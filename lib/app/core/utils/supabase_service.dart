import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import '../../routes/app_pages.dart';

class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find<SupabaseService>();
  AccountDataProvider get _accountDataProvider =>
      Get.find<AccountDataProvider>();

  late final SupabaseClient client;

  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isAuthenticated = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  // Cache control
  final RxBool profileDataCached = false.obs;
  DateTime? lastProfileFetch;

  /// Initializes the Supabase service by loading environment variables and setting up the Supabase client
  Future<SupabaseService> init() async {
    try {
      if (isInitialized.value) {
        debugPrint('Supabase already initialized');
        return this;
      }

      debugPrint('Initializing Supabase service');
      // Load .env file
      await dotenv.load(fileName: ".env");

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('Missing Supabase URL or Anon Key in environment');
      }

      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      client = Supabase.instance.client;
      currentUser.value = client.auth.currentUser;
      isAuthenticated.value = currentUser.value != null;
      isInitialized.value = true;

      // Set up auth state change listener
      client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn) {
          currentUser.value = session?.user;
          isAuthenticated.value = true;
          debugPrint('User signed in: ${currentUser.value?.email}');
        } else if (event == AuthChangeEvent.signedOut) {
          currentUser.value = null;
          isAuthenticated.value = false;
          profileDataCached.value = false;
          lastProfileFetch = null;
          _accountDataProvider.clearData();
          debugPrint('User signed out');
        } else if (event == AuthChangeEvent.userUpdated) {
          currentUser.value = session?.user;
          debugPrint('User updated: ${currentUser.value?.email}');
        }
      });

      // Preload avatar images if user is authenticated and we have cached data
      if (isAuthenticated.value && profileDataCached.value &&
          _accountDataProvider.avatar.value.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AvatarUtils.preloadAvatarImages(_accountDataProvider);
          debugPrint('Preloaded avatar images during initialization');
        });
      }

      debugPrint('Supabase initialized successfully');
      return this;
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  /// Signs in the user with Google authentication
  Future<void> signInWithGoogle() async {
    if (!isInitialized.value) {
      debugPrint('Cannot sign in: Supabase not initialized');
      return;
    }

    final googleClientID = dotenv.env['GOOGLE_WEB_CLIENT_ID'];

    try {
      isLoading.value = true;

      // Start the Google sign-in process
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: googleClientID ?? "",
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        isLoading.value = false;
        return; // User canceled the sign-in flow
      }

      // Get auth details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Sign in to Supabase with Google credential
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
        nonce: null,
      );

      // Update user data
      currentUser.value = response.user;
      isAuthenticated.value = true;

      // Check if user already exists in profiles table
      if (response.user != null) {
        final userId = response.user!.id;
        final existingUserData =
            await client
                .from('profiles')
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        // Ensure default structures are initialized
        _accountDataProvider.initializeDefaultStructures();

        if (existingUserData == null) {
          // New user - initialize with default social data structure
          await client.from('profiles').upsert({
            'user_id': userId,
            'followers': _accountDataProvider.followers,
            'following': _accountDataProvider.following,
            'posts': _accountDataProvider.posts,
          });
        } else {
          // Existing user - ensure social data fields exist, but don't overwrite
          final Map<String, dynamic> updateData = {'user_id': userId};

          // Only add missing fields, don't override existing ones
          if (existingUserData['followers'] == null) {
            updateData['followers'] = _accountDataProvider.followers;
          }

          if (existingUserData['following'] == null) {
            updateData['following'] = _accountDataProvider.following;
          }

          if (existingUserData['posts'] == null) {
            updateData['posts'] = _accountDataProvider.posts;
          }

          // Only update if there are missing fields
          if (updateData.length > 1) {
            await client.from('profiles').upsert(updateData);
          }
        }

        // Fetch the updated user data
        await fetchUserData();
      } else {
        debugPrint('Error: No user returned from Supabase authentication');
        Get.snackbar('Error', 'Authentication failed');
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      Get.snackbar('Error', 'Failed to sign in with Google');
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs out the current user and clears profile data
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await client.auth.signOut();
      _clearUserProfile();
      isAuthenticated.value = false;
      currentUser.value = null;
      Get.offAllNamed(Routes.LOGIN); // Navigate to login screen
    } catch (e) {
      debugPrint('Error signing out: $e');
      Get.snackbar('Error', 'Failed to sign out');
    } finally {
      isLoading.value = false;
    }
  }

  /// Clears user profile reactive variables
  void _clearUserProfile() {
    _accountDataProvider.username.value = '';
    _accountDataProvider.email.value = '';
    _accountDataProvider.avatar.value = '';
  }

  /// Fetches the current user's data if already authenticated
  void _fetchCurrentUserData() {
    final user = client.auth.currentUser;
    if (user != null) {
      currentUser.value = user;
      isAuthenticated.value = true;
      // Also fetch profile data from the database
      fetchUserData()
          .then((_) {
            debugPrint('Initial profile data loaded in _fetchCurrentUserData');
          })
          .catchError((e) {
            debugPrint('Error fetching initial profile data: $e');
          });
    }
  }

  /// Fetches user profile data from the Supabase database
  Future<Map<String, dynamic>> fetchUserData() async {
    try {
      isLoading.value = true;

      // Initialize default structures first to ensure they're available
      _accountDataProvider.initializeDefaultStructures();

      // Check if user is authenticated
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      isAuthenticated.value = true;
      currentUser.value = user;

      // Fetch user profile data from the 'profiles' table
      final userData =
          await client
              .from('profiles')
              .select()
              .eq('user_id', user.id)
              .single();

      debugPrint('Fetched user profile data: $userData');

      // Check if any social data is null and update in database if needed
      Map<String, dynamic> updateData = {};

      if (userData['followers'] == null) {
        updateData['followers'] = _accountDataProvider.followers;
      }

      if (userData['following'] == null) {
        updateData['following'] = _accountDataProvider.following;
      }

      if (userData['posts'] == null) {
        updateData['posts'] = _accountDataProvider.posts;
      }

      // Update database with default values if any field was null
      if (updateData.isNotEmpty) {
        debugPrint('Updating missing fields in database: $updateData');
        await client.from('profiles').update(updateData).eq('user_id', user.id);

        // Merge updates with userData for local use
        userData.addAll(updateData);
      }

      if (userData.isNotEmpty) {
        _accountDataProvider.username.value = userData['username'] ?? '';
        _accountDataProvider.avatar.value = userData['avatar'] ?? '';
        _accountDataProvider.nickname.value = userData['nickname'] ?? '';
        _accountDataProvider.bio.value = userData['bio'] ?? '';
        _accountDataProvider.email.value = client.auth.currentUser?.email ?? '';
        _accountDataProvider.googleAvatar.value =
            client.auth.currentUser?.userMetadata?['avatar_url'] ?? '';

        // Process social data with proper structure
        _processFollowersData(userData['followers']);
        _processFollowingData(userData['following']);
        _processPostsData(userData['posts']);
      } else {
        debugPrint('No profile data found for user ${user.id}');
      }

      return userData;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return {'isAuthenticated': false, 'error': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  /// Process followers data ensuring it has the expected structure
  void _processFollowersData(dynamic followersData) {
    if (followersData == null) {
      // Use the already initialized default structure
      return;
    }

    try {
      final Map<String, dynamic> processedData = Map<String, dynamic>.from(
        followersData,
      );
      // Ensure 'count' exists and is an integer
      if (processedData['count'] == null) {
        processedData['count'] =
            processedData['users'] is List
                ? (processedData['users'] as List).length
                : 0;
      }

      // Ensure 'users' exists and is a list of strings
      if (processedData['users'] == null) {
        processedData['users'] = <String>[];
      } else if (processedData['users'] is List) {
        // Convert any non-string elements to strings
        processedData['users'] =
            (processedData['users'] as List)
                .map((item) => item.toString())
                .toList();
      }

      _accountDataProvider.updateFollowers(processedData);
    } catch (e) {
      debugPrint('Error processing followers data: $e');
      // Default structure is already initialized
    }
  }

  /// Process following data ensuring it has the expected structure
  void _processFollowingData(dynamic followingData) {
    if (followingData == null) {
      // Use the already initialized default structure
      return;
    }

    try {
      final Map<String, dynamic> processedData = Map<String, dynamic>.from(
        followingData,
      );
      // Ensure 'count' exists and is an integer
      if (processedData['count'] == null) {
        processedData['count'] =
            processedData['users'] is List
                ? (processedData['users'] as List).length
                : 0;
      }

      // Ensure 'users' exists and is a list of strings
      if (processedData['users'] == null) {
        processedData['users'] = <String>[];
      } else if (processedData['users'] is List) {
        // Convert any non-string elements to strings
        processedData['users'] =
            (processedData['users'] as List)
                .map((item) => item.toString())
                .toList();
      }

      _accountDataProvider.updateFollowing(processedData);
    } catch (e) {
      debugPrint('Error processing following data: $e');
      // Default structure is already initialized
    }
  }

  /// Process posts data ensuring it has the expected structure
  void _processPostsData(dynamic postsData) {
    if (postsData == null) {
      // Use the already initialized default structure
      return;
    }

    try {
      final Map<String, dynamic> processedData = Map<String, dynamic>.from(
        postsData,
      );

      // Check if this is old format data (with 'posts' and 'count' fields)
      if (processedData['posts'] != null) {
        // Convert old format to new format (categorized)
        final List oldPosts = processedData['posts'] as List;

        // Initialize categories if they don't exist
        if (processedData['threads'] == null) {
          processedData['threads'] = <Map<String, dynamic>>[];
        }
        if (processedData['images'] == null) {
          processedData['images'] = <Map<String, dynamic>>[];
        }
        if (processedData['gifs'] == null) {
          processedData['gifs'] = <Map<String, dynamic>>[];
        }
        if (processedData['stickers'] == null) {
          processedData['stickers'] = <Map<String, dynamic>>[];
        }

        // Move old posts to threads category (default)
        if (oldPosts.isNotEmpty) {
          final List<Map<String, dynamic>> processedThreads = [];

          for (final item in oldPosts) {
            if (item is Map<String, dynamic>) {
              // Ensure each post has an id
              if (item['id'] == null) {
                item['id'] = DateTime.now().millisecondsSinceEpoch.toString();
              }
              processedThreads.add(item);
            } else {
              // Create a new post map with an id
              processedThreads.add({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'content': item.toString(),
              });
            }
          }

          // Merge with existing threads
          final existingThreads = processedData['threads'] as List? ?? [];
          processedData['threads'] = [...existingThreads, ...processedThreads];
        }

        // Remove old format keys
        processedData.remove('posts');
        processedData.remove('count');
      }

      // Ensure all categories exist and are properly formatted
      _ensurePostCategory(processedData, 'threads');
      _ensurePostCategory(processedData, 'images');
      _ensurePostCategory(processedData, 'gifs');
      _ensurePostCategory(processedData, 'stickers');

      _accountDataProvider.updatePosts(processedData);
    } catch (e) {
      debugPrint('Error processing posts data: $e');
      // Default structure is already initialized
    }
  }

  // Helper method to ensure each post category is properly formatted
  void _ensurePostCategory(Map<String, dynamic> data, String category) {
    if (data[category] == null) {
      data[category] = <Map<String, dynamic>>[];
      return;
    }

    if (data[category] is! List) {
      data[category] = <Map<String, dynamic>>[];
      return;
    }

    final List<dynamic> rawItems = data[category] as List;
    final List<Map<String, dynamic>> processedItems = [];

    for (final item in rawItems) {
      if (item is Map<String, dynamic>) {
        // Ensure each post has an id
        if (item['id'] == null) {
          item['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        }
        processedItems.add(item);
      } else if (item != null) {
        // Create a new post map with an id for non-null items
        processedItems.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'content': item.toString(),
        });
      }
    }

    data[category] = processedItems;
  }
}

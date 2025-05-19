import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/core/utils/db_cache_service.dart';
import '../../routes/app_pages.dart';

class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find<SupabaseService>();
  AccountDataProvider get _accountDataProvider =>
      Get.find<AccountDataProvider>();
  
  // Get cache service for optimizations
  DbCacheService? _dbCacheService;
  DbCacheService get dbCacheService {
    _dbCacheService ??= Get.find<DbCacheService>();
    return _dbCacheService!;
  }

  late final SupabaseClient client;

  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isAuthenticated = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  // Cache control
  final RxBool profileDataCached = false.obs;
  DateTime? lastProfileFetch;

  // Realtime subscriptions
  RealtimeChannel? _profileSubscription;
  final RxBool isRealtimeConnected = false.obs;

  // Batch request settings
  static const int maxBatchSize = 20;
  static const Duration batchTimeWindow = Duration(milliseconds: 300);
  final Map<String, List<Future<dynamic> Function()>> _pendingBatches = {};
  final Map<String, Timer> _batchTimers = {};

  // Rate limiting - prevent excessive calls
  final Map<String, DateTime> _lastRequestTime = {};
  static const Duration minRequestInterval = Duration(seconds: 2);

  // Request optimization settings
  static const bool _optimizeFeedRequests = true;
  static const bool _usePreemptiveLoading = true;

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

      // Initialize Supabase with optimal settings for mobile
      await Supabase.initialize(
        url: supabaseUrl, 
        anonKey: supabaseAnonKey,
        debug: false, // Disable debug logs in production
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

          // Set up realtime subscriptions
          _setupRealtimeSubscriptions();
        } else if (event == AuthChangeEvent.signedOut) {
          // Clean up subscriptions
          _cleanupRealtimeSubscriptions();

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

      // If user is already authenticated, set up realtime subscriptions
      if (isAuthenticated.value) {
        _setupRealtimeSubscriptions();
      }

      // Preload avatar images if user is authenticated and we have cached data
      if (isAuthenticated.value &&
          profileDataCached.value &&
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

  /// Sets up realtime subscriptions for the authenticated user's profile data
  /// with optimized settings to reduce bandwidth usage
  void _setupRealtimeSubscriptions() {
    if (!isInitialized.value || currentUser.value == null) {
      debugPrint(
        'Cannot setup realtime: Supabase not initialized or user not authenticated',
      );
      return;
    }

    final userId = currentUser.value!.id;
    debugPrint('Setting up realtime subscriptions for user: $userId');

    // Close any existing subscription
    _cleanupRealtimeSubscriptions();

    try {
      // Create a new subscription to the profiles table for this user
      // but only subscribe to critical fields
      _profileSubscription = client
          .channel('public:profiles')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint(
                'Received realtime profile update',
              );
              _handleProfileUpdate(
                Map<String, dynamic>.from(payload.newRecord),
              );
            },
          )
          .subscribe((status, [err]) {
            if (status == 'SUBSCRIBED') {
              debugPrint('Realtime subscription active for profiles');
              isRealtimeConnected.value = true;
            } else {
              debugPrint('Realtime status for profiles: $status, error: $err');
              isRealtimeConnected.value = status == 'SUBSCRIBED';

              // If there's an error, attempt to reconnect after a delay
              if (status == 'CHANNEL_ERROR' || status == 'TIMED_OUT') {
                Future.delayed(const Duration(seconds: 5), () {
                  debugPrint(
                    'Attempting to reconnect realtime subscription...',
                  );
                  _cleanupRealtimeSubscriptions();
                  _setupRealtimeSubscriptions();
                });
              }
            }
          });

      // Only subscribe to essential realtime events
      // For other data like posts, use cached data with periodic refreshes
    } catch (e) {
      debugPrint('Error setting up realtime subscriptions: $e');
      isRealtimeConnected.value = false;
    }
  }

  /// Handles updates received from the realtime subscription
  void _handleProfileUpdate(Map<String, dynamic> newData) {
    // Process profile updates
    if (newData['username'] != null) {
      _accountDataProvider.username.value = newData['username'];
    }

    if (newData['nickname'] != null) {
      _accountDataProvider.nickname.value = newData['nickname'];
    }

    if (newData['bio'] != null) {
      _accountDataProvider.bio.value = newData['bio'];
    }

    if (newData['avatar'] != null) {
      _accountDataProvider.avatar.value = newData['avatar'];
    }

    // Process social data updates
    if (newData['followers'] != null) {
      _processFollowersData(newData['followers']);
    }

    if (newData['following'] != null) {
      _processFollowingData(newData['following']);
    }

    if (newData['user_posts'] != null) {
      // Update user posts data
      _accountDataProvider.updateUserPostData(
        Map<String, dynamic>.from(newData['user_posts']),
      );
    }

    if (newData['searches'] != null) {
      // Process searches data
      try {
        final List<dynamic> searchesList = newData['searches'];
        _accountDataProvider.searches.value = List<Map<String, dynamic>>.from(
          searchesList.map((item) => Map<String, dynamic>.from(item)),
        );
        // Rebuild the searches map
        _rebuildSearchesMap();
        debugPrint(
          'Updated searches from realtime: ${searchesList.length} items',
        );
      } catch (e) {
        debugPrint('Error processing searches update: $e');
      }
    }
  }

  /// Rebuilds the searches map in account data provider
  void _rebuildSearchesMap() {
    // Access the searches and rebuild the map
    final searches = _accountDataProvider.searches;
    final Map<String, Map<String, dynamic>> searchesMap = {};

    for (final search in searches) {
      if (search['user_id'] != null) {
        searchesMap[search['user_id'].toString()] = search;
      }
    }

    // Update the internal map
    _accountDataProvider.updateSearchesMap(searchesMap);
  }

  /// Cleans up all realtime subscriptions
  void _cleanupRealtimeSubscriptions() {
    if (_profileSubscription != null) {
      _profileSubscription!.unsubscribe();
      _profileSubscription = null;
      isRealtimeConnected.value = false;
      debugPrint('Closed realtime subscriptions');
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
        
        // Get Google avatar URL if available
        String? googleAvatarUrl = response.user?.userMetadata?['avatar_url'];
        
        final existingUserData =
            await client
                .from('profiles')
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        // Ensure default structures are initialized
        _accountDataProvider.initializeDefaultStructures();
        
        // Save Google avatar to account provider
        if (googleAvatarUrl != null && googleAvatarUrl.isNotEmpty) {
          _accountDataProvider.googleAvatar.value = googleAvatarUrl;
        }

        if (existingUserData == null) {
          // New user - initialize with enhanced post structure and Google avatar
          await client.from('profiles').upsert({
            'user_id': userId,
            'follower_count': 0, 
            'following_count': 0,
            'user_posts': {'post_count': 0},
            'google_avatar': googleAvatarUrl ?? '',
          });
        } else {
          // Existing user - ensure social data fields exist, but don't overwrite
          final Map<String, dynamic> updateData = {'user_id': userId};

          // Only add missing fields, don't override existing ones
          if (existingUserData['follower_count'] == null) {
            updateData['follower_count'] = 0;
          }

          if (existingUserData['following_count'] == null) {
            updateData['following_count'] = 0;
          }

          if (existingUserData['user_posts'] == null) {
            updateData['user_posts'] = {'post_count': 0};
          }
          
          // Update Google avatar if needed
          if (googleAvatarUrl != null && 
              (existingUserData['google_avatar'] == null || 
              existingUserData['google_avatar'].toString().isEmpty)) {
            updateData['google_avatar'] = googleAvatarUrl;
          }

          // Only update if there are missing fields
          if (updateData.length > 1) {
            await client.from('profiles').upsert(updateData);
          }
        }

        // Set up realtime subscriptions
        _setupRealtimeSubscriptions();

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

      // Clean up subscriptions first
      _cleanupRealtimeSubscriptions();

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

  /// Fetch user profile data from the Supabase database
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
              .select(
                'user_id, username, nickname, avatar, bio, follower_count, following_count, user_posts, google_avatar, updated_at',
              )
              .eq('user_id', user.id)
              .single();

      debugPrint('Fetched user profile data: $userData');

      // Check if any data is null and update in database if needed
      Map<String, dynamic> updateData = {};

      // Add default values for any missing fields
      if (userData['user_posts'] == null) {
        updateData['user_posts'] = {'post_count': 0};
      }

      // Update follower_count and following_count if missing
      if (userData['follower_count'] == null) {
        updateData['follower_count'] = 0;
      }

      if (userData['following_count'] == null) {
        updateData['following_count'] = 0;
      }

      // Get Google avatar from user metadata if not in profile
      String? googleAvatarUrl = user.userMetadata?['avatar_url'];
      if (googleAvatarUrl != null && 
          (userData['google_avatar'] == null || userData['google_avatar'].toString().isEmpty)) {
        updateData['google_avatar'] = googleAvatarUrl;
      }

      // Update database with default values if any field was null or needs migration
      if (updateData.isNotEmpty) {
        debugPrint('Updating missing fields or migrating data: $updateData');
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
        _accountDataProvider.googleAvatar.value = userData['google_avatar'] ?? 
            client.auth.currentUser?.userMetadata?['avatar_url'] ?? '';

        // Update follower and following counts
        _accountDataProvider.followerCount.value = userData['follower_count'] ?? 0;
        _accountDataProvider.followingCount.value = userData['following_count'] ?? 0;

        // Load followers and following data
        await _accountDataProvider.loadFollowers(user.id);
        await _accountDataProvider.loadFollowing(user.id);

        // Update user_posts data
        if (userData['user_posts'] != null) {
          _accountDataProvider.updateUserPostData(
            Map<String, dynamic>.from(userData['user_posts']),
          );
        }

        // Load posts from posts table
        await _accountDataProvider.loadUserPosts(user.id);

        // Mark profile data as cached and record timestamp
        profileDataCached.value = true;
        lastProfileFetch = DateTime.now();
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

  /// Add a new post with the enhanced post structure
  Future<void> addNewPost(
    Map<String, dynamic> postData,
    String category,
  ) async {
    try {
      // Get user ID
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Ensure required fields are present
      final enhancedPost = _enhancePostItem(postData);

      // Add to local state first for immediate UI update
      _accountDataProvider.addPost(enhancedPost);

      // Update the posts in Supabase using the new create_post function
      String postType;
      switch (category) {
        case 'threads':
          postType = 'text';
          break;
        case 'images':
          postType = 'image';
          break;
        case 'gifs':
          postType = 'gif';
          break;
        case 'stickers':
          postType = 'sticker';
          break;
        default:
          postType = 'text';
      }

      // Call the create_post RPC function
      final result = await client.rpc(
        'create_post',
        params: {
          'user_id': userId,
          'content': enhancedPost['content'] ?? '',
          'post_type': postType,
          'image_url': enhancedPost['image_url'],
          'gif_url': enhancedPost['gif_url'],
          'sticker_url': enhancedPost['sticker_url'],
          'metadata': enhancedPost['metadata'] ?? {},
        },
      );

      // Get the new post ID and update local post
      final postId = result as String;
      enhancedPost['id'] = postId;

      debugPrint('Added new post with ID: $postId');
    } catch (e) {
      debugPrint('Error adding new post: $e');
      Get.snackbar('Error', 'Failed to add post. Please try again.');
    }
  }

  /// Delete a post from any category
  Future<void> deletePost(String postId) async {
    try {
      // Get user ID
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Remove from local state first for immediate UI update
      _accountDataProvider.removePost(postId);

      // Update the posts in Supabase using the delete_post function
      final result = await client.rpc(
        'delete_post',
        params: {'post_id': postId, 'user_id': userId},
      );

      if (result == true) {
        debugPrint('Deleted post with ID: $postId');
      } else {
        debugPrint('Post not found or could not be deleted: $postId');
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      Get.snackbar('Error', 'Failed to delete post. Please try again.');
    }
  }

  /// Follow a user
  Future<void> followUser(String targetUserId) async {
    try {
      // Get user ID
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Call the follow_user function in Supabase with the updated parameter names
      await client.rpc(
        'follow_user',
        params: {
          'p_follower_id': userId,
          'p_following_id': targetUserId,
        },
      );

      debugPrint('Following user: $targetUserId');

      // Fetch latest following data to ensure UI is up-to-date
      await _accountDataProvider.loadFollowing(userId);
      
    } catch (e) {
      debugPrint('Error following user: $e');
      Get.snackbar('Error', 'Failed to follow user. Please try again.');
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    try {
      // Get user ID
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Call the unfollow_user function in Supabase with the updated parameter names
      await client.rpc(
        'unfollow_user',
        params: {
          'p_follower_id': userId,
          'p_following_id': targetUserId,
        },
      );

      debugPrint('Unfollowed user: $targetUserId');

      // Fetch latest following data to ensure UI is up-to-date
      await _accountDataProvider.loadFollowing(userId);
      
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      Get.snackbar('Error', 'Failed to unfollow user. Please try again.');
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
      
      // Convert old JSON format to new list format
      final List<Map<String, dynamic>> followersList = [];
      if (processedData['users'] is List) {
        final List<String> userIds = List<String>.from(processedData['users']);
        for (final userId in userIds) {
          followersList.add({
            'follower_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      _accountDataProvider.updateFollowers(followersList);
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
      
      // Convert old JSON format to new list format
      final List<Map<String, dynamic>> followingList = [];
      if (processedData['users'] is List) {
        final List<String> userIds = List<String>.from(processedData['users']);
        for (final userId in userIds) {
          followingList.add({
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      _accountDataProvider.updateFollowing(followingList);
    } catch (e) {
      debugPrint('Error processing following data: $e');
      // Default structure is already initialized
    }
  }

  /// Enhances a single post item with additional metadata
  Map<String, dynamic> _enhancePostItem(Map<String, dynamic> post) {
    // Clone the post to avoid modifying the original
    final Map<String, dynamic> enhancedPost = Map<String, dynamic>.from(post);

    // Add timestamps if missing
    if (enhancedPost['created_at'] == null) {
      enhancedPost['created_at'] = DateTime.now().toIso8601String();
    }

    if (enhancedPost['updated_at'] == null) {
      enhancedPost['updated_at'] = enhancedPost['created_at'];
    }

    // Add metadata if missing
    if (enhancedPost['metadata'] == null) {
      enhancedPost['metadata'] = {};
    }

    return enhancedPost;
  }

  /// Optimize database fetch with caching and batching
  Future<T> optimizedDbFetch<T>({
    required String cacheKey,
    required String cacheType,
    required Future<T> Function() fetchFn,
    Duration? maxAge,
  }) async {
    // Check rate limiting to prevent excessive calls
    final now = DateTime.now();
    final lastRequest = _lastRequestTime[cacheKey];
    if (lastRequest != null && now.difference(lastRequest) < minRequestInterval) {
      debugPrint('Rate limiting request: $cacheKey - Using cached data');
      // Try to get from cache
      try {
        if (dbCacheService.isCachingEnabled.value) {
          // Use direct fetch since we can't access private methods
          switch (cacheType) {
            case 'user_profile':
              final result = await dbCacheService.getUserProfile(
                cacheKey.split('_').last, 
                () async => null,
              );
              if (result != null) return result as T;
              break;
            case 'user_posts':
              final result = await dbCacheService.getUserPosts(
                cacheKey.split('_').last,
                () async => <Map<String, dynamic>>[],
              );
              if (result.isNotEmpty) return result as T;
              break;
            case 'followers':
              final result = await dbCacheService.getFollowers(
                cacheKey.split('_').last,
                () async => <Map<String, dynamic>>[],
              );
              if (result.isNotEmpty) return result as T;
              break;
            case 'following':
              final result = await dbCacheService.getFollowing(
                cacheKey.split('_').last,
                () async => <Map<String, dynamic>>[],
              );
              if (result.isNotEmpty) return result as T;
              break;
          }
        }
      } catch (_) {}
    }
    
    // Update last request time
    _lastRequestTime[cacheKey] = now;
    
    // For batch-eligible requests, add to batch queue
    if (_shouldBatchRequest(cacheType)) {
      return _addToBatch(cacheKey, cacheType, fetchFn);
    }
    
    // For regular requests, use cache service
    try {
      switch (cacheType) {
        case 'user_profile':
          final result = await dbCacheService.getUserProfile(cacheKey.split('_').last, fetchFn as Future<Map<String, dynamic>?> Function());
          return result as T;
        case 'user_posts':
          final result = await dbCacheService.getUserPosts(cacheKey.split('_').last, fetchFn as Future<List<Map<String, dynamic>>> Function());
          return result as T;
        case 'followers':
          final result = await dbCacheService.getFollowers(cacheKey.split('_').last, fetchFn as Future<List<Map<String, dynamic>>> Function());
          return result as T;
        case 'following':
          final result = await dbCacheService.getFollowing(cacheKey.split('_').last, fetchFn as Future<List<Map<String, dynamic>>> Function());
          return result as T;
        default:
          return fetchFn();
      }
    } catch (e) {
      debugPrint('Error in optimizedDbFetch for $cacheKey: $e');
      return fetchFn(); // Fall back to direct fetch if cache fails
    }
  }
  
  /// Determine if a request should be batched
  bool _shouldBatchRequest(String cacheType) {
    return cacheType == 'user_posts' || 
           cacheType == 'feed' || 
           cacheType == 'explore_feed';
  }
  
  /// Add a request to a batching queue
  Future<T> _addToBatch<T>(
    String cacheKey, 
    String cacheType, 
    Future<T> Function() fetchFn,
  ) async {
    // Create completer to return a future
    final completer = Completer<T>();
    
    // Initialize batch list if it doesn't exist
    if (!_pendingBatches.containsKey(cacheType)) {
      _pendingBatches[cacheType] = [];
      
      // Start a timer to execute batch
      _batchTimers[cacheType] = Timer(batchTimeWindow, () {
        _executeBatch(cacheType);
      });
    }
    
    // Add fetch function to batch
    _pendingBatches[cacheType]!.add(() async {
      try {
        final result = await fetchFn();
        completer.complete(result);
        return result;
      } catch (e) {
        completer.completeError(e);
        return null;
      }
    });
    
    return completer.future;
  }
  
  /// Execute a batch of requests
  Future<void> _executeBatch(String batchType) async {
    final batch = _pendingBatches.remove(batchType) ?? [];
    _batchTimers.remove(batchType);
    
    if (batch.isEmpty) return;
    
    debugPrint('Executing batch of ${batch.length} $batchType requests');
    
    try {
      // Execute batch in parallel with a reasonable limit
      final chunks = _chunkList(batch, maxBatchSize);
      for (final chunk in chunks) {
        await Future.wait(chunk.map((fn) => fn()));
      }
    } catch (e) {
      debugPrint('Error executing batch: $e');
    }
  }
  
  /// Split a list into smaller chunks
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final result = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      result.add(list.sublist(i, end));
    }
    return result;
  }

  /// Preload commonly accessed data to improve app performance
  Future<void> preloadCommonData() async {
    if (!isAuthenticated.value) return;
    
    final userId = currentUser.value!.id;
    
    try {
      // Load user data in parallel
      await Future.wait([
        // Preload user profile
        optimizedDbFetch(
          cacheKey: 'profile_$userId',
          cacheType: 'user_profile',
          fetchFn: () async {
            return await client
                .from('profiles')
                .select()
                .eq('user_id', userId)
                .single();
          },
        ),
        
        // Preload posts
        optimizedDbFetch(
          cacheKey: 'posts_$userId',
          cacheType: 'user_posts',
          fetchFn: () async {
            // Only fetch basic data needed for feed view
            final response = await client
                .from('posts')
                .select('id,created_at,post_type,title')
                .eq('user_id', userId)
                .order('created_at', ascending: false)
                .limit(20);
                
            return List<Map<String, dynamic>>.from(response);
          },
        ),
      ]);
      
      debugPrint('Preloaded common user data');
    } catch (e) {
      debugPrint('Error preloading data: $e');
    }
  }
}

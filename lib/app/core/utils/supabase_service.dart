import 'dart:async';
import 'dart:typed_data';
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

  // Cache durations
  static const Duration profileCacheDuration = Duration(minutes: 5);
  static const Duration followCacheDuration = Duration(minutes: 2);

  // Realtime subscriptions
  RealtimeChannel? _profileSubscription;
  final RxBool isRealtimeConnected = false.obs;

  // Batch request settings
  static const int maxBatchSize = 20;
  static const Duration batchTimeWindow = Duration(milliseconds: 300);

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
      if (isAuthenticated.value) {}

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
            'email': response.user!.email,
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

          if (existingUserData['post_count'] == null) {
            updateData['post_count'] = 0;
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

  /// Diagnose bucket permissions issue
  /// This function can be called to check if the user has proper permissions
  /// for a specific bucket
  Future<bool> checkBucketPermissions(String bucketName) async {
    if (currentUser.value == null) {
      debugPrint(
        '🔐 SECURITY CHECK: Cannot check bucket permissions - no authenticated user',
      );
      return false;
    }

    debugPrint(
      '🔐 SECURITY CHECK: Testing permissions for bucket "$bucketName"',
    );

    try {
      // Try to list the bucket (doesn't need to succeed, just checking permissions)
      await client.storage.from(bucketName).list();
      debugPrint(
        '🔐 SECURITY CHECK: Success! User can list the "$bucketName" bucket',
      );

      // Create a test file path with timestamp to avoid conflicts
      final testPath =
          'permission_test_${DateTime.now().millisecondsSinceEpoch}.txt';

      // Try to upload a small test file
      try {
        await client.storage
            .from(bucketName)
            .uploadBinary(
              testPath,
              Uint8List.fromList('test'.codeUnits),
              fileOptions: const FileOptions(upsert: true),
            );
        debugPrint(
          '🔐 SECURITY CHECK: Success! User can upload to "$bucketName" bucket',
        );

        // Try to delete the test file
        try {
          await client.storage.from(bucketName).remove([testPath]);
          debugPrint(
            '🔐 SECURITY CHECK: Success! User can delete from "$bucketName" bucket',
          );
        } catch (e) {
          debugPrint(
            '🔐 SECURITY CHECK: User cannot delete from "$bucketName" bucket: $e',
          );
        }

        return true;
      } catch (e) {
        debugPrint(
          '🔐 SECURITY CHECK: User cannot upload to "$bucketName" bucket: $e',
        );
        debugPrint(
          '🔐 SECURITY CHECK: This indicates a Row Level Security (RLS) issue',
        );
        return false;
      }
    } catch (e) {
      debugPrint('🔐 SECURITY CHECK: Cannot access "$bucketName" bucket: $e');
      debugPrint(
        '🔐 SECURITY CHECK: Bucket may not exist or user lacks basic permissions',
      );
      return false;
    }
  }

  /// Initialize real-time subscriptions for follow updates
  Future<void> initializeFollowSubscriptions() async {
    if (currentUser.value == null) return;

    debugPrint(
      'Initializing follow subscriptions for user: ${currentUser.value?.id}',
    );

    try {
      await _profileSubscription?.unsubscribe();

      _profileSubscription = client
          .channel('public:follows')
          // When current user follows someone
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'follows',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'follower_id',
              value: currentUser.value!.id,
            ),
            callback: (payload) async {
              debugPrint('Current user followed someone: ${payload.newRecord}');
              await _accountDataProvider.verifyFollowCounts(
                currentUser.value!.id,
              );
            },
          )
          // When current user unfollows someone
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'follows',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'follower_id',
              value: currentUser.value!.id,
            ),
            callback: (payload) async {
              debugPrint(
                'Current user unfollowed someone: ${payload.oldRecord}',
              );
              await _accountDataProvider.verifyFollowCounts(
                currentUser.value!.id,
              );
            },
          )
          // When someone follows current user
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'follows',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'following_id',
              value: currentUser.value!.id,
            ),
            callback: (payload) async {
              debugPrint('Someone followed current user: ${payload.newRecord}');
              await _accountDataProvider.verifyFollowCounts(
                currentUser.value!.id,
              );
            },
          )
          // When someone unfollows current user
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'follows',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'following_id',
              value: currentUser.value!.id,
            ),
            callback: (payload) async {
              debugPrint(
                'Someone unfollowed current user: ${payload.oldRecord}',
              );
              await _accountDataProvider.verifyFollowCounts(
                currentUser.value!.id,
              );
            },
          )
          .subscribe((status, [_]) {
            debugPrint('Follow subscription status: $status');
            isRealtimeConnected.value =
                status == RealtimeSubscribeStatus.subscribed;
          });
    } catch (e) {
      debugPrint('Error setting up follow subscriptions: $e');
    }
  }
}

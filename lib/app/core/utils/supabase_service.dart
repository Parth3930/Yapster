import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../routes/app_pages.dart';

class SupabaseService extends GetxService {
  /// Singleton accessor for the SupabaseService instance
  static SupabaseService get to => Get.find<SupabaseService>();

  /// Supabase client instance, initialized in the `init` method
  late final SupabaseClient client;

  /// Reactive variable for the current authenticated user
  final Rx<User?> currentUser = Rx<User?>(null);

  /// Reactive variable indicating authentication status
  final RxBool isAuthenticated = false.obs;

  /// Reactive variable indicating loading state
  final RxBool isLoading = false.obs;

  /// Reactive variable indicating if Supabase is initialized
  final RxBool isInitialized = false.obs;

  /// Reactive variables for user profile data
  final RxString userName = ''.obs;
  final RxString userEmail = ''.obs;
  final RxString userAvatarUrl = ''.obs;
  final RxString userPhotoUrl = ''.obs; // Google profile photo URL

  /// Initializes the Supabase service by loading environment variables and setting up the Supabase client
  Future<SupabaseService> init() async {
    try {
      debugPrint('Initializing Supabase service');
      // Load environment variables from .env file
      await dotenv.load(fileName: ".env");

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
          'SUPABASE_URL or SUPABASE_ANON_KEY not found in .env file',
        );
      }

      // Initialize Supabase with URL and anonymous key
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      client = Supabase.instance.client;
      _fetchCurrentUserData();
      isInitialized.value = true;
      return this;
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow; //
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
      
      // Save Google profile data
      userName.value = googleUser.displayName ?? '';
      userEmail.value = googleUser.email;
      userPhotoUrl.value = googleUser.photoUrl ?? '';
      
      debugPrint('Google sign-in successful: ${googleUser.displayName}');
      debugPrint('Google photo URL: ${googleUser.photoUrl}');

      // create new user in profiles table or update if exists
      await client.from('profiles').upsert({'user_id': response.user?.id});
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
    userName.value = '';
    userEmail.value = '';
    userAvatarUrl.value = '';
    userPhotoUrl.value = '';
  }

  /// Fetches the current user's data if already authenticated
  void _fetchCurrentUserData() {
    final user = client.auth.currentUser;
    if (user != null) {
      currentUser.value = user;
      isAuthenticated.value = true;
      // Also fetch profile data from the database
      fetchUserData().then((_) {
        debugPrint('Initial profile data loaded in _fetchCurrentUserData');
      }).catchError((e) {
        debugPrint('Error fetching initial profile data: $e');
      });
    }
  }

  /// Fetches user profile data from the Supabase database
  Future<Map<String, dynamic>> fetchUserData() async {
    try {
      isLoading.value = true;
      
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

      if (userData.isNotEmpty) {
        // Make sure we're using the correct field names from the database
        userName.value = userData['username'] ?? '';
        userAvatarUrl.value = userData['avatar'] ?? '';
        
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
}

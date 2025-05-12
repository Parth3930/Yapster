import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'storage_service.dart';
import '../../routes/app_pages.dart';

class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find<SupabaseService>();
  final StorageService _storageService = Get.find<StorageService>();

  late final SupabaseClient client;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isAuthenticated = false.obs;
  final RxBool isLoading = false.obs;

  // User profile data
  final RxString userName = ''.obs;
  final RxString userEmail = ''.obs;
  final RxString userPhotoUrl = ''.obs;

  Future<SupabaseService> init() async {
    try {
      debugPrint('Initializing Supabase service');
      // Load .env file
      await dotenv.load(fileName: ".env");

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        debugPrint(
          'Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env file',
        );
        await Supabase.initialize(
          url: supabaseUrl ?? '',
          anonKey: supabaseAnonKey ?? '',
        );
      } else {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      }

      client = Supabase.instance.client;
      debugPrint('Supabase client initialized');

      // Check if user is already logged in
      currentUser.value = client.auth.currentUser;
      isAuthenticated.value = currentUser.value != null;
      debugPrint('Initial auth state - isAuthenticated: ${isAuthenticated.value}');

      if (isAuthenticated.value) {
        await _loadUserProfile();
      }

      // Listen for auth state changes
      client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        debugPrint('Auth state changed - Event: $event');

        if (event == AuthChangeEvent.signedIn) {
          currentUser.value = session?.user;
          isAuthenticated.value = true;
          debugPrint('User signed in - isAuthenticated: ${isAuthenticated.value}');
          _loadUserProfile();
        } else if (event == AuthChangeEvent.signedOut) {
          currentUser.value = null;
          isAuthenticated.value = false;
          debugPrint('User signed out - isAuthenticated: ${isAuthenticated.value}');
          _clearUserProfile();
        }
      });

      return this;
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      return this;
    }
  }

  Future<void> signInWithGoogle() async {
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

      // Save user profile data
      userName.value = googleUser.displayName ?? '';
      userEmail.value = googleUser.email;
      userPhotoUrl.value = googleUser.photoUrl ?? '';

      await _saveUserProfile();

      // Check if user has a username in the database
      final hasUsername = await checkUserHasUsername();

      // Navigate based on whether user has a username
      if (!hasUsername) {
        Get.offAllNamed(Routes.ACCOUNT_SETUP);
      }
      // If user has username, navigation to home is handled by the listener in controller
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      Get.snackbar('Error', 'Failed to sign in with Google');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await client.auth.signOut();
      _clearUserProfile();
      isAuthenticated.value = false;
      currentUser.value = null;
      Get.offAllNamed(Routes.LOGIN);
    } catch (e) {
      debugPrint('Error signing out: $e');
      Get.snackbar('Error', 'Failed to sign out');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveUserProfile() async {
    await _storageService.saveString('user_name', userName.value);
    await _storageService.saveString('user_email', userEmail.value);
    await _storageService.saveString('user_photo_url', userPhotoUrl.value);
  }

  Future<void> _loadUserProfile() async {
    userName.value = _storageService.getString('user_name') ?? '';
    userEmail.value = _storageService.getString('user_email') ?? '';
    userPhotoUrl.value = _storageService.getString('user_photo_url') ?? '';
  }

  void _clearUserProfile() {
    userName.value = '';
    userEmail.value = '';
    userPhotoUrl.value = '';
    _storageService.remove('user_name');
    _storageService.remove('user_email');
    _storageService.remove('user_photo_url');
  }

  // Check if the current user has a username in the database
  Future<bool> checkUserHasUsername() async {
    try {
      debugPrint('Checking if user has username');
      if (currentUser.value == null) {
        debugPrint('No current user found');
        return false;
      }

      // Check if username exists in profiles table
      final response = await client
          .from('profiles')
          .select('username')
          .eq('user_id', currentUser.value!.id)
          .maybeSingle();
      
      debugPrint('Username check response: $response');
      
      // If no record found or username is empty, return false
      if (response == null) {
        debugPrint('No username record found');
        return false;
      }
      
      // If we get a response with a non-empty username, return true
      final hasUsername = response['username'] != null &&
          response['username'].toString().isNotEmpty;
      debugPrint('Has username: $hasUsername');
      return hasUsername;
    } catch (e) {
      // If there's an error, return false
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  // Save username to the database
  Future<bool> saveUsername(String username) async {
    try {
      if (currentUser.value == null) return false;

      // Update or insert the username in the profiles table
      await client.from('profiles').upsert({
        'user_id': currentUser.value!.id,
        'username': username,
      });

      return true;
    } catch (e) {
      debugPrint('Error saving username: $e');
      return false;
    }
  }
}

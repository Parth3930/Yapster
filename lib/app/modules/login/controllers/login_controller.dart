import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../data/providers/account_data_provider.dart';
import '../../../routes/app_pages.dart';

class LoginController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();

  // Reactive variables
  final RxBool isLoading = false.obs;

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      await _supabaseService.signInWithGoogle();

      // After successful login, check user setup and navigate accordingly
      await _checkUserSetupAndNavigate();
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      Get.snackbar(
        'Error',
        'Failed to sign in with Google',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Check user setup status and navigate to appropriate screen
  Future<void> _checkUserSetupAndNavigate() async {
    try {
      final currentUser = _supabaseService.client.auth.currentUser;

      if (currentUser == null) {
        debugPrint('No user found after login, staying on login screen');
        return;
      }

      // Fetch user profile data
      final userData =
          await _supabaseService.client
              .from('profiles')
              .select()
              .eq('user_id', currentUser.id)
              .maybeSingle();

      if (userData == null) {
        debugPrint('User not found in profiles table, navigating to login');
        _supabaseService.isAuthenticated.value = false;
        await _supabaseService.signOut();
        return;
      }

      // Update profile data
      _supabaseService.isAuthenticated.value = true;
      _accountDataProvider.username.value = userData['username'] ?? '';
      _accountDataProvider.avatar.value = userData['avatar'] ?? '';
      _accountDataProvider.nickname.value = userData['nickname'] ?? '';
      _accountDataProvider.banner.value = userData['banner'] ?? '';
      _accountDataProvider.bio.value = userData['bio'] ?? '';
      _accountDataProvider.email.value = currentUser.email ?? '';
      _accountDataProvider.googleAvatar.value = userData['google_avatar'] ?? '';

      // Navigate based on user setup status
      if (_accountDataProvider.username.string.isEmpty) {
        debugPrint('No username, navigating to account setup');
        Get.offAllNamed(Routes.ACCOUNT_USERNAME_SETUP);
      } else if (_accountDataProvider.avatar.string.isEmpty) {
        debugPrint('No avatar, navigating to avatar setup');
        Get.offAllNamed(Routes.ACCOUNT_AVATAR_SETUP);
      } else {
        debugPrint('User fully set up, navigating to home');
        Get.offAllNamed(Routes.HOME);
      }
    } catch (e) {
      debugPrint('Error checking user setup: $e');
      // On error, stay on login screen
    }
  }
}

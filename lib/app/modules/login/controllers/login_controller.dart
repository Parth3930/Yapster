import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class LoginController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  // Reactive variables
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Check if user is already authenticated
    if (_supabaseService.isAuthenticated.value) {
      _checkUserAndNavigate();
    }

    // Listen for authentication state changes
    ever(_supabaseService.isAuthenticated, (isAuthenticated) {
      if (isAuthenticated) {
        _checkUserAndNavigate();
      }
    });
  }

  // Check if user has a username and navigate accordingly
  Future<void> _checkUserAndNavigate() async {
    final hasUsername = await _supabaseService.checkUserHasUsername();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasUsername) {
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.offAllNamed(Routes.ACCOUNT_USERNAME_SETUP);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      await _supabaseService.signInWithGoogle();

      // Navigation is handled by the listener in onInit
    } catch (e) {
      debugPrint('Error in login controller: $e');
      Get.snackbar(
        'Error',
        'Failed to sign in with Google',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}

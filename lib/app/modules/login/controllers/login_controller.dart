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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.HOME);
      });
    }

    // Listen for authentication state changes
    ever(_supabaseService.isAuthenticated, (isAuthenticated) {
      if (isAuthenticated) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.HOME);
        });
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/splash/controllers/splash_controller.dart';
import '../../../core/utils/supabase_service.dart';

class LoginController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final _navigator = Get.find<SplashController>();

  // Reactive variables
  final RxBool isLoading = false.obs;

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
      _navigator.checkAuthAndNavigate();
    }
  }
}

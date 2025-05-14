import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('SplashController initialized');
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      debugPrint('Starting auth check and navigation');
      isLoading.value = true;

      // Add a small delay to show the splash screen
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('Delay completed');

      final isAuthenticated = _supabaseService.isAuthenticated.value;
      debugPrint('Is authenticated: $isAuthenticated');

      if (!isAuthenticated) {
        debugPrint('User not authenticated, navigating to login');
        Get.offAllNamed(Routes.LOGIN);
      } else {
        final hasUsername = await _supabaseService.checkUserHasUsername();
        debugPrint('Has username: $hasUsername');

        if (!hasUsername) {
          debugPrint('No username, navigating to account setup');
          Get.offAllNamed(Routes.ACCOUNT_USERNAME_SETUP);
        } else {
          debugPrint('Has username, navigating to home');
          Get.offAllNamed(Routes.HOME);
        }
      }
    } catch (e) {
      debugPrint('Error in splash controller: $e');
      Get.offAllNamed(Routes.LOGIN);
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final _accountDataProvider = Get.find<AccountDataProvider>();
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('SplashController initialized');
    Future.microtask(() => checkAuthAndNavigate());
  }

  Future<void> checkAuthAndNavigate() async {
    try {
      debugPrint('Starting auth check and navigation');
      isLoading.value = true;

      // Check authentication first
      if (!_supabaseService.isAuthenticated.value) {
        debugPrint('User not authenticated, navigating to login');
        Get.offAllNamed(Routes.LOGIN);
        return;
      }

      await _supabaseService.fetchUserData();

      // If authenticated, check username
      if (_accountDataProvider.username.string.isEmpty) {
        debugPrint('No username, navigating to account setup');
        Get.offAllNamed(Routes.ACCOUNT_USERNAME_SETUP);
        return;
      }

      // If username exists, check avatar
      if (_accountDataProvider.avatar.string.isEmpty ||
          _accountDataProvider.avatar.string != "skiped") {
        debugPrint('No avatar, navigating to avatar setup');
        Get.offAllNamed(Routes.ACCOUNT_AVATAR_SETUP);
        return;
      }

      // If all checks pass, go to home
      debugPrint('User fully set up, navigating to home');
      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      debugPrint('Error in splash controller: $e');
      Get.offAllNamed(Routes.LOGIN);
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
  }
}

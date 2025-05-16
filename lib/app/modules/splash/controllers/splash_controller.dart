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

      // Check if Supabase client has a current user
      final currentUser = _supabaseService.client.auth.currentUser;
      
      if (currentUser == null) {
        debugPrint('No current user found, navigating to login');
        _supabaseService.isAuthenticated.value = false;
        Get.offAllNamed(Routes.LOGIN);
        return;
      }

      // Try to fetch user profile data
      try {
        final userData = await _supabaseService.client
            .from('profiles')
            .select()
            .eq('user_id', currentUser.id)
            .maybeSingle();
        
        // Check if user exists in profiles table
        if (userData == null) {
          debugPrint('User not found in profiles table, navigating to login');
          _supabaseService.isAuthenticated.value = false;
          await _supabaseService.signOut();
          Get.offAllNamed(Routes.LOGIN);
          return;
        }
        
        // User exists in database, update profile data
        _supabaseService.isAuthenticated.value = true;
        _accountDataProvider.username.value = userData['username'] ?? '';
        _accountDataProvider.avatar.value = userData['avatar'] ?? '';
        _accountDataProvider.email.value = currentUser.email ?? '';
      } catch (e) {
        debugPrint('Error fetching profile data: $e');
        _supabaseService.isAuthenticated.value = false;
        await _supabaseService.signOut();
        Get.offAllNamed(Routes.LOGIN);
        return;
      }

      // If authenticated, check username
      if (_accountDataProvider.username.string.isEmpty) {
        debugPrint('No username, navigating to account setup');
        Get.offAllNamed(Routes.ACCOUNT_USERNAME_SETUP);
        return;
      }

      // If username exists, check avatar
      if (_accountDataProvider.avatar.string.isEmpty) {
        debugPrint('No avatar, navigating to avatar setup');
        Get.offAllNamed(Routes.ACCOUNT_AVATAR_SETUP);
        return;
      }

      // If all checks pass, go to home
      debugPrint('User fully set up, navigating to home');
      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      debugPrint('Error in splash controller: $e');
      _supabaseService.isAuthenticated.value = false;
      Get.offAllNamed(Routes.LOGIN);
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  final _accountDataProvider = Get.find<AccountDataProvider>();
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  // Don't find SupabaseService immediately on initialization
  late SupabaseService _supabaseService;
  bool _serviceChecked = false;

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

      // Check if services are ready
      if (!await _ensureServicesReady()) {
        // Services not ready yet, retry in a moment
        await Future.delayed(const Duration(milliseconds: 500));
        if (Get.isRegistered<SplashController>()) {
          checkAuthAndNavigate();
        }
        return;
      }

      // Check if Supabase client has a current user
      final currentUser = _supabaseService.client.auth.currentUser;

      if (currentUser == null) {
        debugPrint('No current user found, navigating to login');
        _supabaseService.isAuthenticated.value = false;
        Get.offAllNamed(Routes.LOGIN);
        return;
      }

      // Check if we have cached profile data that's not too old (cache for 6 hours)
      bool shouldFetchFromDB = true;

      if (_supabaseService.profileDataCached.value &&
          _supabaseService.lastProfileFetch != null) {
        final cacheDuration = DateTime.now().difference(
          _supabaseService.lastProfileFetch!,
        );
        // Use cache if it's less than 6 hours old and we have data
        if (cacheDuration.inHours < 6 &&
            _accountDataProvider.username.value.isNotEmpty) {
          shouldFetchFromDB = false;
          debugPrint('Using cached profile data in splash screen');
        }
      }

      // Try to fetch user profile data if needed
      if (shouldFetchFromDB) {
        debugPrint('Fetching profile data from database in splash screen');
        final userData =
            await _supabaseService.client
                .from('profiles')
                .select()
                .eq('user_id', currentUser.id)
                .maybeSingle();

        // Update cache status
        _supabaseService.profileDataCached.value = true;
        _supabaseService.lastProfileFetch = DateTime.now();

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
        _accountDataProvider.nickname.value = userData['nickname'] ?? '';
        _accountDataProvider.banner.value = userData['banner'] ?? '';
        _accountDataProvider.bio.value = userData['bio'] ?? '';
        _accountDataProvider.email.value = currentUser.email ?? '';

        // CRITICAL FIX: Ensure Google avatar is also cached when loading profile
        _accountDataProvider.googleAvatar.value =
            userData['google_avatar'] ?? '';

        // CRITICAL FIX: Force refresh all reactive values to ensure UI updates
        _accountDataProvider.username.refresh();
        _accountDataProvider.nickname.refresh();
        _accountDataProvider.avatar.refresh();
        _accountDataProvider.banner.refresh();
        _accountDataProvider.bio.refresh();
        _accountDataProvider.email.refresh();
        _accountDataProvider.googleAvatar.refresh();

        // Log the user data status for debugging
        final bool hasSkippedAvatar =
            userData['avatar'] == "skiped" ||
            userData['avatar'] == null ||
            userData['avatar'] == '';
        debugPrint('Splash Controller - User data loaded and cached:');
        debugPrint('  Username: ${_accountDataProvider.username.value}');
        debugPrint('  Nickname: ${_accountDataProvider.nickname.value}');
        debugPrint('  Bio: ${_accountDataProvider.bio.value}');
        debugPrint('  Email: ${_accountDataProvider.email.value}');
        debugPrint('  Regular avatar: ${userData['avatar']}');
        debugPrint('  Google avatar: ${userData['google_avatar']}');
        debugPrint('  Is avatar skipped: $hasSkippedAvatar');
        debugPrint(
          '  AccountDataProvider avatar: ${_accountDataProvider.avatar.value}',
        );
        debugPrint(
          '  AccountDataProvider googleAvatar: ${_accountDataProvider.googleAvatar.value}',
        );
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
      // Handle case where SupabaseService might not be initialized yet
      if (_serviceChecked) {
        try {
          _supabaseService.isAuthenticated.value = false;
        } catch (_) {
          // Ignore if service is not available
        }
        Get.offAllNamed(Routes.LOGIN);
      } else {
        // If services not ready yet, retry after a delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (Get.isRegistered<SplashController>()) {
          checkAuthAndNavigate();
        }
      }
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
  }

  // Helper method to safely check if services are ready
  Future<bool> _ensureServicesReady() async {
    if (_serviceChecked) return true;

    // Check if SupabaseService is available
    if (!Get.isRegistered<SupabaseService>()) {
      debugPrint('SupabaseService not available yet, waiting...');
      return false;
    }

    try {
      _supabaseService = Get.find<SupabaseService>();
      _serviceChecked = true;
      return true;
    } catch (e) {
      debugPrint('Error finding SupabaseService: $e');
      return false;
    }
  }
}

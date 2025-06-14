import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/startup/preloader/cache_manager.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';

class SettingsController extends GetxController {
  final RxBool isLoggingOut = false.obs;

  /// Logout user and clear all cached data
  Future<void> logout() async {
    try {
      isLoggingOut.value = true;

      // Get services
      final supabaseService = Get.find<SupabaseService>();
      final cacheManager = Get.find<CacheManager>();
      final accountDataProvider = Get.find<AccountDataProvider>();

      // Clear all cached data first
      await cacheManager.clearAllCaches();

      // Clear account data provider
      accountDataProvider.clearData();

      // Sign out from Supabase
      await supabaseService.signOut();

      // Navigate to login (this is already handled in supabaseService.signOut())
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to logout: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoggingOut.value = false;
    }
  }

  /// Navigate to a settings sub-page with right-to-left animation
  void navigateToSubPage(String routeName) {
    Get.toNamed(routeName);
  }
}

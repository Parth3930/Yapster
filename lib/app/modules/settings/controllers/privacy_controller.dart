import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class PrivacyController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  // Observable variable for private account setting
  final RxBool isPrivateAccount = false.obs;
  final RxBool isInitialLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPrivacySettings();
  }

  /// Load privacy settings from database
  Future<void> _loadPrivacySettings() async {
    try {
      final currentUser = _supabaseService.currentUser.value;

      if (currentUser == null) {
        debugPrint('No authenticated user found');
        return;
      }

      // Get current privacy setting from profiles table
      final response =
          await _supabaseService.client
              .from('profiles')
              .select('private')
              .eq('user_id', currentUser.id)
              .maybeSingle();

      if (response != null) {
        isPrivateAccount.value = response['private'] ?? false;
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    } finally {
      isInitialLoading.value = false;
    }
  }

  /// Toggle private account setting
  void togglePrivateAccount(bool value) {
    // Immediately update UI for smooth experience
    isPrivateAccount.value = value;

    // Update database in background
    _updatePrivacyInDatabase(value);
  }

  /// Update privacy setting in database
  Future<void> _updatePrivacyInDatabase(bool value) async {
    try {
      final currentUser = _supabaseService.currentUser.value;

      if (currentUser == null) {
        debugPrint('No authenticated user found');
        // Revert the change if user not authenticated
        isPrivateAccount.value = !value;
        return;
      }

      // Update the private field in profiles table
      await _supabaseService.client
          .from('profiles')
          .update({'private': value})
          .eq('user_id', currentUser.id);

      debugPrint('Privacy setting updated: private = $value');
    } catch (e) {
      debugPrint('Error updating privacy setting: $e');
      // Revert the change on error
      isPrivateAccount.value = !value;
    }
  }
}

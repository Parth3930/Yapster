import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class AccountSetupController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final TextEditingController usernameController = TextEditingController();
  final RxBool isLoading = false.obs;

  // Save account data and navigate to home
  Future<void> saveUsername() async {
    if (usernameController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a username',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading.value = true;
      // Store the username value before navigation to avoid accessing controller after disposal
      final username = usernameController.text.trim();
      if (_supabaseService.currentUser.value == null) return;
      final currentUser = _supabaseService.currentUser.value;

      // Update or insert the username in the profiles table
      await _supabaseService.client.from('profiles').upsert({
        'user_id': currentUser!.id,
        'username': username,
      });
      
      // Navigate to home after successful save
      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      debugPrint('Error saving username: $e');
      Get.snackbar(
        'Error',
        'An error occurred',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> skipedAvatar() async {
    try {
      isLoading.value = true;
      if (_supabaseService.currentUser.value == null) return;
      await _supabaseService.client.from('profiles').upsert({
        'user_id': _supabaseService.currentUser.value!.id,
        'avatar': "skiped",
      });
      
      // Navigate to home after skipping
      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      debugPrint('Error skipping avatar: $e');
      Get.snackbar(
        'Error',
        'An error occurred',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }
}

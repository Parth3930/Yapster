import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/splash/controllers/splash_controller.dart';
import '../../../core/utils/supabase_service.dart';

class AccountSetupController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final TextEditingController usernameController = TextEditingController();
  final RxBool isLoading = false.obs;
  final _navigator = Get.find<SplashController>();

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
    } catch (e) {
      debugPrint('Error saving username: $e');
      Get.snackbar(
        'Error',
        'An error occurred',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
      _navigator.checkAuthAndNavigate();
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class AccountSetupController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  final RxBool isLoading = false.obs;

  // Controllers for input fields
  final TextEditingController usernameController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Check if user is already authenticated and has username
    checkAuthAndUsername();

    // Listen for authentication state changes
    ever(_supabaseService.isAuthenticated, (isAuthenticated) {
      // Only proceed if controller is still registered
      if (isAuthenticated &&
          GetInstance().isRegistered<AccountSetupController>()) {
        checkAuthAndUsername();
      }
    });
  }

  // Check if user is authenticated and has username
  Future<void> checkAuthAndUsername() async {
    // Check if the controller is still mounted before proceeding
    if (!GetInstance().isRegistered<AccountSetupController>()) return;

    if (_supabaseService.isAuthenticated.value) {
      final hasUsername = await _supabaseService.checkUserHasUsername();
      if (hasUsername) {
        // Check again if controller is still mounted before navigating
        if (GetInstance().isRegistered<AccountSetupController>()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed(Routes.HOME);
          });
        }
      }
    }
  }

  // Save account data and navigate to home
  Future<void> saveAccountData() async {
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
      final success = await _supabaseService.saveUsername(username);

      if (success) {
        // Navigate to home screen
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.snackbar(
          'Error',
          'Failed to save username',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
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

  @override
  void onClose() {
    // Dispose controllers when the controller is closed
    usernameController.dispose();
    super.onClose();
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class SignUpController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  final RxBool isLoading = false.obs;

  // Controllers for input fields
  final TextEditingController usernameController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Check if user is already authenticated
    if (_supabaseService.isAuthenticated.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.HOME);
      });
    }

    // Listen for authentication state changes
    ever(_supabaseService.isAuthenticated, (isAuthenticated) {
      if (isAuthenticated) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.HOME);
        });
      }
    });
  }

  @override
  void onClose() {
    // Dispose controllers when the controller is closed
    usernameController.dispose();
    super.onClose();
  }
}

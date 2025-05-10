import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class HomeController extends GetxController {
  final supabaseService = Get.find<SupabaseService>();

  // Lifecycle methods
  @override
  void onInit() {
    super.onInit();
    // Check if user is authenticated
    if (!supabaseService.isAuthenticated.value) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.LOGIN);
      });
    }

    // Listen for authentication state changes
    ever(supabaseService.isAuthenticated, (isAuthenticated) {
      if (!isAuthenticated) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.LOGIN);
        });
      }
    });
  }
}

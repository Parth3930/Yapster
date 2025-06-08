import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Helpers {
  // Show a snackbar message
  static void showSnackBar(
    String title,
    String message, {
    bool isError = false,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
          isError
              ? Color.fromRGBO(255, 0, 0, 0.9)
              : Color.fromRGBO(0, 255, 0, 0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(10),
      duration: const Duration(seconds: 3),
    );
  }

  // Format date to readable string
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Check if device is in dark mode
  static bool isDarkMode() {
    return Get.isDarkMode;
  }

  // Get screen size
  static Size getScreenSize() {
    return Get.size;
  }

  // Navigate to a named route - optimized for instant navigation
  static void navigateTo(String routeName, {dynamic arguments}) {
    // Use instant navigation for main app pages
    final mainPages = ['/home', '/profile', '/chat', '/explore', '/create'];
    if (mainPages.contains(routeName)) {
      Get.offNamed(routeName, arguments: arguments);
    } else {
      Get.toNamed(routeName, arguments: arguments);
    }
  }

  // Navigate instantly to main app pages (optimized for bottom navigation)
  static void navigateToMainPage(String routeName, {dynamic arguments}) {
    Get.offNamed(routeName, arguments: arguments);
  }

  // Go back to previous screen
  static void goBack() {
    Get.back();
  }
}

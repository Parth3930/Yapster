import 'package:get/get.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../routes/app_pages.dart';

class ErrorController extends GetxController {
  // Restart app by clearing navigation stack and going to splash screen
  void restartApp() {
    Get.offAllNamed(Routes.SPLASH);
  }
  
  // For more severe errors, you could try to actually restart the app
  // Note: This is platform-specific and may not work on all platforms
  void forceRestart() {
    try {
      if (Platform.isAndroid) {
        exit(0); // Will only work if app is in foreground
      } else {
        // On iOS, we can just navigate back to splash
        restartApp();
      }
    } catch (e) {
      debugPrint('Could not force restart: $e');
      restartApp();
    }
  }
} 
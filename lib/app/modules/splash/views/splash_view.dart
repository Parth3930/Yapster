import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure the controller is registered - this is a safety check for hot reload
    if (!Get.isRegistered<SplashController>()) {
      Get.put(SplashController());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Obx(() {
          // Access the reactive variable safely (this will cause navigation when ready)
          if (Get.isRegistered<SplashController>()) {
            controller.isInitialized.value;
          }

          return Text(
            'Yapster',
            style: TextStyle(
              fontSize: 70,
              fontWeight: FontWeight.bold,
              height: 0.8,
              fontFamily: GoogleFonts.dongle().fontFamily,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }
}

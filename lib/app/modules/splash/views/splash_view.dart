import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure the controller is registered
    try {
      Get.find<SplashController>();
    } catch (_) {
      // If controller doesn't exist, create it
      Get.lazyPut(() => SplashController());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Obx(() {
          try {
            // Access the reactive variable (this will cause navigation when ready)
            controller.isInitialized.value;
          } catch (e) {
            // Ignore errors from controller not being ready
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
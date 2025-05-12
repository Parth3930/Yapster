import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Obx(() {
          controller.isInitialized.value;
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
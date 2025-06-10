import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/videos_controller.dart';

class VideosView extends GetView<VideosController> {
  const VideosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Videos icon
            Image.asset(
              'assets/icons/videos.png',
              width: 80,
              height: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),

            // Coming Soon text
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Videos feature is under development',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      extendBody: true,
      floatingActionButton: const BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

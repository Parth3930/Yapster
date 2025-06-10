import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/create_controller.dart';

class CameraButton extends StatelessWidget {
  final CreateController controller;

  const CameraButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Get shutter button color based on selected mode
      Color shutterColor;
      switch (controller.selectedMode.value) {
        case 'POST':
          shutterColor = Colors.white;
          break;
        case 'STORY':
          shutterColor = Colors.grey;
          break;
        case 'VIDEO':
          shutterColor = Colors.red;
          break;
        default:
          shutterColor = Colors.white;
      }

      // Show recording timer for video mode
      final showTimer =
          controller.selectedMode.value == 'VIDEO' &&
          controller.isRecordingVideo.value;

      // Make the entire component tappable with a GestureDetector
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          debugPrint('CAMERA BUTTON PRESSED');
          // Only process if not already processing
          if (!controller.isProcessingPhoto.value) {
            controller.takePhoto();
          }
        },
        child: Container(
          width: 120, // Larger area for easier tapping
          height: 120, // Larger area for easier tapping
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Recording timer text
              if (showTimer)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${controller.recordingDuration.value}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Button UI (visual only, entire container is clickable)
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle decoration
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                  ),

                  // Inner circle with animation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // The colored button
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 1.0,
                          end: controller.isButtonPressed.value ? 0.85 : 1.0,
                        ),
                        duration: const Duration(milliseconds: 150),
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: shutterColor,
                                shape:
                                    controller.selectedMode.value == 'VIDEO' &&
                                            controller.isRecordingVideo.value
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                borderRadius:
                                    controller.selectedMode.value == 'VIDEO' &&
                                            controller.isRecordingVideo.value
                                        ? BorderRadius.circular(12)
                                        : null,
                              ),
                            ),
                          );
                        },
                      ),

                      // Loading indicator - only shows when processing
                      if (controller.isProcessingPhoto.value)
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              shutterColor == Colors.white
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

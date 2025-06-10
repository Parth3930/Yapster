import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/create_controller.dart';

class CreateView extends GetView<CreateController> {
  const CreateView({super.key});

  BottomNavAnimationController get _bottomNavController =>
      Get.find<BottomNavAnimationController>();

  @override
  Widget build(BuildContext context) {
    // Initialize camera without waiting for it
    // This avoids blocking the UI while camera initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.ensureCameraInitialized();
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Stop camera when leaving create page
          debugPrint('Leaving create page, stopping camera');
          controller.stopCamera();
          // Show bottom navigation when user goes back
          _bottomNavController.onReturnToHome();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.85,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: Obx(() {
                  final isInitialized = controller.isCameraInitialized.value;
                  final cameraController = controller.cameraController;

                  if (cameraController != null &&
                      isInitialized &&
                      cameraController.value.isInitialized) {
                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: cameraController.value.previewSize!.height,
                        height: cameraController.value.previewSize!.width,
                        child: CameraPreview(cameraController),
                      ),
                    );
                  }

                  // Just show black background without any loader or text
                  return Container(color: Colors.black);
                }),
              ),
            ),

            // Top status bar (always visible)
            _buildTopBar(context),

            // Right side controls (always visible)
            _buildRightControls(context),

            // Camera capture controls (always visible)
            _buildCameraControls(context),

            // Timer feedback text (center of screen)
            _buildTimerFeedback(context),

            // Bottom controls (always visible)
            _buildBottomControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).padding.top + 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                GestureDetector(
                  onTap: () {
                    debugPrint('Create page cross button tapped');
                    // Stop camera before navigating away
                    controller.stopCamera();
                    _bottomNavController.onReturnToHome();
                    Get.back();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.xmark,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // Placeholder for symmetry
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightControls(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: Column(
        children: [
          // Camera switch button
          _buildIconButton(
            icon: FontAwesomeIcons.cameraRotate,
            onTap: controller.switchCamera,
          ),

          const SizedBox(height: 16),

          // Flash button
          _buildFlashButton(),

          const SizedBox(height: 16),

          // Timer button
          _buildTimerButton(),
        ],
      ),
    );
  }

  /// Helper function to create consistent icon buttons for create view controls
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    double size = 25,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        child: FaIcon(icon, size: size, color: color ?? Colors.white),
      ),
    );
  }

  Widget _buildFlashButton() {
    return Obx(() {
      // Use FontAwesome lightning icons for different flash modes
      IconData flashIcon;
      Color iconColor;

      // Check if flash is available (typically only on rear camera)
      bool isFlashAvailable = controller.isRearCamera.value;

      if (!isFlashAvailable) {
        // Flash not available (front camera)
        flashIcon = FontAwesomeIcons.bolt;
        iconColor = Colors.grey.withValues(alpha: 0.3);
      } else {
        switch (controller.flashMode.value) {
          case 'on':
            flashIcon = FontAwesomeIcons.bolt;
            iconColor = Colors.yellow;
            break;
          case 'auto':
            flashIcon = FontAwesomeIcons.boltLightning;
            iconColor = Colors.orange;
            break;
          case 'off':
          default:
            flashIcon = FontAwesomeIcons.bolt;
            iconColor = Colors.white.withValues(alpha: 0.6);
            break;
        }
      }

      return _buildIconButton(
        icon: flashIcon,
        onTap:
            isFlashAvailable
                ? controller.toggleFlash
                : () {
                  // Do nothing if flash not available
                  debugPrint('Flash not available on front camera');
                },
        color: iconColor,
      );
    });
  }

  Widget _buildTimerButton() {
    return Obx(() {
      return _buildIconButton(
        icon: FontAwesomeIcons.clock,
        onTap: () {
          // Cycle through timer options: 0 -> 3 -> 10 -> 0
          int nextTimer =
              controller.timerSeconds.value == 0
                  ? 3
                  : controller.timerSeconds.value == 3
                  ? 10
                  : 0;
          controller.setTimer(nextTimer);
        },
        color: controller.timerSeconds.value > 0 ? Colors.yellow : Colors.white,
      );
    });
  }

  Widget _buildCameraControls(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.15 + 20,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gallery button - moved closer to center
            GestureDetector(
              onTap: controller.pickImages,
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/uploadIcons/gallery.png',
                  width: 30,
                  height: 30,
                ),
              ),
            ),

            const SizedBox(width: 40),
            GestureDetector(
              onTap: controller.takePhoto,
              child: Obx(() {
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

                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: shutterColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(width: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerFeedback(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
      left: 0,
      right: 0,
      child: const SizedBox(), // Empty widget, hiding timer feedback completely
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),

            // Mode tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeTab('STORY'),
                const SizedBox(width: 40),
                _buildModeTab('VIDEO'),
                const SizedBox(width: 40),
                _buildModeTab('POST'),
              ],
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String mode) {
    return GestureDetector(
      onTap: () {
        debugPrint('Mode tab tapped: $mode');
        controller.setMode(mode);
      },
      child: Obx(() {
        final isSelected = controller.selectedMode.value == mode;
        return Text(
          mode,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }),
    );
  }
}

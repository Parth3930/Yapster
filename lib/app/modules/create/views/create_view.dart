import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/create_controller.dart';

class CreateView extends GetView<CreateController> {
  const CreateView({super.key});

  BottomNavAnimationController get _bottomNavController =>
      Get.find<BottomNavAnimationController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (!controller.isCameraInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return Stack(
          children: [
            // Camera preview
            Positioned.fill(child: CameraPreview(controller.cameraController!)),

            // Top status bar
            _buildTopBar(context),

            // Right side controls
            _buildRightControls(context),

            // Bottom controls
            _buildBottomControls(context),
          ],
        );
      }),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                GestureDetector(
                  onTap:
                      () => {_bottomNavController.onReturnToHome(), Get.back()},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // Title
                const Text(
                  'Yap Upload',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
      top: MediaQuery.of(context).padding.top + 80,
      right: 16,
      child: Column(
        children: [
          // Camera switch button
          GestureDetector(
            onTap: controller.switchCamera,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
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

  Widget _buildFlashButton() {
    return GestureDetector(
      onTap: controller.toggleFlash,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Obx(() {
          IconData flashIcon;
          switch (controller.flashMode.value) {
            case 'on':
              flashIcon = Icons.flash_on;
              break;
            case 'auto':
              flashIcon = Icons.flash_auto;
              break;
            default:
              flashIcon = Icons.flash_off;
          }
          return Icon(flashIcon, color: Colors.white, size: 24);
        }),
      ),
    );
  }

  Widget _buildTimerButton() {
    return GestureDetector(
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Obx(() {
          return controller.timerSeconds.value == 0
              ? const Icon(Icons.timer_off, color: Colors.white, size: 24)
              : Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 24),
                  Text(
                    '${controller.timerSeconds.value}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
        }),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Positioned(
      bottom: 0,
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

            // Capture controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery button
                  GestureDetector(
                    onTap: controller.pickImages,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Capture button
                  GestureDetector(
                    onTap: controller.takePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  // Mode selector placeholder
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

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
      onTap: () => controller.setMode(mode),
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

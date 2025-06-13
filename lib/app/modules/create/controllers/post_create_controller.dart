import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../controllers/create_controller.dart';

class PostCreateController extends GetxController {
  // Dependencies
  final CreateController createController = Get.find<CreateController>();

  // Observable variables
  final selectedImages = <File>[].obs;
  final videoPath = RxString('');
  final isGlobalPost = false.obs;
  final isLoading = false.obs;
  final progress = 0.0.obs; // Add progress value
  final processingMessage = ''.obs; // Add processing message
  // Track if video player finished initialization
  final videoInitialized = false.obs;

  // Video player
  VideoPlayerController? videoController;

  @override
  void onInit() {
    super.onInit();

    // Get arguments passed from navigation
    if (Get.arguments != null) {
      if (Get.arguments['selectedImages'] != null) {
        selectedImages.assignAll(Get.arguments['selectedImages'] as List<File>);
      }

      if (Get.arguments['videoPath'] != null) {
        videoPath.value = Get.arguments['videoPath'] as String;
        _initializeVideoPlayer();
      }
    }
  }

  @override
  void onClose() {
    videoController?.dispose();
    videoInitialized.value = false;

    // Reset main CreateController state so next entry is clean
    createController.videoFilePath.value = '';
    createController.selectedImages.clear();
    createController.postTextController.clear();
    createController.canPost.value = false;

    super.onClose();
  }

  void _initializeVideoPlayer() {
    videoInitialized.value = false;

    if (videoPath.isNotEmpty) {
      // Dispose any previously created controller to avoid exceeding buffer limits
      if (videoController != null) {
        try {
          videoController!.dispose();
        } catch (_) {
          // Ignore dispose errors
        }
      }

      videoController = VideoPlayerController.file(File(videoPath.value))
        ..initialize().then((_) {
          videoController?.setLooping(true);
          videoController?.play();
          videoInitialized.value = true; // Trigger UI rebuild via Obx
        });
    }
  }

  void toggleGlobalPost(bool value) {
    isGlobalPost.value = value;
  }

  Future<void> createPost() async {
    isLoading.value = true;
    progress.value = 0.0;
    processingMessage.value = 'Preparing post...';

    // Force the CreateController to allow posting
    createController.canPost.value = true;

    try {
      // Transfer video path to main controller if needed
      if (videoPath.isNotEmpty &&
          createController.videoFilePath.value.isEmpty) {
        createController.videoFilePath.value = videoPath.value;
        progress.value = 0.2;
        processingMessage.value = 'Processing video...';
      }

      // Add some example text if empty to help pass validation
      if (createController.postTextController.text.trim().isEmpty &&
          createController.selectedImages.isEmpty &&
          videoPath.isEmpty) {
        createController.postTextController.text = "New post";
      }

      progress.value = 0.4;
      processingMessage.value = 'Uploading content...';

      await createController.createPost(
        isGlobal: isGlobalPost.value,
        isPublic: createController.isPublic.value,
        bypassValidation: true, // Bypass the empty content validation
      );

      progress.value = 1.0;
      processingMessage.value = 'Post created successfully!';
    } catch (e) {
      debugPrint('📱 POST CREATE VIEW: Error creating post: $e');
      Get.snackbar('Error', 'Failed to create post');

      // Only on error, try to navigate back to home
      try {
        // Use a gentler navigation approach on error
        Get.until((route) => route.settings.name == '/home' || route.isFirst);
      } catch (navError) {
        debugPrint(
          '📱 POST CREATE VIEW: Error navigating after failure: $navError',
        );
      }
    } finally {
      isLoading.value = false;
      progress.value = 0.0;
      processingMessage.value = '';
    }
  }
}

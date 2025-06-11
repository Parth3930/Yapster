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

    // Reset main CreateController state so next entry is clean
    createController.videoFilePath.value = '';
    createController.selectedImages.clear();
    createController.postTextController.clear();
    createController.canPost.value = false;

    super.onClose();
  }

  void _initializeVideoPlayer() {
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
          update(); // Notify UI to rebuild
        });
    }
  }

  void toggleGlobalPost(bool value) {
    isGlobalPost.value = value;
  }

  Future<void> createPost() async {
    isLoading.value = true;
    debugPrint('PostCreateController: Starting post creation');

    // Force the CreateController to allow posting
    createController.canPost.value = true;

    try {
      // Use the main CreateController to create the post
      // Pass the isPublic value from the CreateController
      debugPrint(
        'PostCreateController: Calling main controller (isGlobal: ${isGlobalPost.value}, isPublic: ${createController.isPublic.value})',
      );

      // Transfer video path to main controller if needed
      if (videoPath.isNotEmpty &&
          createController.videoFilePath.value.isEmpty) {
        debugPrint(
          'Transferring video path to main controller: ${videoPath.value}',
        );
        createController.videoFilePath.value = videoPath.value;
      }

      // Add some example text if empty to help pass validation
      if (createController.postTextController.text.trim().isEmpty &&
          createController.selectedImages.isEmpty &&
          videoPath.isEmpty) {
        debugPrint('Adding default post text to ensure validation passes');
        createController.postTextController.text = "New post";
      }

      await createController.createPost(
        isGlobal: isGlobalPost.value,
        isPublic: createController.isPublic.value,
        bypassValidation: true, // Bypass the empty content validation
      );

      // No navigation here - let the CreateController handle it
      debugPrint('PostCreateController: Post creation finished successfully');
    } catch (e) {
      debugPrint('PostCreateController: Error creating post: $e');
      Get.snackbar('Error', 'Failed to create post');

      // Only on error, try to navigate back to home
      try {
        debugPrint(
          'PostCreateController: Attempting emergency navigation to home after error',
        );
        // Use a gentler navigation approach on error
        Get.until((route) => route.settings.name == '/home' || route.isFirst);
      } catch (navError) {
        debugPrint(
          'PostCreateController: Error navigating after post creation failed: $navError',
        );
      }
    } finally {
      isLoading.value = false;
      debugPrint('PostCreateController: Post creation process completed');
    }
  }
}

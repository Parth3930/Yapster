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
    super.onClose();
  }
  
  void _initializeVideoPlayer() {
    if (videoPath.isNotEmpty) {
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
  
  void createPost() {
    isLoading.value = true;
    
    try {
      // Use the main CreateController to create the post
      createController.createPost(isGlobal: isGlobalPost.value);
      
      // Navigate back to home
      Get.until((route) => route.settings.name == '/home');
    } catch (e) {
      debugPrint('Error creating post: $e');
      Get.snackbar('Error', 'Failed to create post');
    } finally {
      isLoading.value = false;
    }
  }
}
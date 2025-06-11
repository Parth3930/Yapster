import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoEditController extends GetxController {
  // Observable variables
  final isLoading = false.obs;
  final videoFile = Rx<File?>(null);
  final startValue = 0.0.obs;
  final endValue = 0.0.obs;
  
  // Non-reactive variables
  final Trimmer trimmer = Trimmer();
  VideoPlayerController? videoPlayerController;
  
  @override
  void onInit() {
    super.onInit();
    
    // Get arguments passed from navigation
    if (Get.arguments != null && Get.arguments['videoFile'] != null) {
      videoFile.value = Get.arguments['videoFile'] as File;
      initVideoPlayer();
    } else {
      Get.snackbar('Error', 'No video file provided');
      Get.back();
    }
  }
  
  @override
  void onClose() {
    videoPlayerController?.dispose();
    super.onClose();
  }
  
  Future<void> initVideoPlayer() async {
    isLoading.value = true;
    
    try {
      await trimmer.loadVideo(videoFile: videoFile.value!);
      videoPlayerController = VideoPlayerController.file(videoFile.value!);
      await videoPlayerController!.initialize();
      videoPlayerController!.setLooping(true);
      videoPlayerController!.play();
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      Get.snackbar('Error', 'Failed to load video');
    } finally {
      isLoading.value = false;
    }
  }
  
  void updateStartValue(double value) {
    startValue.value = value;
  }
  
  void updateEndValue(double value) {
    endValue.value = value;
  }
  
  Future<void> saveTrimmedVideo() async {
    isLoading.value = true;
    
    try {
      // Use the values captured from the trim slider
      double start = startValue.value;
      double end = endValue.value;
      
      // If values are still zero, default to entire video up to 1 minute
      if (start == 0.0 && end == 0.0) {
        start = 0.0;
        // Get video duration and cap it at 1 minute
        try {
          final videoDuration =
              videoPlayerController?.value.duration.inMilliseconds.toDouble() ?? 60000.0;
          end = videoDuration > 60000.0 ? 60000.0 : videoDuration;
        } catch (e) {
          debugPrint('Error getting video duration: $e');
          end = 60000.0;
        }
      }
      
      // Ensure video is not longer than 1 minute (60000 milliseconds)
      if (end - start > 60000) {
        end = start + 60000;
        Get.snackbar(
          'Video Trimmed',
          'Video has been trimmed to 1 minute maximum',
          backgroundColor: Colors.black,
          colorText: Colors.white,
        );
      }
      
      await trimmer.saveTrimmedVideo(
        startValue: start,
        endValue: end,
        onSave: (outputPath) {
          isLoading.value = false;
          
          if (outputPath != null) {
            // Return the trimmed video
            Get.back(result: {'editedVideo': File(outputPath)});
          } else {
            Get.snackbar('Error', 'Failed to save video');
          }
        },
      );
    } catch (e) {
      isLoading.value = false;
      debugPrint('Error saving trimmed video: $e');
      Get.snackbar('Error', 'Failed to save video');
    }
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/profile/controllers/profile_posts_controller.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';

class CreateController extends GetxController {
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final PostRepository _postRepository = Get.find<PostRepository>();
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final UserPostsCacheService _cacheService = Get.find<UserPostsCacheService>();
  final ImagePicker _picker = ImagePicker();

  // User info - use reactive data from AccountDataProvider
  RxString get username => _accountDataProvider.username;
  RxString get userAvatar => _accountDataProvider.avatar;
  final RxBool isVerified = false.obs;

  // Post content
  final TextEditingController postTextController = TextEditingController();
  final RxString selectedPostType = 'text'.obs;
  final RxList<File> selectedImages = <File>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool canPost = false.obs;

  // Media URLs
  final RxString imageUrl = ''.obs;
  final RxString gifUrl = ''.obs;
  final RxString stickerUrl = ''.obs;

  // Camera functionality
  CameraController? cameraController;
  final RxBool isCameraInitialized = false.obs;
  final RxBool isRearCamera = true.obs; // true for rear, false for front
  final RxString flashMode = 'off'.obs; // off, on, auto
  final RxInt timerSeconds = 0.obs; // 0, 3, 10
  final RxString selectedMode = 'POST'.obs; // STORY, VIDEO, POST
  List<CameraDescription> cameras = [];

  @override
  void onInit() {
    super.onInit();
    // Listen to content changes to enable/disable post button
    postTextController.addListener(_updateCanPost);
    initializeCamera();
  }

  @override
  void onClose() {
    postTextController.dispose();
    cameraController?.dispose();
    super.onClose();
  }

  void _updateCanPost() {
    canPost.value =
        postTextController.text.trim().isNotEmpty || selectedImages.isNotEmpty;
  }

  void setPostType(String type) {
    selectedPostType.value = type;
  }

  /// Initialize camera
  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        await _initializeCameraController();
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  /// Initialize camera controller
  Future<void> _initializeCameraController() async {
    try {
      final camera =
          isRearCamera.value
              ? cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              : cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
              );

      cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: selectedMode.value == 'VIDEO',
      );

      await cameraController!.initialize();
      isCameraInitialized.value = true;

      // Set flash mode
      await _updateFlashMode();
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      isCameraInitialized.value = false;
    }
  }

  /// Switch between front and rear camera
  Future<void> switchCamera() async {
    if (cameras.length < 2) return;

    isRearCamera.value = !isRearCamera.value;
    isCameraInitialized.value = false;

    await cameraController?.dispose();
    await _initializeCameraController();
  }

  /// Toggle flash mode
  void toggleFlash() {
    switch (flashMode.value) {
      case 'off':
        flashMode.value = 'on';
        break;
      case 'on':
        flashMode.value = 'auto';
        break;
      case 'auto':
        flashMode.value = 'off';
        break;
    }
    _updateFlashMode();
  }

  /// Update flash mode on camera
  Future<void> _updateFlashMode() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    try {
      switch (flashMode.value) {
        case 'off':
          await cameraController!.setFlashMode(FlashMode.off);
          break;
        case 'on':
          await cameraController!.setFlashMode(FlashMode.always);
          break;
        case 'auto':
          await cameraController!.setFlashMode(FlashMode.auto);
          break;
      }
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  /// Set timer
  void setTimer(int seconds) {
    timerSeconds.value = seconds;
  }

  /// Set capture mode
  void setMode(String mode) {
    selectedMode.value = mode;
    // Reinitialize camera with audio if switching to video
    if (mode == 'VIDEO' && cameraController != null) {
      _initializeCameraController();
    }
  }

  /// Take photo
  Future<void> takePhoto() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Apply timer if set
      if (timerSeconds.value > 0) {
        await Future.delayed(Duration(seconds: timerSeconds.value));
      }

      final XFile photo = await cameraController!.takePicture();
      selectedImages.add(File(photo.path));
      selectedPostType.value = 'image';
      _updateCanPost();

      // Navigate to post creation or handle based on mode
      if (selectedMode.value == 'POST') {
        // Stay on camera for now, user can navigate to text post creation
      } else if (selectedMode.value == 'STORY') {
        // Navigate to story creation
        Get.toNamed('/create-story');
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      Get.snackbar('Error', 'Failed to take photo');
    }
  }

  /// Pick images from gallery
  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        // Limit to 3 images maximum
        final imagesToAdd = images.take(3 - selectedImages.length).toList();

        for (final image in imagesToAdd) {
          selectedImages.add(File(image.path));
        }

        if (selectedImages.isNotEmpty) {
          selectedPostType.value = 'image';
        }

        _updateCanPost();
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      Get.snackbar(
        'Error',
        'Failed to pick images',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Remove image at index
  void removeImage(int index) {
    if (index >= 0 && index < selectedImages.length) {
      selectedImages.removeAt(index);

      if (selectedImages.isEmpty && postTextController.text.trim().isNotEmpty) {
        selectedPostType.value = 'text';
      } else if (selectedImages.isEmpty &&
          postTextController.text.trim().isEmpty) {
        selectedPostType.value = 'text';
      }

      _updateCanPost();
    }
  }

  /// Create and publish post
  Future<void> createPost() async {
    if (!canPost.value) return;

    try {
      isLoading.value = true;

      final currentUser = _supabase.client.auth.currentUser;
      if (currentUser == null) {
        Get.snackbar('Error', 'User not authenticated');
        return;
      }

      // Create post model
      final post = PostModel(
        id: '', // Will be generated by database
        userId: currentUser.id,
        content: postTextController.text.trim(),
        postType: selectedPostType.value,
        metadata: {}, // Will be updated with image URLs after upload
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create post with images
      final postId = await _postRepository.createPostWithImages(
        post,
        selectedImages.toList(),
      );

      if (postId != null) {
        // Create the complete post model with the generated ID
        final createdPost = post.copyWith(id: postId);

        // Add to cache immediately
        _cacheService.addPostToCache(currentUser.id, createdPost);

        // Add to profile posts controller if it exists
        try {
          final profileController = Get.find<ProfilePostsController>(
            tag: 'profile_threads_current',
          );
          profileController.addNewPost(createdPost);
        } catch (e) {
          debugPrint('Profile posts controller not found: $e');
        }

        // Add to feed controller if it exists
        try {
          final feedController = Get.find<PostsFeedController>();
          feedController.addNewPost(createdPost);
        } catch (e) {
          debugPrint('Posts feed controller not found: $e');
        }

        // Clear form
        _clearForm();

        // Show bottom navigation and navigate back to home
        try {
          final bottomNavController = Get.find<BottomNavAnimationController>();
          bottomNavController.onReturnToHome();
        } catch (e) {
          debugPrint('BottomNavAnimationController not found: $e');
        }

        // Navigate back to home
        Get.offAllNamed('/home');
      } else {
        Get.snackbar(
          'Error',
          'Failed to create post',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      Get.snackbar(
        'Error',
        'Failed to create post: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear form data
  void _clearForm() {
    postTextController.clear();
    selectedImages.clear();
    selectedPostType.value = 'text';
    canPost.value = false;
  }

  /// Get image layout for UI
  String getImageLayout() {
    switch (selectedImages.length) {
      case 1:
        return 'single';
      case 2:
        return 'double';
      case 3:
        return 'triple';
      default:
        return 'none';
    }
  }
}

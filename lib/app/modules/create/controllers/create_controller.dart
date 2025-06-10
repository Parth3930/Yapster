import 'dart:io';
import 'dart:async';
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
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/models/story_model.dart';
import 'package:yapster/app/modules/home/controllers/stories_home_controller.dart';

class CreateController extends GetxController {
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final PostRepository _postRepository = Get.find<PostRepository>();
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final UserPostsCacheService _cacheService = Get.find<UserPostsCacheService>();
  final ImagePicker _picker = ImagePicker();

  // Story repository - lazy initialization to avoid dependency issues
  StoryRepository? _storyRepository;

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
  final RxBool isCameraSwitching = false.obs; // Track camera switching state
  final RxBool isRearCamera = true.obs; // true for rear, false for front
  final RxString flashMode = 'off'.obs; // off, on, auto
  final RxInt timerSeconds = 0.obs; // 0, 3, 10
  final RxString selectedMode = 'POST'.obs; // STORY, VIDEO, POST
  final RxString timerFeedback = ''.obs; // For showing timer feedback text
  List<CameraDescription> cameras = [];

  // Cache camera controllers for instant switching
  CameraController? _rearCameraController;
  CameraController? _frontCameraController;
  final RxBool _rearCameraReady = false.obs;
  final RxBool _frontCameraReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to content changes to enable/disable post button
    postTextController.addListener(_updateCanPost);

    // DO NOT initialize camera here - only when actually needed
    // Camera will be initialized when ensureCameraInitialized() is called from the view
    debugPrint(
      'CreateController initialized - camera will be initialized when needed',
    );
  }

  @override
  void onReady() {
    super.onReady();
    // Check if mode is passed via arguments and set it after widget is ready
    final arguments = Get.arguments as Map<String, dynamic>?;
    final mode = arguments?['mode'] as String?;
    debugPrint('Create page mode argument: $mode');
    debugPrint('All arguments: $arguments');
    if (mode != null && ['STORY', 'VIDEO', 'POST'].contains(mode)) {
      selectedMode.value = mode;
      debugPrint('Mode set to: ${selectedMode.value}');
      // Force UI update
      update();
    } else {
      debugPrint(
        'No valid mode argument found, keeping default: ${selectedMode.value}',
      );
    }
  }

  /// Ensure camera is initialized (can be called multiple times safely)
  void ensureCameraInitialized() {
    if (!isCameraInitialized.value ||
        cameraController == null ||
        !cameraController!.value.isInitialized) {
      debugPrint('Starting camera initialization in background...');

      // Start initialization in the background without awaiting
      _initCameraInBackground();
    } else {
      debugPrint('Camera already initialized');
    }
  }

  /// Initialize camera in background to avoid blocking UI
  Future<void> _initCameraInBackground() async {
    try {
      // Make sure we have cameras available first
      if (cameras.isEmpty) {
        cameras = await availableCameras();
        debugPrint('Available cameras: ${cameras.length}');
      }

      if (cameras.isNotEmpty) {
        await _initializeSingleCamera();
      } else {
        debugPrint('No cameras available');
        isCameraInitialized.value = false;
      }
    } catch (e) {
      debugPrint('Error initializing camera in background: $e');
      isCameraInitialized.value = false;
    }
  }

  @override
  void onClose() async {
    debugPrint('CreateController: Disposing resources');

    // Stop camera (no longer disposes controllers, just nullifies them)
    stopCamera();

    // Stop any active recording timer
    _stopRecordingTimer();

    // Dispose other non-camera controllers
    postTextController.dispose();

    // DO NOT dispose camera controllers - this causes the IllegalStateException
    // Let garbage collection handle them

    // Additional reset of camera state (stopCamera already does some of this)
    isCameraSwitching.value = false;

    super.onClose();
  }

  /// Stop camera when leaving create page
  void stopCamera() {
    try {
      debugPrint('Stopping camera and properly disposing controllers');

      // Properly dispose the camera controllers to release camera resources
      if (cameraController != null && cameraController!.value.isInitialized) {
        cameraController!.dispose();
        debugPrint('Main camera controller disposed');
      }

      if (_rearCameraController != null &&
          _rearCameraController!.value.isInitialized) {
        _rearCameraController!.dispose();
        debugPrint('Rear camera controller disposed');
      }

      if (_frontCameraController != null &&
          _frontCameraController!.value.isInitialized) {
        _frontCameraController!.dispose();
        debugPrint('Front camera controller disposed');
      }

      // Clear all controller references
      cameraController = null;
      _rearCameraController = null;
      _frontCameraController = null;

      // Reset camera state
      isCameraInitialized.value = false;
      _rearCameraReady.value = false;
      _frontCameraReady.value = false;

      debugPrint('Camera resources released and references cleared');
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
  }

  void _updateCanPost() {
    canPost.value =
        postTextController.text.trim().isNotEmpty || selectedImages.isNotEmpty;
  }

  void setPostType(String type) {
    selectedPostType.value = type;
  }

  /// Fallback to single camera initialization
  Future<void> _initializeSingleCamera() async {
    try {
      debugPrint('Initializing single camera...');

      // Ensure we have cameras available
      if (cameras.isEmpty) {
        cameras = await availableCameras();
        debugPrint('Available cameras: ${cameras.length}');

        if (cameras.isEmpty) {
          debugPrint('No cameras available');
          isCameraInitialized.value = false;
          return;
        }
      }

      // Properly dispose the existing controller if it exists
      if (cameraController != null && cameraController!.value.isInitialized) {
        await cameraController!.dispose();
        debugPrint('Disposed existing camera controller during initialization');
      }
      cameraController = null;

      // Select appropriate camera
      final camera =
          isRearCamera.value
              ? cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
                orElse: () => cameras.first,
              )
              : cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
                orElse: () => cameras.first,
              );

      // Create new controller
      cameraController = CameraController(
        camera,
        ResolutionPreset.high, // Use high instead of max for better performance
        enableAudio: selectedMode.value == 'VIDEO',
      );

      // Initialize new controller
      await cameraController!.initialize();

      // Verify camera is actually initialized before setting the flag
      if (cameraController!.value.isInitialized) {
        // Only update flash mode if camera successfully initialized
        await _updateFlashMode();
        isCameraInitialized.value = true;
        debugPrint(
          'Single camera initialized successfully: ${camera.lensDirection}',
        );
      } else {
        debugPrint('Single camera failed to initialize properly');
        isCameraInitialized.value = false;
      }
    } catch (e) {
      debugPrint('Error initializing single camera: $e');
      isCameraInitialized.value = false;
    }
  }

  /// Switch between front and rear camera with optimized switching
  Future<void> switchCamera() async {
    if (cameras.length < 2) return;

    try {
      // Prevent multiple simultaneous switches
      if (isCameraSwitching.value) return;
      isCameraSwitching.value = true;

      debugPrint(
        'Switching camera from ${isRearCamera.value ? "rear" : "front"} to ${!isRearCamera.value ? "rear" : "front"}',
      );

      // Toggle camera direction first
      isRearCamera.value = !isRearCamera.value;

      // Always recreate controller to avoid conflicts with mode switching
      await _recreateCameraController();
    } catch (e) {
      debugPrint('Error switching camera: $e');
      // Revert camera direction on error
      isRearCamera.value = !isRearCamera.value;
    } finally {
      isCameraSwitching.value = false;
    }
  }

  /// Recreate camera controller for the current camera direction
  Future<void> _recreateCameraController() async {
    try {
      // Temporarily set as not initialized
      isCameraInitialized.value = false;

      // Properly dispose the old camera controller
      if (cameraController != null && cameraController!.value.isInitialized) {
        await cameraController!.dispose();
        debugPrint('Disposed old camera controller during recreation');
      }
      cameraController = null;

      final camera =
          isRearCamera.value
              ? cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
                orElse: () => cameras.first,
              )
              : cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
                orElse: () => cameras.last,
              );

      // Create a new controller
      cameraController = CameraController(
        camera,
        ResolutionPreset.high, // Use high instead of max for better performance
        enableAudio: selectedMode.value == 'VIDEO',
      );

      // Initialize the new controller
      await cameraController!.initialize();

      // Only if initialization completed successfully, apply flash mode
      if (cameraController!.value.isInitialized) {
        await _updateFlashMode();
        // Set camera as initialized after everything is ready
        isCameraInitialized.value = true;
        debugPrint(
          'Camera recreated for: ${isRearCamera.value ? "rear" : "front"}',
        );
      } else {
        debugPrint('Camera initialization failed');
        isCameraInitialized.value = false;
      }
    } catch (e) {
      debugPrint('Error recreating camera controller: $e');
      isCameraInitialized.value = false;
    }
  }

  /// Toggle flash mode
  Future<void> toggleFlash() async {
    debugPrint('Toggle flash called - current mode: ${flashMode.value}');

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

    debugPrint('Flash mode changing to: ${flashMode.value}');
    await _updateFlashMode();
    debugPrint('Flash mode changed to: ${flashMode.value}');
  }

  /// Update flash mode on camera
  Future<void> _updateFlashMode() async {
    try {
      debugPrint('_updateFlashMode called with flashMode: ${flashMode.value}');

      // Safety check: make sure camera controller exists and is initialized
      if (cameraController == null || !cameraController!.value.isInitialized) {
        debugPrint('Cannot set flash mode: camera not initialized');
        return;
      }

      // Safety check: make sure cameras list is not empty
      if (cameras.isEmpty) {
        debugPrint('Cannot set flash mode: cameras list is empty');
        return;
      }

      // Check if current camera supports flash (usually only rear cameras do)
      CameraDescription? currentCamera;
      try {
        currentCamera = cameras.firstWhere(
          (camera) =>
              camera.lensDirection ==
              (isRearCamera.value
                  ? CameraLensDirection.back
                  : CameraLensDirection.front),
          orElse: () => cameras.first,
        );
      } catch (e) {
        debugPrint('Error finding current camera: $e');
        return;
      }

      debugPrint(
        'Current camera: ${currentCamera.lensDirection}, isRearCamera: ${isRearCamera.value}',
      );

      // Front cameras typically don't have flash
      if (currentCamera.lensDirection == CameraLensDirection.front) {
        debugPrint('Flash not available on front camera');
        return;
      }

      // Double check the camera controller is still valid
      if (cameraController == null || !cameraController!.value.isInitialized) {
        debugPrint('Camera no longer initialized, skipping flash mode update');
        return;
      }

      FlashMode targetFlashMode;
      switch (flashMode.value) {
        case 'off':
          targetFlashMode = FlashMode.off;
          break;
        case 'on':
          targetFlashMode = FlashMode.torch;
          break;
        case 'auto':
          targetFlashMode = FlashMode.auto;
          break;
        default:
          targetFlashMode = FlashMode.off;
      }

      await cameraController!.setFlashMode(targetFlashMode);
      debugPrint(
        'Flash mode set to: ${flashMode.value} (${targetFlashMode.toString()})',
      );
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
      // If torch mode is not supported, try always mode
      if (e.toString().contains('not supported') && flashMode.value == 'on') {
        try {
          if (cameraController != null &&
              cameraController!.value.isInitialized) {
            await cameraController!.setFlashMode(FlashMode.always);
            debugPrint('Torch not supported, using FlashMode.always instead');
          }
        } catch (e2) {
          debugPrint('FlashMode.always also not supported: $e2');
          flashMode.value = 'off';
        }
      } else if (e.toString().contains('not supported') ||
          e.toString().contains('flash')) {
        flashMode.value = 'off';
        debugPrint('Flash not supported on this camera, reset to off');
      }
    }
  }

  /// Set timer
  void setTimer(int seconds) {
    timerSeconds.value = seconds;

    // Show feedback text for 2 seconds
    if (seconds == 0) {
      timerFeedback.value = 'Timer Off';
    } else {
      timerFeedback.value = '${seconds}s Timer';
    }

    // Clear feedback after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      timerFeedback.value = '';
    });
  }

  /// Set capture mode
  void setMode(String mode) {
    debugPrint('Setting mode to: $mode (previous: ${selectedMode.value})');
    final previousMode = selectedMode.value;
    selectedMode.value = mode;
    debugPrint('Mode set to: ${selectedMode.value}');

    // Only reinitialize camera if switching between modes that require different audio settings
    if (mode == 'VIDEO' &&
        previousMode != 'VIDEO' &&
        cameraController != null) {
      debugPrint('Switching to VIDEO mode, reinitializing camera with audio');
      _reinitializeCameraForVideo();
    } else if (previousMode == 'VIDEO' &&
        mode != 'VIDEO' &&
        cameraController != null) {
      debugPrint(
        'Switching from VIDEO mode, reinitializing camera without audio',
      );
      _reinitializeCameraForPhoto();
    }
  }

  /// Take photo
  // Flag to track if video recording is in progress
  final RxBool isRecordingVideo = false.obs;
  // Video file path
  final RxString videoFilePath = ''.obs;
  // For button animation
  final RxBool isButtonPressed = false.obs;
  // For recording duration in seconds
  final RxInt recordingDuration = 0.obs;
  // Timer instance for video recording
  Timer? _recordingTimer;
  // Flag for processing state
  final RxBool isProcessingPhoto = false.obs;

  Future<void> takePhoto() async {
    debugPrint('🔥 takePhoto called');

    // Set processing flag to true
    isProcessingPhoto.value = true;

    // Trigger button press animation
    isButtonPressed.value = true;
    Future.delayed(const Duration(milliseconds: 150), () {
      isButtonPressed.value = false;
    });

    if (cameraController == null || !cameraController!.value.isInitialized) {
      debugPrint('❌ Camera not initialized, cannot take photo');
      Get.snackbar(
        'Camera Not Ready',
        'Please wait for the camera to initialize',
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );

      // Try to initialize the camera again
      ensureCameraInitialized();
      return;
    }

    try {
      // Handle different modes
      if (selectedMode.value == 'VIDEO') {
        debugPrint(
          '📹 Video mode detected, redirecting to _handleVideoCapture',
        );
        if (cameraController != null && cameraController!.value.isInitialized) {
          await _handleVideoCapture();
        } else {
          debugPrint('❌ Camera not ready for video recording');
          Get.snackbar('Error', 'Camera not ready for video recording');
        }
        return;
      }

      // Apply timer if set
      if (timerSeconds.value > 0) {
        await Future.delayed(Duration(seconds: timerSeconds.value));
      }

      // Ensure flash mode is set before taking photo
      if (isRearCamera.value && flashMode.value != 'off') {
        FlashMode photoFlashMode;
        switch (flashMode.value) {
          case 'on':
            photoFlashMode = FlashMode.always;
            break;
          case 'auto':
            photoFlashMode = FlashMode.auto;
            break;
          default:
            photoFlashMode = FlashMode.off;
        }

        try {
          await cameraController!.setFlashMode(photoFlashMode);
          debugPrint('Flash mode set for photo: $photoFlashMode');
        } catch (e) {
          debugPrint('Error setting flash for photo: $e');
        }
      }

      final XFile photo = await cameraController!.takePicture();

      if (selectedMode.value == 'POST') {
        // Navigate to image crop/edit page
        _navigateToImageEditPage(File(photo.path));
      } else if (selectedMode.value == 'STORY') {
        // Create story directly with the captured image
        await _createStoryWithImage(File(photo.path));
      }

      // Reset processing flag
      isProcessingPhoto.value = false;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      Get.snackbar('Error', 'Failed to take photo');

      // Reset processing flag on error
      isProcessingPhoto.value = false;
    }
  }

  Future<void> _handleVideoCapture() async {
    debugPrint(
      '📹 _handleVideoCapture called, isRecording: ${isRecordingVideo.value}',
    );

    if (isRecordingVideo.value) {
      // Stop recording
      try {
        debugPrint('📹 Attempting to stop video recording');
        final XFile videoFile = await cameraController!.stopVideoRecording();
        isRecordingVideo.value = false;
        videoFilePath.value = videoFile.path;

        // Stop the duration timer
        _stopRecordingTimer();

        debugPrint('📹 Video recording stopped: ${videoFile.path}');

        // Provide user feedback
        Get.snackbar(
          'Success',
          'Video recorded successfully',
          backgroundColor: Colors.green.withOpacity(0.7),
          colorText: Colors.white,
        );

        // Navigate to video edit page
        _navigateToVideoEditPage(File(videoFile.path));
      } catch (e) {
        debugPrint('❌ Error stopping video recording: $e');
        Get.snackbar('Error', 'Failed to stop video recording');

        // Make sure to stop the timer if there's an error
        _stopRecordingTimer();
      }
    } else {
      // Start recording
      try {
        debugPrint('📹 Attempting to start video recording');
        await cameraController!.startVideoRecording();
        isRecordingVideo.value = true;

        // Reset and start the duration timer
        recordingDuration.value = 0;
        _startRecordingTimer();

        debugPrint('📹 Video recording started');

        // Provide user feedback
        Get.snackbar(
          'Recording',
          'Video recording in progress',
          backgroundColor: Colors.red.withOpacity(0.7),
          colorText: Colors.white,
          duration: const Duration(seconds: 1),
        );
      } catch (e) {
        debugPrint('❌ Error starting video recording: $e');
        Get.snackbar('Error', 'Failed to start video recording');
        // Reset recording state on error
        isRecordingVideo.value = false;
        _stopRecordingTimer();
      }
    }
  }

  // Start a timer that updates the recording duration every second
  void _startRecordingTimer() {
    // Create a periodic timer that fires every second
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration.value++;
      debugPrint('Recording duration: ${recordingDuration.value}s');
    });
  }

  // Stop the recording timer
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    recordingDuration.value = 0;
  }

  /// Pick media from gallery based on current mode
  Future<void> pickImages() async {
    try {
      if (selectedMode.value == 'VIDEO') {
        // Pick video
        final XFile? video = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 2),
        );

        if (video != null) {
          _navigateToVideoEditPage(File(video.path));
        }
      } else {
        // Pick images
        final List<XFile> images = await _picker.pickMultiImage(
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (images.isNotEmpty) {
          // For POST mode, navigate to edit page with first image
          if (selectedMode.value == 'POST') {
            _navigateToImageEditPage(File(images.first.path));
          } else if (selectedMode.value == 'STORY') {
            // Create story directly with the first image
            await _createStoryWithImage(File(images.first.path));
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking media: $e');
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
  // Navigate to image edit page
  void _navigateToImageEditPage(File imageFile) {
    // Create a temporary image in the selected images list
    selectedImages.clear();
    selectedImages.add(imageFile);
    selectedPostType.value = 'image';

    // Navigate to image edit page
    Get.toNamed(
      '/image-edit',
      arguments: {
        'imageFile': imageFile,
        'aspectRatio': 4 / 5, // Fixed 4:5 ratio for post images
      },
    )?.then((result) {
      if (result != null && result is Map<String, dynamic>) {
        // Handle edited image returned from edit page
        if (result.containsKey('editedImage')) {
          File editedImage = result['editedImage'] as File;
          selectedImages.clear();
          selectedImages.add(editedImage);

          // Navigate to post creation page
          _navigateToPostPage();
        }
      }
    });
  }

  // Navigate to video edit page
  void _navigateToVideoEditPage(File videoFile) {
    // Navigate to video edit page
    Get.toNamed('/video-edit', arguments: {'videoFile': videoFile})?.then((
      result,
    ) {
      if (result != null && result is Map<String, dynamic>) {
        // Handle edited video returned from edit page
        if (result.containsKey('editedVideo')) {
          File editedVideo = result['editedVideo'] as File;
          videoFilePath.value = editedVideo.path;

          // Navigate to post creation page
          _navigateToPostPage();
        }
      }
    });
  }

  // Navigate to post creation page
  void _navigateToPostPage() {
    Get.toNamed(
      '/create-post',
      arguments: {
        'selectedImages': selectedImages.toList(),
        'videoPath':
            videoFilePath.value.isNotEmpty ? videoFilePath.value : null,
      },
    );
  }

  Future<void> createPost({bool isGlobal = false}) async {
    if (!canPost.value) return;

    try {
      isLoading.value = true;

      final currentUser = _supabase.client.auth.currentUser;
      if (currentUser == null) {
        Get.snackbar('Error', 'User not authenticated');
        return;
      }

      // Check if we're posting a video
      bool isVideoPost = videoFilePath.value.isNotEmpty;

      // Create post model
      final post = PostModel(
        id: '', // Will be generated by database
        userId: currentUser.id,
        content: postTextController.text.trim(),
        postType: isVideoPost ? 'video' : selectedPostType.value,
        metadata: {}, // Will be updated with URLs after upload
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        global: isGlobal,
      );

      String? postId;

      if (isVideoPost) {
        // For video posts, create a different upload flow
        // First create post to get ID
        postId = await _postRepository.createPost(post);

        if (postId != null) {
          // Upload video file
          final videoUrl = await _postRepository.uploadPostVideo(
            File(videoFilePath.value),
            currentUser.id,
            postId,
          );

          if (videoUrl != null) {
            // Update post with video URL
            await _postRepository.updatePostWithVideo(postId, videoUrl);
          }
        }
      } else {
        // Create post with images
        postId = await _postRepository.createPostWithImages(
          post,
          selectedImages.toList(),
        );
      }

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

  /// Reinitialize camera for video mode (with audio)
  Future<void> _reinitializeCameraForVideo() async {
    try {
      debugPrint('Reinitializing camera for video mode with audio');

      // Temporarily disable camera
      isCameraInitialized.value = false;

      // Get current camera direction
      final currentIsRear = isRearCamera.value;

      // Dispose current controller
      await cameraController?.dispose();

      // Find the appropriate camera
      final camera =
          currentIsRear
              ? cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
                orElse: () => cameras.first,
              )
              : cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
                orElse: () => cameras.last,
              );

      // Create new controller with audio enabled
      cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true, // Enable audio for video
      );

      await cameraController!.initialize();

      // Apply flash mode
      await _updateFlashMode();

      isCameraInitialized.value = true;
      debugPrint('Camera reinitialized for video mode successfully');
    } catch (e) {
      debugPrint('Error reinitializing camera for video: $e');
      isCameraInitialized.value = false;
    }
  }

  /// Reinitialize camera for photo mode (without audio)
  Future<void> _reinitializeCameraForPhoto() async {
    try {
      debugPrint('Reinitializing camera for photo mode without audio');

      // Temporarily disable camera
      isCameraInitialized.value = false;

      // Get current camera direction
      final currentIsRear = isRearCamera.value;

      // Dispose current controller
      await cameraController?.dispose();

      // Find the appropriate camera
      final camera =
          currentIsRear
              ? cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
                orElse: () => cameras.first,
              )
              : cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front,
                orElse: () => cameras.last,
              );

      // Create new controller without audio
      cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false, // Disable audio for photo/story
      );

      await cameraController!.initialize();

      // Apply flash mode
      await _updateFlashMode();

      isCameraInitialized.value = true;
      debugPrint('Camera reinitialized for photo mode successfully');
    } catch (e) {
      debugPrint('Error reinitializing camera for photo: $e');
      isCameraInitialized.value = false;
    }
  }

  /// Get story repository instance
  StoryRepository get _getStoryRepository {
    _storyRepository ??= Get.find<StoryRepository>();
    return _storyRepository!;
  }

  /// Create story with captured image
  Future<void> _createStoryWithImage(File imageFile) async {
    try {
      isLoading.value = true;

      final currentUser = _supabase.client.auth.currentUser;
      if (currentUser == null) {
        Get.snackbar('Error', 'User not authenticated');
        return;
      }

      // Create story model
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final story = StoryModel(
        id: '',
        userId: currentUser.id,
        imageUrl: null,
        textItems: [],
        doodlePoints: [],
        createdAt: now,
        expiresAt: expiresAt,
      );

      // Create story in database first
      final storyId = await _getStoryRepository.createStory(story);

      if (storyId != null) {
        // Show success message
        Get.snackbar('Success', 'Story posted successfully!');

        // Clear form and navigate back to home
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

        // Refresh stories in background
        if (Get.isRegistered<StoriesHomeController>()) {
          Get.find<StoriesHomeController>().refreshStories();
        }

        // Upload image in background
        _uploadStoryImageInBackground(imageFile, currentUser.id, storyId);
      } else {
        Get.snackbar(
          'Error',
          'Failed to create story',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error creating story: $e');
      Get.snackbar(
        'Error',
        'Failed to create story: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Upload story image in background
  Future<void> _uploadStoryImageInBackground(
    File imageFile,
    String userId,
    String storyId,
  ) async {
    try {
      final imageUrl = await _getStoryRepository.uploadStoryImage(
        imageFile,
        userId,
      );
      if (imageUrl != null) {
        // Update story with image URL
        await _supabase.client
            .from('stories')
            .update({'image_url': imageUrl})
            .eq('id', storyId);

        debugPrint('Story image uploaded and updated successfully');
      }
    } catch (e) {
      debugPrint('Error uploading story image in background: $e');
    }
  }
}

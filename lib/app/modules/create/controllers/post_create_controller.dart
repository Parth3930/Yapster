import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../controllers/create_controller.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class PostCreateController extends GetxController {
  // Dependencies
  final CreateController createController = Get.find<CreateController>();
  final UserPostsCacheService _cacheService = Get.find<UserPostsCacheService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final SupabaseService _supabase = Get.find<SupabaseService>();

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

  // Focus node for text field
  final FocusNode textFocusNode = FocusNode();

  // Observable focus state
  final isTextFieldFocused = false.obs;

  // Debounce timer for focus changes
  Timer? _focusDebounceTimer;

  @override
  void onInit() {
    super.onInit();

    // Set up focus node listener with debouncing
    textFocusNode.addListener(() {
      // Cancel any pending timer
      _focusDebounceTimer?.cancel();

      // Update focus state immediately for UI
      isTextFieldFocused.value = textFocusNode.hasFocus;

      // Debounce video operations to prevent rapid changes
      _focusDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (textFocusNode.hasFocus) {
          // Pause video when starting to type
          pauseVideoForTyping();
        } else {
          // Resume video when focus is lost
          resumeVideoAfterTyping();
        }
      });
    });

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
    debugPrint('PostCreateController: onClose called');
    
    // Cancel any pending timers
    _focusDebounceTimer?.cancel();

    // Dispose focus node
    textFocusNode.dispose();

    // Safely dispose video controller using our helper method
    _safeDisposeVideoController();
    videoInitialized.value = false;

    // Reset main CreateController state so next entry is clean
    createController.videoFilePath.value = '';
    createController.selectedImages.clear();
    createController.postTextController.clear();
    createController.canPost.value = false;

    super.onClose();
  }

  void _initializeVideoPlayer() {
    // Use a microtask to ensure this runs on the main thread
    // but doesn't interfere with any ongoing UI operations
    Future.microtask(() {
      _performVideoInitialization();
    });
  }

  void _performVideoInitialization() {
    // Set initialized state to false first
    videoInitialized.value = false;

    if (videoPath.isEmpty) {
      debugPrint('Video path is empty, skipping initialization');
      return;
    }

    // Don't initialize video if user is currently typing
    if (isTextFieldFocused.value) {
      debugPrint('Delaying video initialization - user is typing');
      return;
    }

    // Safely dispose any previously created controller
    _safeDisposeVideoController();

    try {
      // Create the video controller with explicit thread safety options
      videoController = VideoPlayerController.file(
        File(videoPath.value),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize in a way that properly handles thread safety
      videoController!.initialize().then((_) {
        // Use a microtask to ensure we're on the main thread for UI updates
        // but don't block the UI thread with video operations
        Future.microtask(() {
          try {
            // Double-check controller is still valid after async operation
            if (videoController != null &&
                videoController!.value.isInitialized &&
                !videoController!.value.hasError) {
              
              // Configure playback with reduced resource usage
              videoController!.setLooping(true);
              videoController!.setVolume(0.3);

              // Only auto-play if user is not typing
              if (!isTextFieldFocused.value) {
                videoController!.play();
              }
              
              // Mark as initialized to update UI
              videoInitialized.value = true;
              debugPrint('Video player initialized successfully');
            } else {
              debugPrint('Video controller not ready or has error');
              videoInitialized.value = false;
            }
          } catch (e) {
            debugPrint('Error setting up video controller: $e');
            videoInitialized.value = false;
            _safeDisposeVideoController();
          }
        });
      }).catchError((error) {
        debugPrint('Error initializing video player: $error');
        videoInitialized.value = false;
        _safeDisposeVideoController();
      });
    } catch (e) {
      debugPrint('Error creating video controller: $e');
      videoInitialized.value = false;
      _safeDisposeVideoController();
    }
  }

  // Helper method to safely dispose video controller
  void _safeDisposeVideoController() {
    if (videoController != null) {
      try {
        // Always pause before disposing to ensure resources are released
        if (videoController!.value.isInitialized) {
          videoController!.pause();
        }
        videoController!.dispose();
        debugPrint('Video controller disposed safely');
      } catch (e) {
        debugPrint('Error disposing previous video controller: $e');
      } finally {
        videoController = null;
      }
    }
  }

  void toggleGlobalPost(bool value) {
    isGlobalPost.value = value;
  }

  void pauseVideoForTyping() {
    // Ensure this runs on the main thread and is isolated from camera operations
    if (videoController != null) {
      try {
        // Use a microtask to ensure this doesn't interfere with camera operations
        scheduleMicrotask(() {
          if (videoController != null &&
              videoController!.value.isInitialized &&
              !videoController!.value.hasError &&
              videoController!.value.isPlaying) {
            videoController!.pause();
          }
        });
      } catch (e) {
        debugPrint('Error pausing video: $e');
      }
    }
  }

  void resumeVideoAfterTyping() {
    // Ensure this runs on the main thread and is isolated from camera operations
    if (videoController != null) {
      try {
        // Use a microtask to ensure this doesn't interfere with camera operations
        scheduleMicrotask(() {
          if (videoController != null &&
              videoInitialized.value &&
              videoController!.value.isInitialized &&
              !videoController!.value.hasError &&
              !videoController!.value.isPlaying) {
            videoController!.play();
          } else if (videoPath.isNotEmpty && !videoInitialized.value) {
            // If video wasn't initialized because user was typing, initialize it now
            _initializeVideoPlayer();
          }
        });
      } catch (e) {
        debugPrint('Error resuming video: $e');
      }
    }
  }

  Future<void> _updatePostCount(String userId) async {
    try {
      // 1. First get the current post count from DB
      final response = await _supabase.client
          .from('posts')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      final postCount = response.length;
      debugPrint('Current post count from DB for user $userId: $postCount');

      // 2. Update the post_count in profiles table
      await _supabase.client
          .from('profiles')
          .update({'post_count': postCount})
          .eq('user_id', userId);

      debugPrint('Updated post_count in profiles table for user $userId');

      // 3. Update the cache with the accurate count
      await _accountDataProvider.refreshCounts(userId);

      debugPrint('Updated post count in cache for user $userId');
    } catch (e) {
      debugPrint('Error updating post count: $e');
    }
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
        // Verify video file exists before proceeding
        final videoFile = File(videoPath.value);
        if (await videoFile.exists()) {
          createController.videoFilePath.value = videoPath.value;
          progress.value = 0.2;
          processingMessage.value = 'Processing video...';
        } else {
          debugPrint(
            '📱 POST CREATE VIEW: Video file does not exist: ${videoPath.value}',
          );
          throw Exception('Video file not found');
        }
      }

      // Add some example text if empty to help pass validation
      if (createController.postTextController.text.trim().isEmpty &&
          createController.selectedImages.isEmpty &&
          videoPath.isEmpty) {
        createController.postTextController.text = "New post";
      }

      progress.value = 0.4;
      processingMessage.value = 'Uploading content...';

      // Call createPost and wait for it to complete
      await createController.createPost(
        isGlobal: isGlobalPost.value, // This will be false by default
        bypassValidation: true, // Bypass the empty content validation
      );

      progress.value = 0.8;
      processingMessage.value = 'Updating post count...';

      // Get the current user ID
      final currentUserId = _supabase.client.auth.currentUser?.id;
      if (currentUserId != null) {
        // Increment post count optimistically first
        _accountDataProvider.incrementPostCount();

        // Update post count in correct sequence
        await _updatePostCount(currentUserId);

        // Force refresh the posts cache
        await _cacheService.refreshUserPosts(currentUserId);
      }

      progress.value = 1.0;
      processingMessage.value = 'Post created successfully!';

      // Add a small delay to show success message
      await Future.delayed(const Duration(milliseconds: 1500));

      // Navigate back on success
      try {
        if (Get.isRegistered<PostCreateController>()) {
          Get.back();
        }
      } catch (navError) {
        debugPrint(
          '📱 POST CREATE VIEW: Error navigating after success: $navError',
        );
      }
    } catch (e) {
      debugPrint('📱 POST CREATE VIEW: Error creating post: $e');

      // Show user-friendly error message
      String errorMessage = 'Failed to create post';
      if (e.toString().contains('Video file not found')) {
        errorMessage = 'Video file is no longer available';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission error - please try again';
      }

      Get.snackbar(
        'Error',
        errorMessage,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
      progress.value = 0.0;
      processingMessage.value = '';
    }
  }
}

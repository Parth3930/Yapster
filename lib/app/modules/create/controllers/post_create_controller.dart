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
  final progress = 0.0.obs;
  final processingMessage = ''.obs;
  final videoInitialized = false.obs;
  final isTextFieldFocused = false.obs;

  // Video player controller
  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  // Focus node for text field
  final FocusNode textFocusNode = FocusNode();

  // Timers and state management
  Timer? _focusDebounceTimer;
  Timer? _initializationTimer;
  bool _isDisposed = false;
  bool _isInitializing = false;

  @override
  void onInit() {
    super.onInit();
    _setupFocusListener();
    _processArguments();
  }

  @override
  void onClose() {
    debugPrint('PostCreateController: onClose called');
    _isDisposed = true;

    // Cancel all timers
    _focusDebounceTimer?.cancel();
    _initializationTimer?.cancel();

    // Dispose focus node
    textFocusNode.dispose();

    // Dispose video controller safely
    _disposeVideoController();

    // Reset create controller state
    _resetCreateControllerState();

    super.onClose();
  }

  void _setupFocusListener() {
    textFocusNode.addListener(() {
      if (_isDisposed) return;

      _focusDebounceTimer?.cancel();
      isTextFieldFocused.value = textFocusNode.hasFocus;

      _focusDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (_isDisposed) return;

        if (textFocusNode.hasFocus) {
          _pauseVideoForTyping();
        } else {
          _resumeVideoAfterTyping();
        }
      });
    });
  }

  void _processArguments() {
    final args = Get.arguments;
    if (args == null) return;

    if (args['selectedImages'] != null) {
      selectedImages.assignAll(args['selectedImages'] as List<File>);
    }

    if (args['videoPath'] != null) {
      videoPath.value = args['videoPath'] as String;
      _scheduleVideoInitialization();
    }
  }

  void _scheduleVideoInitialization() {
    if (_isDisposed || _isInitializing) return;

    _initializationTimer?.cancel();
    _initializationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed && !isTextFieldFocused.value) {
        _initializeVideoPlayer();
      }
    });
  }

  Future<void> _initializeVideoPlayer() async {
    if (_isDisposed || _isInitializing || videoPath.isEmpty) return;

    _isInitializing = true;
    videoInitialized.value = false;

    try {
      // Dispose previous controller
      await _disposeVideoController();

      // Verify video file exists
      final videoFile = File(videoPath.value);
      if (!await videoFile.exists()) {
        debugPrint('Video file does not exist: ${videoPath.value}');
        return;
      }

      // Create new controller
      _videoController = VideoPlayerController.file(
        videoFile,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize with timeout
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Video initialization timeout');
        },
      );

      // Check if still valid after initialization
      if (_isDisposed || _videoController == null) return;

      if (_videoController!.value.isInitialized &&
          !_videoController!.value.hasError) {
        // Configure playback
        await _videoController!.setLooping(true);
        await _videoController!.setVolume(0.5);

        // Auto-play if not typing
        if (!isTextFieldFocused.value && !_isDisposed) {
          await _videoController!.play();
        }

        videoInitialized.value = true;
        debugPrint('Video player initialized successfully');
      } else {
        throw Exception('Video controller not properly initialized');
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      await _disposeVideoController();

      // Show user-friendly error
      if (!_isDisposed) {
        Get.snackbar(
          'Video Error',
          'Failed to load video. Please try again.',
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _disposeVideoController() async {
    if (_videoController == null) return;

    try {
      if (_videoController!.value.isInitialized) {
        await _videoController!.pause();
      }
      await _videoController!.dispose();
      debugPrint('Video controller disposed safely');
    } catch (e) {
      debugPrint('Error disposing video controller: $e');
    } finally {
      _videoController = null;
      videoInitialized.value = false;
    }
  }

  void _pauseVideoForTyping() {
    if (_videoController?.value.isInitialized == true &&
        _videoController!.value.isPlaying) {
      _videoController!.pause().catchError((e) {
        debugPrint('Error pausing video: $e');
      });
    }
  }

  void _resumeVideoAfterTyping() {
    if (_videoController?.value.isInitialized == true &&
        !_videoController!.value.isPlaying) {
      _videoController!.play().catchError((e) {
        debugPrint('Error resuming video: $e');
      });
    } else if (videoPath.isNotEmpty && !videoInitialized.value) {
      _scheduleVideoInitialization();
    }
  }

  void _resetCreateControllerState() {
    try {
      createController.videoFilePath.value = '';
      createController.selectedImages.clear();
      createController.postTextController.clear();
      createController.canPost.value = false;
    } catch (e) {
      debugPrint('Error resetting create controller state: $e');
    }
  }

  void toggleGlobalPost(bool value) {
    isGlobalPost.value = value;
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
    if (_isDisposed) return;

    isLoading.value = true;
    progress.value = 0.0;
    processingMessage.value = 'Preparing post...';

    try {
      // Pause video during upload
      await _pauseVideoForUpload();

      // Force the CreateController to allow posting
      createController.canPost.value = true;

      // Transfer video path to main controller if needed
      if (videoPath.isNotEmpty &&
          createController.videoFilePath.value.isEmpty) {
        final videoFile = File(videoPath.value);
        if (await videoFile.exists()) {
          createController.videoFilePath.value = videoPath.value;
          progress.value = 0.2;
          processingMessage.value = 'Processing video...';
        } else {
          throw Exception('Video file not found');
        }
      }

      // Add default text if empty
      if (createController.postTextController.text.trim().isEmpty &&
          createController.selectedImages.isEmpty &&
          videoPath.isEmpty) {
        createController.postTextController.text = "New post";
      }

      progress.value = 0.4;
      processingMessage.value = 'Uploading content...';

      // Create the post
      await createController.createPost(
        isGlobal: isGlobalPost.value,
        bypassValidation: true,
      );

      progress.value = 0.8;
      processingMessage.value = 'Updating post count...';

      // Update post count
      final currentUserId = _supabase.client.auth.currentUser?.id;
      if (currentUserId != null) {
        _accountDataProvider.incrementPostCount();
        await _updatePostCount(currentUserId);
        await _cacheService.refreshUserPosts(currentUserId);
      }

      progress.value = 1.0;
      processingMessage.value = 'Post created successfully!';

      // Show success message briefly
      await Future.delayed(const Duration(milliseconds: 1500));

      // Navigate back
      if (!_isDisposed && Get.isRegistered<PostCreateController>()) {
        Get.back();
      }
    } catch (e) {
      debugPrint('Error creating post: $e');

      if (!_isDisposed) {
        String errorMessage = 'Failed to create post';
        if (e.toString().contains('Video file not found')) {
          errorMessage = 'Video file is no longer available';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission error - please try again';
        }

        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (!_isDisposed) {
        isLoading.value = false;
        progress.value = 0.0;
        processingMessage.value = '';
      }
    }
  }

  Future<void> _pauseVideoForUpload() async {
    if (_videoController?.value.isInitialized == true) {
      try {
        await _videoController!.pause();
      } catch (e) {
        debugPrint('Error pausing video for upload: $e');
      }
    }
  }
}

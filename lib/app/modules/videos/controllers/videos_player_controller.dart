import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class VideosPlayerController extends GetxController {
  final _supabaseService = Get.find<SupabaseService>();
  final _accountProvider = Get.find<AccountDataProvider>();

  final RxList<PostModel> _videos = <PostModel>[].obs;
  final RxInt _currentIndex = 0.obs;
  final Rx<VideoPlayerController?> _videoController =
      Rx<VideoPlayerController?>(null);
  final RxBool _isInitialized = false.obs;
  final RxBool _isPlaying = false.obs;
  final RxBool _isMuted = false.obs;
  final RxBool _isLoading = true.obs;
  final RxBool _isDisposed = false.obs;

  List<PostModel> get videos => _videos;
  int get currentIndex => _currentIndex.value;
  VideoPlayerController? get videoController => _videoController.value;
  bool get isInitialized => _isInitialized.value;
  bool get isPlaying => _isPlaying.value;
  bool get isMuted => _isMuted.value;
  bool get isLoading => _isLoading.value;
  bool get isDisposed => _isDisposed.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args['videos'] != null) {
      _videos.value = List<PostModel>.from(args['videos']);
      _currentIndex.value = args['initialIndex'] ?? 0;
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    if (_videos.isEmpty || _currentIndex.value >= _videos.length) return;

    _isLoading.value = true;
    _isInitialized.value = false;

    // Dispose previous controller if exists
    await _disposeVideoController();

    if (_isDisposed.value) return;

    try {
      final videoUrl = _videos[_currentIndex.value].videoUrl;
      if (videoUrl == null) {
        _isLoading.value = false;
        return;
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: const {'Range': 'bytes=0-'},
      );

      _videoController.value = controller;

      // Set up listener for initialization
      controller.addListener(() {
        if (controller.value.isInitialized && !_isInitialized.value) {
          _isInitialized.value = true;
          _isLoading.value = false;
          controller.setLooping(true);
          controller.play();
          _isPlaying.value = true;
        }
      });

      // Initialize the controller
      await controller.initialize();

      if (!_isDisposed.value) {
        controller.setVolume(_isMuted.value ? 0.0 : 1.0);
      }
    } catch (e) {
      print('Error initializing video: $e');
      _isLoading.value = false;
    }
  }

  Future<void> _disposeVideoController() async {
    if (_videoController.value != null) {
      try {
        await _videoController.value!.pause();
        await _videoController.value!.dispose();
      } catch (e) {
        print('Error disposing video controller: $e');
      }
      _videoController.value = null;
    }
  }

  void onPageChanged(int index) {
    if (index == _currentIndex.value) return;
    _currentIndex.value = index;
    _initializeVideo();
  }

  void togglePlayPause() {
    if (!_isInitialized.value) return;
    if (_isPlaying.value) {
      _videoController.value?.pause();
    } else {
      _videoController.value?.play();
    }
    _isPlaying.value = !_isPlaying.value;
  }

  void toggleMute() {
    if (!_isInitialized.value) return;
    _isMuted.value = !_isMuted.value;
    _videoController.value?.setVolume(_isMuted.value ? 0.0 : 1.0);
  }

  bool isFollowing(String userId) => _accountProvider.isFollowing(userId);
  String? get currentUserId => _supabaseService.currentUser.value?.id;

  void followUser(String userId) {
    _accountProvider.followUser(userId);
  }

  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  void onClose() {
    _isDisposed.value = true;
    _disposeVideoController();
    super.onClose();
  }
}

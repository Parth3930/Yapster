import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/videos_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_share_dialog.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/comment_dialog.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';

class VideosView extends GetView<VideosController> {
  const VideosView({super.key});

  @override
  Widget build(BuildContext context) {
    return _VideosViewState();
  }
}

class _VideosViewState extends StatefulWidget {
  @override
  State<_VideosViewState> createState() => __VideosViewStateState();
}

class __VideosViewStateState extends State<_VideosViewState>
    with WidgetsBindingObserver {
  final VideosController controller = Get.find<VideosController>();
  final PostsFeedController feedController = Get.find<PostsFeedController>();
  final AccountDataProvider _accountProvider = Get.find<AccountDataProvider>();
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  PageController? _pageController;
  List<PostModel> _videos = [];
  int _currentIndex = 0;

  // Video controllers cache for preloading
  final Map<String, CachedVideoPlayerPlusController> _videoControllers = {};
  final Map<String, bool> _videoInitialized = {};
  String? _currentVideoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideos();
  }

  void _initializeVideos() {
    // Get videos from arguments or from feed controller
    final args = Get.arguments;
    if (args != null && args['videos'] != null) {
      _videos = List<PostModel>.from(args['videos']);
      _currentIndex = args['initialIndex'] ?? 0;
    } else {
      // Get videos from feed controller
      _videos =
          feedController.posts
              .where(
                (p) =>
                    p.postType.toLowerCase() == 'video' ||
                    (p.videoUrl != null && p.videoUrl!.isNotEmpty),
              )
              .toList();
      _currentIndex = 0;
    }

    if (_videos.isNotEmpty) {
      _pageController = PageController(initialPage: _currentIndex);
      controller.currentVideo.value = _videos[_currentIndex];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeVideoController(_currentIndex);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAllVideoControllers();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_currentVideoId != null) {
      final controller = _videoControllers[_currentVideoId!];
      if (controller != null && _videoInitialized[_currentVideoId!] == true) {
        switch (state) {
          case AppLifecycleState.paused:
          case AppLifecycleState.inactive:
            controller.pause();
            break;
          case AppLifecycleState.resumed:
            controller.play();
            break;
          default:
            break;
        }
      }
    }
  }

  void _disposeAllVideoControllers() {
    for (final controller in _videoControllers.values) {
      try {
        controller.pause();
        controller.dispose();
      } catch (e) {
        // Silent cleanup
      }
    }
    _videoControllers.clear();
    _videoInitialized.clear();
    _currentVideoId = null;
  }

  Future<void> _initializeVideoController(int index) async {
    if (index >= _videos.length) return;

    final post = _videos[index];
    final videoId = post.id;
    _currentVideoId = videoId;

    // Preload current, next, and previous videos
    await _preloadVideos(index);

    // Play current video
    _playVideo(videoId);
  }

  Future<void> _preloadVideos(int currentIndex) async {
    // Only preload current video and next video (not previous to save memory)
    final indicesToPreload = <int>[];

    // Current video (priority)
    indicesToPreload.add(currentIndex);

    // Next video only (for smooth forward scrolling)
    if (currentIndex < _videos.length - 1) {
      indicesToPreload.add(currentIndex + 1);
    }

    // Preload videos sequentially (current first, then next)
    for (final index in indicesToPreload) {
      await _preloadVideo(index);
    }
  }

  Future<void> _preloadVideo(int index) async {
    if (index >= _videos.length || index < 0) return;

    final post = _videos[index];
    final videoId = post.id;
    final videoUrl = post.videoUrl;

    // Skip if already initialized or no URL
    if (_videoInitialized[videoId] == true ||
        videoUrl == null ||
        videoUrl.isEmpty) {
      return;
    }

    // Skip if controller already exists
    if (_videoControllers.containsKey(videoId)) {
      return;
    }

    try {
      final controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      _videoControllers[videoId] = controller;

      await controller.initialize();

      if (mounted && controller.value.isInitialized) {
        controller.setLooping(true);
        controller.setVolume(1.0);
        _videoInitialized[videoId] = true;

        // If this is the current video, start playing immediately and trigger rebuild
        if (videoId == _currentVideoId && mounted) {
          controller.play();
          setState(() {});
        }
      }
    } catch (e) {
      _videoControllers.remove(videoId);
      _videoInitialized[videoId] = false;
    }
  }

  void _playVideo(String videoId) {
    // Pause all other videos
    for (final entry in _videoControllers.entries) {
      if (entry.key != videoId) {
        try {
          entry.value.pause();
        } catch (e) {
          // Silent pause
        }
      }
    }

    // Play current video
    final controller = _videoControllers[videoId];
    if (controller != null && _videoInitialized[videoId] == true) {
      try {
        controller.play();
      } catch (e) {
        // Silent play error
      }
    }
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
      controller.currentVideo.value = _videos[index];
    });

    final videoId = _videos[index].id;
    _currentVideoId = videoId;

    // Play current video immediately if already preloaded
    _playVideo(videoId);

    // Preload adjacent videos in background
    _preloadVideos(index);

    // Clean up distant videos to prevent memory leaks
    _cleanupDistantVideos(index);
  }

  void _cleanupDistantVideos(int currentIndex) {
    final videosToKeep = <String>{};

    // Only keep current video and next video (more aggressive cleanup)
    videosToKeep.add(_videos[currentIndex].id);
    if (currentIndex + 1 < _videos.length) {
      videosToKeep.add(_videos[currentIndex + 1].id);
    }

    // Dispose controllers that are not needed
    final controllersToRemove = <String>[];
    for (final videoId in _videoControllers.keys) {
      if (!videosToKeep.contains(videoId)) {
        controllersToRemove.add(videoId);
      }
    }

    for (final videoId in controllersToRemove) {
      try {
        _videoControllers[videoId]?.dispose();
        _videoControllers.remove(videoId);
        _videoInitialized.remove(videoId);
      } catch (e) {
        // Silent cleanup
      }
    }
  }

  void _navigateToUserProfile(String userId) {
    Get.toNamed('/profile', arguments: {'userId': userId});
  }

  Widget _buildVideoWidget(PostModel post) {
    final videoId = post.id;
    final controller = _videoControllers[videoId];

    try {
      if (controller != null &&
          _videoInitialized[videoId] == true &&
          controller.value.isInitialized &&
          !controller.value.hasError) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: CachedVideoPlayerPlus(controller),
            ),
          ),
        );
      }
    } catch (e) {
      // Silent error handling
    }

    // Show black screen instead of shimmer for smoother transitions
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
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

  // Helper method to safely access metadata values
  dynamic _getMetadataValue(Map<String, dynamic> metadata, String key) {
    try {
      return metadata[key];
    } catch (e) {
      debugPrint('Error accessing metadata key "$key": $e');
      return null;
    }
  }

  // Build action button widget
  Widget _buildActionButton({
    required String assetPath,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(assetPath, width: 32, height: 32),
          SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Handle like button tap
  void _handleLikeTap(PostModel post) {
    feedController.togglePostLike(post.id);
  }

  // Handle comment button tap
  void _handleCommentTap(PostModel post) {
    feedController.trackPostComment(post.id);

    CommentDialog.show(
      postId: post.id,
      post: post,
      onCommentSubmit: (postId, commentText) async {
        // Comment count is already incremented in CommentController.addComment()
        debugPrint('Comment submitted for post $postId: $commentText');
      },
    );
  }

  // Handle share button tap
  Future<void> _handleShareTap(PostModel post) async {
    feedController.trackPostShare(post.id);

    // Try to get chat controller or create it if not found
    ChatController chatController;
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      debugPrint('ChatController not found, registering it now');
      chatController = ChatController();
      Get.put(chatController);
    }

    // Ensure recent chats are loaded
    try {
      if (chatController.recentChats.isEmpty) {
        await chatController.preloadRecentChats();
      }
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
      return;
    }

    // Show enhanced share dialog
    Get.bottomSheet(
      EnhancedShareDialog(
        post: post,
        onShareComplete: () {
          debugPrint('Post shared successfully');
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // Handle favorite button tap
  Future<void> _handleFavoriteTap(PostModel post) async {
    await feedController.togglePostFavorite(post.id);
  }

  Widget _buildVideoPage(PostModel post) {
    final currentUserId = _supabaseService.currentUser.value?.id;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video content (full screen)
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: _buildVideoWidget(post),
        ),

        // Top overlay for header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 4,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
                Expanded(
                  child: Text(
                    'Yap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _handleFavoriteTap(post),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Image.asset(
                      _getMetadataValue(post.metadata, 'isFavorited') == true
                          ? 'assets/postIcons/star_selected.png'
                          : 'assets/postIcons/star.png',
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom overlay for controls and caption (moved up 100px for bottom nav)
        Positioned(
          bottom: 100, // Moved up to avoid bottom navigation
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left side: Avatar, username, and content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar and username row
                      Row(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: () => _navigateToUserProfile(post.userId),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    post.avatar == null ||
                                            post.avatar == 'skiped'
                                        ? post.googleAvatar ??
                                            'https://via.placeholder.com/40'
                                        : post.avatar!,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Username and time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Username and follow button row
                                Row(
                                  children: [
                                    // Username/nickname
                                    Expanded(
                                      child: Text(
                                        post.nickname?.isNotEmpty == true
                                            ? post.nickname!
                                            : post.username ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Follow button if not following and not own post
                                    Builder(
                                      builder: (context) {
                                        final isCurrentUser =
                                            currentUserId == post.userId;
                                        if (!isCurrentUser &&
                                            !_accountProvider.isFollowing(
                                              post.userId,
                                            )) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap:
                                                    () => _accountProvider
                                                        .followUser(
                                                          post.userId,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  child: Text(
                                                    'Follow',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                // Time ago
                                Text(
                                  _getTimeAgo(post.createdAt),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Content
                      if (post.content.isNotEmpty)
                        Text(
                          post.content,
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                // Right side: Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like button
                    _buildActionButton(
                      assetPath:
                          _getMetadataValue(post.metadata, 'isLiked') == true
                              ? 'assets/postIcons/like_active.png'
                              : 'assets/postIcons/like.png',
                      count: post.likesCount,
                      onTap: () => _handleLikeTap(post),
                    ),
                    SizedBox(height: 20),
                    // Comment button
                    _buildActionButton(
                      assetPath: 'assets/postIcons/comment.png',
                      count: post.commentsCount,
                      onTap: () => _handleCommentTap(post),
                    ),
                    SizedBox(height: 20),
                    // Share button
                    _buildActionButton(
                      assetPath: 'assets/postIcons/send.png',
                      count: post.sharesCount,
                      onTap: () => _handleShareTap(post),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No videos yet',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
        extendBody: true,
        floatingActionButton: const BottomNavigation(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: _videos.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return Obx(() {
            // Find the current post in the feed controller to get the latest state
            final currentPost = feedController.posts.firstWhere(
              (p) => p.id == _videos[index].id,
              orElse: () => _videos[index],
            );
            return _buildVideoPage(currentPost);
          });
        },
      ),
      extendBody: true,
      floatingActionButton: const BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

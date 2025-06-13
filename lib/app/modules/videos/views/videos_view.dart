import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
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

class __VideosViewStateState extends State<_VideosViewState> {
  final VideosController controller = Get.find<VideosController>();
  final PostsFeedController feedController = Get.find<PostsFeedController>();
  final AccountDataProvider _accountProvider = Get.find<AccountDataProvider>();
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  PageController? _pageController;
  List<PostModel> _videos = [];
  int _currentIndex = 0;
  CachedVideoPlayerPlusController? _videoPlayerController;
  String? _currentVideoId;

  @override
  void initState() {
    super.initState();
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
                    p.videoUrl != null ||
                    p.metadata['video_url'] != null,
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
    _disposeVideoController();
    _pageController?.dispose();
    super.dispose();
  }

  void _disposeVideoController() {
    if (_videoPlayerController != null) {
      try {
        _videoPlayerController!.pause();
        _videoPlayerController!.dispose();
      } catch (e) {
        debugPrint('Error disposing video controller: $e');
      } finally {
        _videoPlayerController = null;
        _currentVideoId = null;
      }
    }
  }

  Future<void> _initializeVideoController(int index) async {
    if (index >= _videos.length) return;

    final post = _videos[index];
    final videoId = post.id;

    // Don't reinitialize if it's the same video
    if (_currentVideoId == videoId &&
        _videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      return;
    }

    // Dispose previous controller safely
    _disposeVideoController();

    _currentVideoId = videoId;
    String? videoUrl =
        post.videoUrl?.isNotEmpty == true
            ? post.videoUrl!
            : post.metadata['video_url'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      debugPrint('VideosView: no video URL for post ${post.id}');
      return;
    }

    try {
      debugPrint('VideosView: initializing video for $videoUrl');
      _videoPlayerController = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await _videoPlayerController!.initialize();

      // Check if controller is still valid after initialization
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized &&
          mounted) {
        _videoPlayerController!
          ..setLooping(true)
          ..setVolume(1.0)
          ..play();

        if (mounted) {
          setState(() {});
        }
        debugPrint('VideosView: video initialized successfully');
      }
    } catch (e) {
      debugPrint('VideosView init failed: $e');
      // Clean up on error
      _disposeVideoController();
    }
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
      controller.currentVideo.value = _videos[index];
    });

    _initializeVideoController(index);
  }

  Widget _buildShimmerLoading(String? thumbnailUrl) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      period: const Duration(milliseconds: 800),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child:
            thumbnailUrl != null
                ? Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    );
                  },
                )
                : const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
      ),
    );
  }

  void _navigateToUserProfile(String userId) {
    Get.toNamed('/profile', arguments: {'userId': userId});
  }

  Widget _buildVideoWidget(PostModel post) {
    try {
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized &&
          !_videoPlayerController!.value.hasError) {
        return AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: CachedVideoPlayerPlus(_videoPlayerController!),
        );
      }
    } catch (e) {
      debugPrint('Error building video widget: $e');
    }

    // Fallback to shimmer loading
    return _buildShimmerLoading(post.metadata['video_thumbnail'] as String?);
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: _videos.length,
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

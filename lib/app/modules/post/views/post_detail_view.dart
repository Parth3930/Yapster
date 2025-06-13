import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:yapster/app/modules/post/controllers/post_detail_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_widget_factory.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_comment_widget.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_share_dialog.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/comment_dialog.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class PostDetailView extends GetView<PostDetailController> {
  const PostDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return _PostDetailViewState();
  }
}

class _PostDetailViewState extends StatefulWidget {
  @override
  State<_PostDetailViewState> createState() => __PostDetailViewStateState();
}

class __PostDetailViewStateState extends State<_PostDetailViewState> {
  final PostDetailController controller = Get.find<PostDetailController>();
  VideoPlayerController? _videoPlayerController;
  String? _currentPostId;
  final AccountDataProvider _accountProvider = Get.find<AccountDataProvider>();

  @override
  void initState() {
    super.initState();
    _currentPostId = controller.post.value?.id;
    ever<PostModel?>(controller.post, (newPost) {
      if (newPost?.id != _currentPostId) {
        _currentPostId = newPost?.id;
        _resetVideoPlayer();
        controller.resetVideoState();
        _initializeVideoController();
      }
    });
    // Initialize video controller after first frame to avoid GetX listener error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoController();
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _resetVideoPlayer() {
    if (_videoPlayerController != null) {
      // Pause first to prevent audio overlap
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
      _videoPlayerController = null;

      // Update controller state
      controller.setVideoInitialized(false);
    }
  }

  Future<void> _initializeVideoController() async {
    final postModel = controller.post.value;
    if (postModel == null) return;
    String? videoUrl =
        postModel.videoUrl?.isNotEmpty == true
            ? postModel.videoUrl!
            : postModel.metadata['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      debugPrint('PostDetailView: no video URL');
      return;
    }
    try {
      debugPrint('PostDetailView: initializing video for $videoUrl');
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await _videoPlayerController!.initialize();
      _videoPlayerController!
        ..setLooping(true)
        ..setVolume(1.0)
        ..play();
      controller.setVideoInitialized(true);
      debugPrint('PostDetailView: video initialized');
      _videoPlayerController!.addListener(() {
        final ctl = _videoPlayerController!;
        if (ctl.value.isInitialized &&
            ctl.value.position >=
                ctl.value.duration - const Duration(milliseconds: 100)) {
          ctl.seekTo(Duration.zero);
        }
        if (ctl.value.hasError) {
          debugPrint(
            'PostDetailView video error: ${ctl.value.errorDescription}',
          );
        }
      });
    } catch (e) {
      debugPrint('PostDetailView init failed: $e');
      controller.setVideoInitialized(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          // Show fullscreen shimmer while the post data is loading
          return _buildShimmerLoading(null);
        }

        if (controller.post.value == null) {
          return Stack(
            children: [
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white54, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Post not found',
                      style: TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This post may have been deleted or is no longer available.',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Custom header
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
                        Colors.black.withOpacity(0.7),
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
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final post = controller.post.value!;

        // Only apply this custom layout for video posts
        if (post.postType == 'video' ||
            post.videoUrl != null ||
            (post.metadata['video_url'] != null)) {
          return Stack(
            children: [
              // Full screen video content
              Positioned.fill(child: _buildVideoPostDetail(post)),

              // Custom header with back button and star
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
                        Colors.black.withOpacity(0.7),
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
                        onTap: () {
                          // Implement star functionality
                          if (controller.post.value != null) {
                            controller.togglePostFavorite(
                              controller.post.value!.id,
                            );
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Image.asset(
                            post.metadata['isFavorited'] == true
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
            ],
          );
        } else {
          // For non-video posts, use the original layout with stack
          return Stack(
            children: [
              // Scrollable content
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 56,
                  bottom: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Main post
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: PostWidgetFactory.createPostWidget(
                          post: post,
                          controller: controller.feedController,
                        ),
                      ),

                      // Comments section
                      _buildCommentsSection(),
                    ],
                  ),
                ),
              ),

              // Custom header
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
                    color: Colors.black.withOpacity(0.8),
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
                        onTap: () {
                          // Implement star functionality
                          if (controller.post.value != null) {
                            controller.togglePostFavorite(
                              controller.post.value!.id,
                            );
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Image.asset(
                            post.metadata['isFavorited'] == true
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
            ],
          );
        }
      }),
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

  Widget _buildVideoPostDetail(post) {
    final supabaseService = Get.find<SupabaseService>();
    final currentUserId = supabaseService.currentUser.value?.id;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video content (full screen)
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Obx(() {
            final isInitialized = controller.isVideoInitialized.value;
            if (_videoPlayerController != null && isInitialized) {
              return AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController!),
              );
            } else {
              return _buildShimmerLoading(
                post.metadata['video_thumbnail'] as String?,
              );
            }
          }),
        ),

        // Bottom overlay for controls and caption
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
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
                          // Username and follow button
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.nickname?.isNotEmpty == true
                                      ? post.nickname!
                                      : post.username ?? '',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                SizedBox(height: 4),
                                // Follow button if not following and not own post
                                Builder(
                                  builder: (context) {
                                    final isCurrentUser =
                                        currentUserId == post.userId;
                                    if (!isCurrentUser &&
                                        !_accountProvider.isFollowing(
                                          post.userId,
                                        )) {
                                      return ElevatedButton(
                                        onPressed:
                                            () => _accountProvider.followUser(
                                              post.userId,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[300],
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Follow',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Content
                      Text(
                        post.content,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Right side: Interaction buttons in column
                Container(
                  margin: EdgeInsets.only(bottom: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: () {
                          controller.togglePostLike(post.id);
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              Image.asset(
                                post.metadata['isLiked'] == true
                                    ? 'assets/postIcons/like_active.png'
                                    : 'assets/postIcons/like.png',
                                width: 30,
                                height: 30,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${post.likesCount}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Comment button
                      GestureDetector(
                        onTap: () {
                          controller.feedController.trackPostComment(post.id);
                          CommentDialog.show(
                            postId: post.id,
                            post: post,
                            onCommentSubmit: (postId, text) async {
                              await controller.loadComments();
                              final current = controller.post.value!;
                              controller.post.value = current.copyWith(
                                commentsCount: current.commentsCount + 1,
                              );
                            },
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/postIcons/comment.png',
                                width: 30,
                                height: 30,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${post.commentsCount}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Share button
                      GestureDetector(
                        onTap: () {
                          controller.feedController.trackPostShare(post.id);
                          EnhancedShareDialog(post: post);
                        },
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/postIcons/send.png',
                              width: 30,
                              height: 30,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${post.sharesCount}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(String? thumbnailUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background thumbnail (if available) with darkened effect
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          Opacity(
            opacity: 0.2,
            child: Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Container(color: Colors.black),
            ),
          ),

        // Shimmer loading effect
        Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[800]!,
          period: const Duration(milliseconds: 800),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 20),
                Container(width: 200, height: 15, color: Colors.white),
                const SizedBox(height: 12),
                Container(width: 150, height: 15, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comments header
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Comments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Comments list
          Obx(() {
            if (controller.commentController.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              );
            }

            if (controller.commentController.comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: const Center(
                  child: Text(
                    'No comments yet. Be the first to comment!',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.commentController.comments.length,
              itemBuilder: (context, index) {
                final comment = controller.commentController.comments[index];
                return EnhancedCommentWidget(
                  comment: comment,
                  controller: controller.commentController,
                );
              },
            );
          }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _navigateToUserProfile(String userId) {
    // Navigate to user profile
    Get.toNamed('/profile/$userId');
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/modules/post/controllers/post_detail_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_widget_factory.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_comment_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_share_dialog.dart';

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
  bool _showFullCaption = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
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

  Widget _buildVideoPostDetail(post) {
    // Extract video URL
    String? videoUrl = post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      videoUrl = post.metadata['video_url'] as String?;
    }

    // Extract thumbnail
    final thumbnailUrl = post.metadata['video_thumbnail'] as String?;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video content (full screen)
        GestureDetector(
          onTap: () {
            // Implement video play functionality
            _playVideo(videoUrl ?? '');
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child:
                thumbnailUrl != null && thumbnailUrl.isNotEmpty
                    ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _buildVideoPlaceholder();
                      },
                    )
                    : _buildVideoPlaceholder(),
          ),
        ),

        // Play button overlay
        Center(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow, color: Colors.white, size: 48),
          ),
        ),

        // Bottom overlay for controls and caption
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
            decoration: BoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Caption (if any)
                if (post.content.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12, right: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _showFullCaption
                              ? post.content
                              : (post.content.length > 50
                                  ? '${post.content.substring(0, 50)}...'
                                  : post.content),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        if (post.content.length > 50 && !_showFullCaption)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showFullCaption = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(40, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'more',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Avatar and engagement buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar in bottom left
                    GestureDetector(
                      onTap: () {
                        // Navigate to profile
                        _navigateToUserProfile(post.userId);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                          image: DecorationImage(
                            image: NetworkImage(
                              post.avatar == null || post.avatar == 'skiped'
                                  ? post.googleAvatar ??
                                      'https://via.placeholder.com/40'
                                  : post.avatar!,
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    // Interaction buttons in bottom right as column
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Like button
                        GestureDetector(
                          onTap: () {
                            controller.togglePostLike(post.id);
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 16),
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
                            // Track comment interaction
                            controller.feedController.trackPostComment(post.id);
                            // Show comments in a bottom sheet
                            _showCommentsBottomSheet();
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 16),
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
                            // Use enhanced share dialog
                            _showEnhancedShareDialog(post);
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 16),
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
                        ),
                      ],
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

  Widget _buildVideoPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam, color: Colors.white.withOpacity(0.6), size: 64),
          SizedBox(height: 16),
          Text(
            'Video Preview',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
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

  void _playVideo(String videoUrl) {
    // Implement video player
    debugPrint('Play video: $videoUrl');

    // For now, show a dialog indicating video would play
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Video Player', style: TextStyle(color: Colors.white)),
        content: Text(
          'Video player would open here.\nURL: $videoUrl',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }

  void _navigateToUserProfile(String userId) {
    // Navigate to user profile
    Get.toNamed('/profile/$userId');
  }

  void _showCommentsBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            Divider(color: Colors.grey[800]),
            Expanded(
              child: Obx(() {
                if (controller.commentController.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }

                if (controller.commentController.comments.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: controller.commentController.comments.length,
                  itemBuilder: (context, index) {
                    final comment =
                        controller.commentController.comments[index];
                    return EnhancedCommentWidget(
                      comment: comment,
                      controller: controller.commentController,
                    );
                  },
                );
              }),
            ),

            // Comment input field
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  fillColor: Colors.grey[800],
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Icon(Icons.send, color: Colors.white),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
    );
  }

  void _showEnhancedShareDialog(PostModel post) {
    try {
      // Try to get chat controller or create it if not found
      var chatController;
      try {
        chatController = Get.find<ChatController>();
      } catch (e) {
        // If not found, register it
        debugPrint('ChatController not found, registering it now');
        chatController = ChatController();
        Get.put(chatController);
      }

      // Ensure recent chats are loaded
      try {
        if (chatController.recentChats.isEmpty) {
          chatController.preloadRecentChats();
        }
      } catch (e) {
        debugPrint('Error loading recent chats: $e');
      }

      // Show enhanced share dialog
      Get.bottomSheet(
        EnhancedShareDialog(
          post: post,
          onShareComplete: () {
            // Optional callback when share is complete
            debugPrint('Post shared successfully');
          },
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } catch (e) {
      debugPrint('Error showing share dialog: $e');
      // Fallback to simple share
      controller.feedController.trackPostShare(post.id);
    }
  }
}

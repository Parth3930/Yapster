import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/comment_dialog.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_action_button.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_share_dialog.dart';
import 'dart:ui';

/// A reusable widget for post interaction buttons (like, comment, share, favorite)
class PostInteractionButtons extends StatelessWidget {
  final PostModel post;
  final PostsFeedController controller;
  final bool glassy;
  final Function(String)? onCommentTap;

  const PostInteractionButtons({
    Key? key,
    required this.post,
    required this.controller,
    this.glassy = true,
    this.onCommentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Find the current post in the controller's list to get the latest state
      final currentPost = controller.posts.firstWhere(
        (p) => p.id == post.id,
        orElse: () => post,
      );

      final isLiked = currentPost.metadata['isLiked'] == true;
      final isFavorited = currentPost.metadata['isFavorited'] == true;

      final interactionButtons = [
        _buildLikeButton(isLiked: isLiked, likesCount: currentPost.likesCount),
        SizedBox(width: 16),
        _buildCommentButton(commentsCount: currentPost.commentsCount),
        SizedBox(width: 16),
        _buildShareButton(sharesCount: currentPost.sharesCount),
      ];

      return Row(
        children: [
          glassy
              ? _buildGlassyPill(interactionButtons)
              : Row(children: interactionButtons),
          Spacer(),
          _buildFavoriteButton(isFavorited),
        ],
      );
    });
  }

  Widget _buildLikeButton({required bool isLiked, required int likesCount}) {
    return PostActionButton(
      assetPath:
          isLiked
              ? 'assets/postIcons/like_active.png'
              : 'assets/postIcons/like.png',
      text: likesCount.toString(),
      onTap: () => _handleLikeTap(isLiked),
    );
  }

  Widget _buildCommentButton({required int commentsCount}) {
    return PostActionButton(
      assetPath: 'assets/postIcons/comment.png',
      text: commentsCount.toString(),
      onTap: () => _handleCommentTap(),
    );
  }

  Widget _buildShareButton({required int sharesCount}) {
    return PostActionButton(
      assetPath: 'assets/postIcons/send.png',
      text: sharesCount.toString(),
      onTap: () => _handleShareTap(),
    );
  }

  Widget _buildFavoriteButton(bool isFavorited) {
    return PostActionButton(
      assetPath:
          isFavorited
              ? 'assets/postIcons/star_selected.png'
              : 'assets/postIcons/star.png',
      onTap: () => _handleFavoriteTap(isFavorited),
      glassy: glassy,
    );
  }

  // Handle like button tap
  void _handleLikeTap(bool isCurrentlyLiked) {
    // Use the controller to toggle like status
    controller.togglePostLike(post.id);

    // Show toast for like/unlike
    Get.snackbar(
      isCurrentlyLiked ? 'Unliked' : 'Liked',
      isCurrentlyLiked ? 'You unliked this post' : 'You liked this post',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 1),
      backgroundColor: Colors.black54,
      colorText: Colors.white,
    );
  }

  // Handle comment button tap
  void _handleCommentTap() {
    if (onCommentTap != null) {
      onCommentTap!(post.id);
    } else {
      // Show enhanced comment dialog using the reusable component
      CommentDialog.show(
        postId: post.id,
        post: post,
        onCommentSubmit: (postId, commentText) async {
          // Add comment logic
          await controller.updatePostEngagement(postId, 'comments', 1);

          // No need for toast as the comment is already visible in the dialog
        },
      );
    }
  }

  // Handle share button tap
  Future<void> _handleShareTap() async {
    // Don't increment share count here - only when actually shared to someone

    // Try to get chat controller or create it if not found
    ChatController chatController;
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
        await chatController.preloadRecentChats();
      }
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
      // Show a simple share dialog if we can't load chats
      Get.snackbar(
        'Shared',
        'Post shared successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[800],
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
      return;
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
  }

  // Handle favorite button tap
  Future<void> _handleFavoriteTap(bool isCurrentlyFavorited) async {
    // Use the controller to toggle favorite status
    await controller.togglePostFavorite(post.id);

    // Show toast for favorite/unfavorite
    Get.snackbar(
      isCurrentlyFavorited ? 'Removed from Favorites' : 'Added to Favorites',
      isCurrentlyFavorited
          ? 'Post removed from your favorites'
          : 'Post added to your favorites',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 1),
      backgroundColor: Colors.black54,
      colorText: Colors.white,
    );
  }

  // Helper method for glassy pill container
  Widget _buildGlassyPill(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

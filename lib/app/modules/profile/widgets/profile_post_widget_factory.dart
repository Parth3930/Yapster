import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/profile/controllers/profile_posts_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/text_post_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/image_post_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/gif_post_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/video_post_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/sticker_post_widget.dart';

/// Factory class to create appropriate post widgets for profile pages
/// This factory uses ProfilePostsController instead of PostsFeedController
class ProfilePostWidgetFactory {
  /// Creates the appropriate post widget based on the post type for profile pages
  static Widget createPostWidget({
    required PostModel post,
    required ProfilePostsController controller,
  }) {
    // Create a wrapper that adapts ProfilePostsController to work with existing post widgets
    final adaptedController = _ProfilePostsControllerAdapter(controller);

    switch (post.postType.toLowerCase()) {
      case 'text':
        return TextPostWidget(post: post, controller: adaptedController);

      case 'image':
        return ImagePostWidget(post: post, controller: adaptedController);

      case 'gif':
        return GifPostWidget(post: post, controller: adaptedController);

      case 'video':
        return VideoPostWidget(post: post, controller: adaptedController);

      case 'sticker':
        return StickerPostWidget(post: post, controller: adaptedController);

      default:
        // Fallback to text post for unknown types
        return TextPostWidget(post: post, controller: adaptedController);
    }
  }

  /// Gets the appropriate icon for a post type
  static IconData getPostTypeIcon(String postType) {
    switch (postType.toLowerCase()) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'gif':
        return Icons.gif;
      case 'video':
        return Icons.play_circle_outline;
      case 'sticker':
        return Icons.emoji_emotions;
      default:
        return Icons.post_add;
    }
  }
}

/// Adapter class to make ProfilePostsController compatible with existing post widgets
/// This allows us to reuse existing post widgets without modifying them
class _ProfilePostsControllerAdapter extends PostsFeedController {
  final ProfilePostsController _profileController;

  _ProfilePostsControllerAdapter(this._profileController);

  // Override methods to delegate to ProfilePostsController
  @override
  Future<void> togglePostLike(String postId) async {
    return _profileController.togglePostLike(postId);
  }

  @override
  Future<void> togglePostFavorite(String postId) async {
    return _profileController.togglePostFavorite(postId);
  }

  @override
  Future<void> updatePostEngagement(
    String postId,
    String engagementType,
    int increment,
  ) async {
    return _profileController.updatePostEngagement(
      postId,
      engagementType,
      increment,
    );
  }

  // Override the posts getter to return profile posts
  @override
  RxList<PostModel> get posts => _profileController.profilePosts;
}

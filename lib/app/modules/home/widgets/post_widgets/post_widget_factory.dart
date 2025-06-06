import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'text_post_widget.dart';
import 'image_post_widget.dart';
import 'gif_post_widget.dart';
import 'video_post_widget.dart';
import 'sticker_post_widget.dart';
import 'post_view_tracker.dart';

/// Factory class to create appropriate post widgets based on post type
class PostWidgetFactory {
  /// Creates the appropriate post widget based on the post type
  static Widget createPostWidget({
    required PostModel post,
    required PostsFeedController controller,
  }) {
    Widget postWidget;

    switch (post.postType.toLowerCase()) {
      case 'text':
        postWidget = TextPostWidget(post: post, controller: controller);
        break;

      case 'image':
        postWidget = ImagePostWidget(post: post, controller: controller);
        break;

      case 'gif':
        postWidget = GifPostWidget(post: post, controller: controller);
        break;

      case 'video':
        postWidget = VideoPostWidget(post: post, controller: controller);
        break;

      case 'sticker':
        postWidget = StickerPostWidget(post: post, controller: controller);
        break;

      default:
        // Fallback to text post for unknown types
        postWidget = TextPostWidget(post: post, controller: controller);
        break;
    }

    // Wrap with view tracker for intelligent feed learning
    return PostViewTracker(post: post, child: postWidget);
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

  /// Gets the appropriate color for a post type
  static Color getPostTypeColor(String postType) {
    switch (postType.toLowerCase()) {
      case 'text':
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'gif':
        return Colors.purple;
      case 'video':
        return Colors.red;
      case 'sticker':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Gets a human-readable name for a post type
  static String getPostTypeName(String postType) {
    switch (postType.toLowerCase()) {
      case 'text':
        return 'Text Post';
      case 'image':
        return 'Image Post';
      case 'gif':
        return 'GIF Post';
      case 'video':
        return 'Video Post';
      case 'sticker':
        return 'Sticker Post';
      default:
        return 'Unknown Post';
    }
  }

  /// Validates if a post type is supported
  static bool isValidPostType(String postType) {
    const validTypes = ['text', 'image', 'gif', 'video', 'sticker'];
    return validTypes.contains(postType.toLowerCase());
  }

  /// Gets all supported post types
  static List<String> getSupportedPostTypes() {
    return ['text', 'image', 'gif', 'video', 'sticker'];
  }
}

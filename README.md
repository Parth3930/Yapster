# Post Interaction Components

This directory contains reusable components for post interactions like liking, commenting, sharing, and favoriting posts.

## Components

### 1. PostInteractionButtons

A complete set of interaction buttons for posts, including like, comment, share, and favorite.

```dart
PostInteractionButtons(
  post: postModel,
  controller: postsFeedController,
  glassy: true, // Optional: Use glassy UI effect
  onCommentTap: (postId) {
    // Optional: Custom comment tap handler
  },
)
```

### 2. PostActionButton

An individual action button that can be used standalone.

```dart
PostActionButton(
  assetPath: 'assets/postIcons/like.png',
  text: '42', // Optional: Text to display next to icon
  onTap: () => handleTap(),
  glassy: false, // Optional: Use glassy UI effect
  size: 25, // Optional: Icon size
  textColor: Colors.white, // Optional: Text color
)
```

### 3. CommentDialog

A reusable dialog for adding comments to posts.

```dart
// Show the dialog
CommentDialog.show(
  postId: 'post-123',
  onCommentSubmit: (postId, commentText) {
    // Handle comment submission
  },
);
```

## Usage Examples

### Basic Usage in a Post Widget

```dart
import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';

class MyPostWidget extends StatelessWidget {
  final PostModel post;
  final PostsFeedController controller;

  const MyPostWidget({
    Key? key,
    required this.post,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Post content here
          SizedBox(height: 12),
          PostInteractionButtons(
            post: post,
            controller: controller,
          ),
        ],
      ),
    );
  }
}
```

### Using Individual Action Buttons

```dart
import 'package:flutter/material.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_action_button.dart';

class CustomInteractionBar extends StatelessWidget {
  final bool isLiked;
  final int likesCount;
  final VoidCallback onLikeTap;

  const CustomInteractionBar({
    Key? key,
    required this.isLiked,
    required this.likesCount,
    required this.onLikeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PostActionButton(
          assetPath: isLiked
              ? 'assets/postIcons/like_active.png'
              : 'assets/postIcons/like.png',
          text: likesCount.toString(),
          onTap: onLikeTap,
        ),
        // Other custom buttons
      ],
    );
  }
}
```

## Icon Assets

The components use the following icon assets:

- `assets/postIcons/like.png` - Like icon (inactive)
- `assets/postIcons/like_active.png` - Like icon (active)
- `assets/postIcons/comment.png` - Comment icon
- `assets/postIcons/send.png` - Share icon
- `assets/postIcons/star.png` - Favorite icon (inactive)
- `assets/postIcons/star_selected.png` - Favorite icon (active)
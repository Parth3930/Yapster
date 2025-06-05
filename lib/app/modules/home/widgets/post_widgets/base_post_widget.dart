import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'image_post_widget.dart'; // For access to the custom engagement bar builder
import 'dart:ui';

/// Base widget that contains common post elements like header, footer, and engagement buttons
abstract class BasePostWidget extends StatelessWidget {
  final PostModel post;
  final PostsFeedController controller;

  const BasePostWidget({
    super.key,
    required this.post,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth * 0.95,
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(),
          SizedBox(height: 12),
          buildPostContent(), // Abstract method for specific content
          SizedBox(height: 12),
          CustomEngagementBar(post: post, controller: controller),
        ],
      ),
    );
  }

  /// Abstract method to be implemented by specific post type widgets
  Widget buildPostContent();

  Widget _buildPostHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[800],
          backgroundImage:
              post.avatar != null ? NetworkImage(post.avatar!) : null,
          child:
              post.avatar == null
                  ? Icon(Icons.person, color: Colors.grey[600])
                  : null,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.username ?? 'Unknown User',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (post.metadata['verified'] == true)
                        Icon(Icons.verified, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // Handle follow button tap
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Follow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTimeAgo(post.createdAt),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}

class CustomEngagementBar extends StatelessWidget {
  final dynamic post;
  final dynamic controller;
  final bool glassy;
  const CustomEngagementBar({
    Key? key,
    required this.post,
    required this.controller,
    this.glassy = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconsRow = [
      _buildIconWithText(
        assetPath: 'assets/postIcons/like_active.png',
        text: post.likesCount.toString(),
        onTap: () => controller.updatePostEngagement(post.id, 'likes', 1),
      ),
      SizedBox(width: 16),
      _buildIconWithText(
        assetPath: 'assets/postIcons/comment.png',
        text: post.commentsCount.toString(),
        onTap: () {},
      ),
      SizedBox(width: 16),
      _buildIconWithText(
        assetPath: 'assets/postIcons/send.png',
        text: post.sharesCount.toString(),
        onTap: () => controller.updatePostEngagement(post.id, 'shares', 1),
      ),
    ];
    return Row(
      children: [
        glassy ? _buildGlassyPill(iconsRow) : Row(children: iconsRow),
        Spacer(),
        glassy
            ? _buildGlassyIconButton(
              assetPath: 'assets/postIcons/star.png',
              onTap: () {},
            )
            : _buildIconButton(
              assetPath: 'assets/postIcons/star.png',
              onTap: () {},
            ),
      ],
    );
  }

  Widget _buildGlassyIconButton({
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(assetPath, width: 25, height: 25),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(assetPath, width: 25, height: 25),
      ),
    );
  }

  Widget _buildGlassyPill(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: Colors.white.withOpacity(0.28),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Widget _buildIconWithText({
    required String assetPath,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Image.asset(assetPath, width: 25, height: 25),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

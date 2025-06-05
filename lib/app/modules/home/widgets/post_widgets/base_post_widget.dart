import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';

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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(),
          SizedBox(height: 12),
          buildPostContent(), // Abstract method for specific content
          SizedBox(height: 12),
          _buildEngagementSection(),
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
          backgroundColor: Colors.grey[300],
          backgroundImage:
              post.avatar != null ? NetworkImage(post.avatar!) : null,
          child:
              post.avatar == null
                  ? Icon(Icons.person, color: Colors.grey[600])
                  : null,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.username ?? 'Unknown User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatTimeAgo(post.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[500]),
          onSelected: (value) {
            // Handle menu actions
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(value: 'report', child: Text('Report')),
                PopupMenuItem(value: 'save', child: Text('Save')),
                PopupMenuItem(value: 'share', child: Text('Share')),
              ],
        ),
      ],
    );
  }

  Widget _buildEngagementSection() {
    return Row(
      children: [
        _buildEngagementButton(
          Icons.favorite_border,
          post.likesCount.toString(),
          () => controller.updatePostEngagement(post.id, 'likes', 1),
        ),
        SizedBox(width: 24),
        _buildEngagementButton(
          Icons.chat_bubble_outline,
          post.commentsCount.toString(),
          () {}, // TODO: Navigate to comments
        ),
        SizedBox(width: 24),
        _buildEngagementButton(
          Icons.share_outlined,
          post.sharesCount.toString(),
          () => controller.updatePostEngagement(post.id, 'shares', 1),
        ),
        Spacer(),
        Text(
          '${post.viewsCount} views',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEngagementButton(
    IconData icon,
    String count,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          SizedBox(width: 4),
          Text(count, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

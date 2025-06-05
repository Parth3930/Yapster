import 'package:flutter/material.dart';
import 'base_post_widget.dart';

/// Widget for displaying text-only posts
class TextPostWidget extends BasePostWidget {
  const TextPostWidget({
    super.key,
    required super.post,
    required super.controller,
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
          // Use the same header as BasePostWidget
          _buildPostHeader(),
          SizedBox(height: 12),
          buildPostContent(),
          SizedBox(height: 12),
          CustomEngagementBar(
            post: post,
            controller: controller,
            glassy: false,
          ),
        ],
      ),
    );
  }

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

  @override
  Widget buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              post.content,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/comment_model.dart';
import 'package:yapster/app/modules/home/controllers/comment_controller.dart';

class EnhancedCommentWidget extends StatelessWidget {
  final CommentModel comment;
  final CommentController controller;
  final VoidCallback? onReplyTap;
  final bool showReplies;

  const EnhancedCommentWidget({
    super.key,
    required this.comment,
    required this.controller,
    this.onReplyTap,
    this.showReplies = true,
  });

  @override
  Widget build(BuildContext context) {
    final replies =
        showReplies ? controller.getReplies(comment.id) : <CommentModel>[];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          _buildCommentItem(comment, isReply: false),

          // Replies
          if (replies.isNotEmpty) ...[
            SizedBox(height: 8),
            ...replies.map(
              (reply) => Padding(
                padding: EdgeInsets.only(left: 40),
                child: _buildCommentItem(reply, isReply: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment, {required bool isReply}) {
    return Container(
      margin: EdgeInsets.only(bottom: isReply ? 8 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: Colors.grey[800],
            backgroundImage:
                comment.avatar != null ? NetworkImage(comment.avatar!) : null,
            child:
                comment.avatar == null
                    ? Icon(
                      Icons.person,
                      color: Colors.grey[600],
                      size: isReply ? 16 : 20,
                    )
                    : null,
          ),
          SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with username and time
                Row(
                  children: [
                    Text(
                      comment.username ?? 'Unknown User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isReply ? 13 : 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isReply ? 11 : 12,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isReply ? 13 : 14,
                  ),
                ),

                SizedBox(height: 8),

                // Interaction row (likes and replies)
                Row(
                  children: [
                    // Like button and count
                    Obx(() {
                      final isLiked = comment.isLiked;
                      return GestureDetector(
                        onTap: () => controller.toggleCommentLike(comment.id),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey[500],
                              size: isReply ? 14 : 16,
                            ),
                            if (comment.likesCount > 0) ...[
                              SizedBox(width: 4),
                              Text(
                                _formatCount(comment.likesCount),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: isReply ? 11 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    SizedBox(width: 16),

                    // Reply button (only for top-level comments)
                    if (!isReply)
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Row(
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              color: Colors.grey[500],
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Replies count (only for top-level comments with replies)
                if (!isReply && showReplies) ...[
                  SizedBox(height: 8),
                  Obx(() {
                    final repliesCount =
                        controller.getReplies(comment.id).length;
                    if (repliesCount > 0) {
                      return Text(
                        '$repliesCount ${repliesCount == 1 ? 'Reply' : 'Replies'}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }),
                ],
              ],
            ),
          ),
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}

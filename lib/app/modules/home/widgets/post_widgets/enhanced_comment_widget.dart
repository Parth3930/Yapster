import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/comment_model.dart';
import 'package:yapster/app/modules/home/controllers/comment_controller.dart';

class EnhancedCommentWidget extends StatelessWidget {
  final CommentModel comment;
  final CommentController controller;
  final VoidCallback? onReplyTap;
  final bool isReply;

  const EnhancedCommentWidget({
    super.key,
    required this.comment,
    required this.controller,
    this.onReplyTap,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isReply) {
      // Render reply with connecting line
      return _buildReplyComment();
    } else {
      // Render parent comment with replies section
      return _buildParentComment();
    }
  }

  Widget _buildParentComment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main comment
        _buildCommentRow(),

        // Replies section with connecting line
        Obx(() {
          final replies = controller.getReplies(comment.id);
          final isExpanded = controller.areRepliesExpanded(comment.id);

          if (replies.isEmpty) return SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Connecting line from parent profile picture
              Positioned(
                left: 16,
                top: -40,
                child: Container(
                  width: 1,
                  height: isExpanded ? (replies.length * 63.0) : 60,
                  decoration: BoxDecoration(
                    color: Color(0xff474747),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              // Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "X Replies" button
                  if (!isExpanded) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(width: 16),
                        Container(
                          width: 12,
                          height: 1,
                          margin: EdgeInsets.only(right: 8, top: 8),
                          decoration: BoxDecoration(
                            color: Color(0xff474747),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () =>
                                  controller.toggleRepliesExpanded(comment.id),
                          child: Text(
                            '${replies.length} ${replies.length == 1 ? 'Reply' : 'Replies'}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Expanded replies
                  if (isExpanded) ...[
                    SizedBox(height: 8),
                    ...replies.map((reply) {
                      return Stack(
                        children: [
                          // Horizontal connecting line to reply profile picture
                          Positioned(
                            left: 16,
                            top: 14,
                            child: Container(
                              width: 50,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),

                          // Reply widget
                          Container(
                            margin: EdgeInsets.only(left: 44),
                            child: EnhancedCommentWidget(
                              comment: reply,
                              controller: controller,
                              isReply: true,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildReplyComment() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: _buildCommentRow(),
    );
  }

  Widget _buildCommentRow() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture
          Container(
            width: isReply ? 28 : 32,
            height: isReply ? 28 : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image:
                  comment.avatar != null && comment.avatar!.isNotEmpty
                      ? DecorationImage(
                        image: NetworkImage(comment.avatar!),
                        fit: BoxFit.cover,
                      )
                      : null,
              color:
                  comment.avatar == null || comment.avatar!.isEmpty
                      ? Colors.grey[300]
                      : null,
            ),
            child:
                comment.avatar == null || comment.avatar!.isEmpty
                    ? Icon(
                      Icons.person,
                      color: Colors.grey[600],
                      size: isReply ? 16 : 18,
                    )
                    : null,
          ),

          SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username on first line
                Text(
                  comment.username ?? 'Unknown User',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isReply ? 13 : 14,
                  ),
                ),

                SizedBox(height: 4),

                // Comment content on next line
                Text(
                  comment.content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isReply ? 13 : 14,
                  ),
                ),

                SizedBox(height: 8),

                // Interaction row
                Row(
                  children: [
                    // Time ago
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: isReply ? 11 : 12,
                      ),
                    ),

                    SizedBox(width: 16),

                    // Like button and count
                    Obx(() {
                      final currentComment =
                          controller.comments.firstWhereOrNull(
                            (c) => c.id == comment.id,
                          ) ??
                          comment;
                      final isLiked = currentComment.isLiked;

                      return GestureDetector(
                        onTap: () => controller.toggleCommentLike(comment.id),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey[500],
                              size: isReply ? 14 : 16,
                            ),
                            if (currentComment.likesCount > 0) ...[
                              SizedBox(width: 4),
                              Text(
                                _formatCount(currentComment.likesCount),
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

                    // Reply button (only for parent comments)
                    if (!isReply && onReplyTap != null)
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
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

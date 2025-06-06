import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/models/comment_model.dart';
import 'package:yapster/app/modules/home/controllers/comment_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_comment_widget.dart';

/// Enhanced comment dialog that shows existing comments and allows adding new ones
class CommentDialog extends StatefulWidget {
  final String postId;
  final Function(String, String) onCommentSubmit;
  final PostModel? post;

  const CommentDialog({
    super.key,
    required this.postId,
    required this.onCommentSubmit,
    this.post,
  });

  @override
  State<CommentDialog> createState() => _CommentDialogState();

  /// Static method to show the comment dialog as a bottom sheet
  static void show({
    required String postId,
    required Function(String, String) onCommentSubmit,
    PostModel? post,
  }) {
    Get.bottomSheet(
      CommentDialog(
        postId: postId,
        onCommentSubmit: onCommentSubmit,
        post: post,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _CommentDialogState extends State<CommentDialog> {
  final commentController = TextEditingController();
  final FocusNode commentFocusNode = FocusNode();
  late final CommentController _commentController;
  final RxString replyingToCommentId = ''.obs;
  final RxString replyingToUsername = ''.obs;

  @override
  void initState() {
    super.initState();
    _commentController = Get.put(
      CommentController(),
      tag: 'comment_${widget.postId}',
    );
    _loadComments();
  }

  Future<void> _loadComments() async {
    await _commentController.loadComments(widget.postId);
  }

  Future<void> _addComment(String text, {String? parentId}) async {
    if (text.trim().isEmpty) return;

    final newComment = await _commentController.addComment(
      widget.postId,
      text.trim(),
      parentId: parentId,
    );

    if (newComment != null) {
      commentController.clear();
      commentFocusNode.unfocus();

      // Clear reply state
      replyingToCommentId.value = '';
      replyingToUsername.value = '';

      // Update post comments count in the parent widget
      widget.onCommentSubmit(widget.postId, text.trim());
    } else {
      Get.snackbar(
        'Error',
        'Failed to add comment. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _startReply(CommentModel comment) {
    replyingToCommentId.value = comment.id;
    replyingToUsername.value = comment.username ?? 'Unknown User';
    commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    replyingToCommentId.value = '';
    replyingToUsername.value = '';
    commentFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 10),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.dongle().fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              // Comments list
              Expanded(
                child: Obx(() {
                  if (_commentController.isLoading.value &&
                      _commentController.comments.isEmpty) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.red[300]!,
                        ),
                      ),
                    );
                  }

                  if (_commentController.comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet. Be the first to comment!',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  final topLevelComments =
                      _commentController.getTopLevelComments();

                  return ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: topLevelComments.length,
                    itemBuilder: (context, index) {
                      final comment = topLevelComments[index];
                      return EnhancedCommentWidget(
                        comment: comment,
                        controller: _commentController,
                        onReplyTap: () => _startReply(comment),
                      );
                    },
                  );
                }),
              ),
              // Comment input
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                ),
                child: Column(
                  children: [
                    // Reply indicator
                    Obx(() {
                      if (replyingToCommentId.value.isNotEmpty) {
                        return Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Replying to ${replyingToUsername.value}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                              Spacer(),
                              GestureDetector(
                                onTap: _cancelReply,
                                child: Icon(
                                  Icons.close,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    }),
                    // Input row
                    Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => TextField(
                              controller: commentController,
                              focusNode: commentFocusNode,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText:
                                    replyingToCommentId.value.isNotEmpty
                                        ? 'Reply to ${replyingToUsername.value}...'
                                        : 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[800],
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.red[300]),
                          onPressed: () {
                            final parentId =
                                replyingToCommentId.value.isNotEmpty
                                    ? replyingToCommentId.value
                                    : null;
                            _addComment(
                              commentController.text,
                              parentId: parentId,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

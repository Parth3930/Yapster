import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/post_model.dart';

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
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> comments = <Map<String, dynamic>>[].obs;
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final FocusNode commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    isLoading.value = true;
    try {
      final response = await _supabase.client
          .from('post_comments')
          .select('*, profiles:profiles!user_id(username, avatar)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false)
          .limit(20);

      if (response.isNotEmpty) {
        comments.value = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _addComment(String text, {String? parentId}) async {
    if (text.trim().isEmpty) return;

    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar(
        'Error',
        'You need to be logged in to comment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      Map<String, dynamic> commentData = {
        'post_id': widget.postId,
        'user_id': userId,
        'content': text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'parent_id': parentId, // Set to null for top-level comments
        'likes': 0, // Initialize likes to 0
      };

      final response =
          await _supabase.client
              .from('post_comments')
              .insert(commentData)
              .select('id, *, profiles:profiles!user_id(username, avatar)')
              .single();

      if (response.isNotEmpty) {
        comments.insert(0, Map<String, dynamic>.from(response));

        // Fetch the current comments count
        final postResponse =
            await _supabase.client
                .from('posts')
                .select('id, comments_count')
                .eq('id', widget.postId)
                .single();

        if (postResponse.isNotEmpty) {
          final currentCount = postResponse['comments_count'] as int;
          debugPrint('Current comments count: $currentCount');
          debugPrint('Post ID from response: ${postResponse['id']}');

          // Update the comments count
          final updateResponse =
              await _supabase.client
                  .from('posts')
                  .update({'comments_count': currentCount + 1})
                  .eq('id', widget.postId)
                  .select(); // Use select() to get the updated row

          if (updateResponse.isEmpty) {
            debugPrint('Error updating comments count: No rows affected');
            debugPrint('Post ID used for update: ${widget.postId}');
          } else {
            debugPrint('Comments count updated successfully');
          }
        } else {
          debugPrint('Post not found or comments_count is null');
          debugPrint('Post ID used for fetching: ${widget.postId}');
        }
      }

      commentController.clear();
      widget.onCommentSubmit(widget.postId, text.trim());
    } catch (e) {
      debugPrint('Error adding comment: $e');
      Get.snackbar(
        'Error',
        'Failed to add comment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
            color: Colors.black.withOpacity(0.7),
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
                  if (isLoading.value && comments.isEmpty) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.red[300]!,
                        ),
                      ),
                    );
                  }

                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet. Be the first to comment!',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final profile =
                          comment['profiles'] as Map<String, dynamic>?;
                      final username = profile?['username'] ?? 'Unknown User';
                      final avatar = profile?['avatar'] as String?;
                      final content = comment['content'] as String;
                      final createdAt = DateTime.parse(
                        comment['created_at'] as String,
                      );

                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.grey[800],
                              backgroundImage:
                                  avatar != null ? NetworkImage(avatar) : null,
                              child:
                                  avatar == null
                                      ? Icon(
                                        Icons.person,
                                        color: Colors.grey[600],
                                        size: 20,
                                      )
                                      : null,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        username,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        _formatTimeAgo(createdAt),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    content,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.favorite_border,
                                        color: Colors.grey[500],
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Like',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(
                                        Icons.reply,
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              // Comment input
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        focusNode: commentFocusNode,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
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
                    SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.red[300]),
                      onPressed: () {
                        _addComment(commentController.text);
                      },
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

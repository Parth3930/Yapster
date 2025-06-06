import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/comment_model.dart';

class CommentController extends GetxController {
  final SupabaseService _supabase = Get.find<SupabaseService>();

  // Observable lists for comments
  final RxList<CommentModel> comments = <CommentModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString currentUserId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';
  }

  /// Load comments for a specific post
  Future<void> loadComments(String postId) async {
    try {
      isLoading.value = true;
      
      final response = await _supabase.client
          .from('post_comments')
          .select('*, profiles:profiles!user_id(username, avatar)')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(50);

      if (response.isNotEmpty) {
        final commentsList = (response as List).map((comment) => CommentModel.fromMap(comment)).toList();
        
        // Load like status for current user
        await _loadCommentLikeStatus(commentsList);
        
        comments.assignAll(commentsList);
        debugPrint('Loaded ${commentsList.length} comments for post: $postId');
      } else {
        comments.clear();
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load like status for comments
  Future<void> _loadCommentLikeStatus(List<CommentModel> commentsList) async {
    if (currentUserId.value.isEmpty || commentsList.isEmpty) return;

    try {
      final commentIds = commentsList.map((c) => c.id).toList();
      
      final likesResponse = await _supabase.client
          .from('post_comment_likes')
          .select('comment_id')
          .eq('user_id', currentUserId.value)
          .inFilter('comment_id', commentIds);

      final likedCommentIds = (likesResponse as List)
          .map((like) => like['comment_id'] as String)
          .toSet();

      // Update metadata for each comment
      for (var comment in commentsList) {
        comment.metadata['isLiked'] = likedCommentIds.contains(comment.id);
      }
    } catch (e) {
      debugPrint('Error loading comment like status: $e');
    }
  }

  /// Add a new comment
  Future<CommentModel?> addComment(String postId, String content, {String? parentId}) async {
    if (content.trim().isEmpty || currentUserId.value.isEmpty) return null;

    try {
      final commentData = {
        'post_id': postId,
        'user_id': currentUserId.value,
        'content': content.trim(),
        'parent_id': parentId,
        'likes': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase.client
          .from('post_comments')
          .insert(commentData)
          .select('*, profiles:profiles!user_id(username, avatar)')
          .single();

      if (response.isNotEmpty) {
        final newComment = CommentModel.fromMap(response);
        newComment.metadata['isLiked'] = false;
        
        // Add to the beginning of the list
        comments.insert(0, newComment);
        
        // Update post comments count
        await _updatePostCommentsCount(postId, 1);
        
        debugPrint('Added new comment: ${newComment.id}');
        return newComment;
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
    return null;
  }

  /// Toggle comment like status
  Future<void> toggleCommentLike(String commentId) async {
    if (currentUserId.value.isEmpty) return;

    final commentIndex = comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = comments[commentIndex];
    final isCurrentlyLiked = comment.isLiked;

    try {
      // Update UI immediately for better UX
      final updatedMetadata = Map<String, dynamic>.from(comment.metadata);
      updatedMetadata['isLiked'] = !isCurrentlyLiked;
      
      final updatedComment = comment.copyWith(
        metadata: updatedMetadata,
        likesCount: comment.likesCount + (isCurrentlyLiked ? -1 : 1),
      );
      
      comments[commentIndex] = updatedComment;

      // Update database
      if (!isCurrentlyLiked) {
        // Add like
        await _supabase.client.from('post_comment_likes').upsert({
          'user_id': currentUserId.value,
          'comment_id': commentId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Update comment likes count
        await _supabase.client
            .from('post_comments')
            .update({'likes': comment.likesCount + 1})
            .eq('id', commentId);
      } else {
        // Remove like
        await _supabase.client
            .from('post_comment_likes')
            .delete()
            .eq('user_id', currentUserId.value)
            .eq('comment_id', commentId);
            
        // Update comment likes count
        await _supabase.client
            .from('post_comments')
            .update({'likes': comment.likesCount - 1})
            .eq('id', commentId);
      }

      debugPrint('Successfully ${isCurrentlyLiked ? 'unliked' : 'liked'} comment: $commentId');
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      // Revert UI change on error
      comments[commentIndex] = comment;
    }
  }

  /// Update post comments count
  Future<void> _updatePostCommentsCount(String postId, int increment) async {
    try {
      final postResponse = await _supabase.client
          .from('posts')
          .select('comments_count')
          .eq('id', postId)
          .single();

      if (postResponse.isNotEmpty) {
        final currentCount = postResponse['comments_count'] as int;
        await _supabase.client
            .from('posts')
            .update({'comments_count': currentCount + increment})
            .eq('id', postId);
      }
    } catch (e) {
      debugPrint('Error updating post comments count: $e');
    }
  }

  /// Get replies for a specific comment
  List<CommentModel> getReplies(String parentCommentId) {
    return comments.where((comment) => comment.parentId == parentCommentId).toList();
  }

  /// Get top-level comments (not replies)
  List<CommentModel> getTopLevelComments() {
    return comments.where((comment) => !comment.isReply).toList();
  }

  /// Clear all comments
  void clearComments() {
    comments.clear();
  }
}

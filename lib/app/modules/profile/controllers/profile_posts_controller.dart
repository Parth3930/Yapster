import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';

/// Controller specifically for managing posts in profile pages
/// This allows users to like/unlike their own posts and other users' posts in profile views
class ProfilePostsController extends GetxController {
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final PostRepository _postRepository = Get.find<PostRepository>();
  final UserPostsCacheService _cacheService = Get.find<UserPostsCacheService>();

  // Observable lists for profile posts
  final RxList<PostModel> profilePosts = <PostModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString currentUserId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';
  }

  /// Load posts for a specific user profile using cache
  Future<void> loadUserPosts(String userId, {bool forceRefresh = false}) async {
    try {
      // Check if we have cached posts and don't need to show loading
      final hasCachedPosts = _cacheService.hasCachedPosts(userId);

      // Only show loading if we don't have cached posts
      if (!hasCachedPosts) {
        isLoading.value = true;
      }

      // Load posts from cache service (handles database calls internally)
      final posts = await _cacheService.getUserPosts(
        userId,
        forceRefresh: forceRefresh,
      );

      // Fetch likes and favorites for the current user (only if we have posts)
      if (posts.isNotEmpty) {
        final likesResponse = await _supabase.client
            .from('post_likes')
            .select('post_id')
            .eq('user_id', currentUserId.value);

        final favoritesResponse = await _supabase.client
            .from('user_favorites')
            .select('post_id')
            .eq('user_id', currentUserId.value);

        final likes = likesResponse as List<dynamic>;
        final favorites = favoritesResponse as List<dynamic>;

        // Update posts with like and favorite status
        for (var post in posts) {
          post.metadata['isLiked'] = likes.any(
            (like) => like['post_id'] == post.id,
          );
          post.metadata['isFavorited'] = favorites.any(
            (favorite) => favorite['post_id'] == post.id,
          );
        }
      }

      profilePosts.assignAll(posts);
      debugPrint(
        'Loaded ${posts.length} profile posts for user: $userId (cached: $hasCachedPosts)',
      );
    } catch (e) {
      debugPrint('Error loading profile posts: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Toggle post like status
  Future<void> togglePostLike(String postId) async {
    final postIndex = profilePosts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = profilePosts[postIndex];
      final isCurrentlyLiked = post.metadata['isLiked'] == true;

      // Update metadata
      final updatedMetadata = Map<String, dynamic>.from(post.metadata);
      updatedMetadata['isLiked'] = !isCurrentlyLiked;

      // Update post with new metadata and like count
      final updatedPost = post.copyWith(
        metadata: updatedMetadata,
        likesCount: post.likesCount + (isCurrentlyLiked ? -1 : 1),
      );

      profilePosts[postIndex] = updatedPost;

      // Update in database
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          if (!isCurrentlyLiked) {
            // Add to post_likes
            await _supabase.client.from('post_likes').upsert({
              'user_id': userId,
              'post_id': postId,
              'created_at': DateTime.now().toIso8601String(),
            });
          } else {
            // Remove from post_likes
            await _supabase.client
                .from('post_likes')
                .delete()
                .eq('user_id', userId)
                .eq('post_id', postId);
          }

          // Update cache with the new post data
          _cacheService.updatePostInCache(post.userId, updatedPost);

          debugPrint(
            'Successfully ${isCurrentlyLiked ? 'unliked' : 'liked'} post: $postId',
          );
        } catch (e) {
          debugPrint('Error updating likes in database: $e');
          // Revert the local change if database update fails
          profilePosts[postIndex] = post;
        }
      }

      // Force UI update
      profilePosts.refresh();
    }
  }

  /// Toggle post favorite status
  Future<void> togglePostFavorite(String postId) async {
    final postIndex = profilePosts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = profilePosts[postIndex];
      final isCurrentlyFavorited = post.metadata['isFavorited'] == true;

      // Update metadata
      final updatedMetadata = Map<String, dynamic>.from(post.metadata);
      updatedMetadata['isFavorited'] = !isCurrentlyFavorited;

      // Update post with new metadata
      final updatedPost = post.copyWith(metadata: updatedMetadata);

      profilePosts[postIndex] = updatedPost;

      // Update in database - store in user_favorites table
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          if (!isCurrentlyFavorited) {
            // Add to user_favorites
            await _supabase.client.from('user_favorites').upsert({
              'user_id': userId,
              'post_id': postId,
              'created_at': DateTime.now().toIso8601String(),
            });
          } else {
            // Remove from user_favorites
            await _supabase.client
                .from('user_favorites')
                .delete()
                .eq('user_id', userId)
                .eq('post_id', postId);
          }
          debugPrint(
            'Successfully ${isCurrentlyFavorited ? 'unfavorited' : 'favorited'} post: $postId',
          );
        } catch (e) {
          debugPrint('Error updating favorites in database: $e');
          // Revert the local change if database update fails
          profilePosts[postIndex] = post;
        }
      }

      // Force UI update
      profilePosts.refresh();
    }
  }

  /// Update post engagement (likes, comments, views, shares)
  Future<void> updatePostEngagement(
    String postId,
    String engagementType,
    int increment,
  ) async {
    try {
      // Update in database
      await _postRepository.updatePostEngagement(
        postId,
        engagementType,
        increment,
      );

      // Update local post
      final postIndex = profilePosts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = profilePosts[postIndex];
        PostModel updatedPost;

        switch (engagementType) {
          case 'likes':
            updatedPost = post.copyWith(
              likesCount: post.likesCount + increment,
            );
            break;
          case 'comments':
            updatedPost = post.copyWith(
              commentsCount: post.commentsCount + increment,
            );
            break;
          case 'views':
            updatedPost = post.copyWith(
              viewsCount: post.viewsCount + increment,
            );
            break;
          case 'shares':
            updatedPost = post.copyWith(
              sharesCount: post.sharesCount + increment,
            );
            break;
          default:
            return;
        }

        profilePosts[postIndex] = updatedPost;

        // Update cache
        _cacheService.updatePostInCache(post.userId, updatedPost);

        // Force UI update
        profilePosts.refresh();
      }
    } catch (e) {
      debugPrint('Error updating post engagement: $e');
    }
  }

  /// Get a specific post by ID
  PostModel? getPostById(String postId) {
    try {
      return profilePosts.firstWhere((post) => post.id == postId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all posts
  void clearPosts() {
    profilePosts.clear();
  }

  /// Add a new post to the profile (called when user creates a post)
  void addNewPost(PostModel post) {
    // Add to local list
    profilePosts.insert(0, post);

    // Add to cache
    _cacheService.addPostToCache(post.userId, post);

    debugPrint('Added new post to profile: ${post.id}');
  }

  /// Remove a post from profile and cache
  void removePost(String postId) {
    final postIndex = profilePosts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = profilePosts[postIndex];
      profilePosts.removeAt(postIndex);

      // Remove from cache
      _cacheService.removePostFromCache(post.userId, postId);

      debugPrint('Removed post from profile: $postId');
    }
  }

  /// Get cached posts count for current user
  int getCachedPostsCount() {
    return _cacheService.getCachedPostsCount(currentUserId.value);
  }
}

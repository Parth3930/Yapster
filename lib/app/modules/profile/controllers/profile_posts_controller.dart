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
      // The cache service now validates cached posts against database results
      final posts = await _cacheService.getUserPosts(
        userId,
        forceRefresh: forceRefresh,
      );

      // Load engagement states for posts using the new user_interactions table
      if (posts.isNotEmpty) {
        debugPrint(
          'Loading engagement states for ${posts.length} profile posts',
        );
        await _loadEngagementStates(posts);
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

      // Update in database using the new toggle function
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          // Use the new toggle function
          final success = await _postRepository.togglePostEngagement(
            postId,
            userId,
            'likes',
          );

          if (success) {
            // Update metadata
            final updatedMetadata = Map<String, dynamic>.from(post.metadata);
            updatedMetadata['isLiked'] = !isCurrentlyLiked;

            // Update post with new metadata and like count
            final updatedPost = post.copyWith(
              metadata: updatedMetadata,
              likesCount: post.likesCount + (isCurrentlyLiked ? -1 : 1),
            );

            profilePosts[postIndex] = updatedPost;

            // Update cache with the new post data
            _cacheService.updatePostInCache(post.userId, updatedPost);

            debugPrint(
              'Successfully ${isCurrentlyLiked ? 'unliked' : 'liked'} post: $postId',
            );
          }
        } catch (e) {
          debugPrint('Error updating likes in database: $e');
          // Don't update UI if database operation failed
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

      // Update in database using the new toggle function
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          // Use the new toggle function
          final success = await _postRepository.togglePostEngagement(
            postId,
            userId,
            'stars',
          );

          if (success) {
            // Update metadata
            final updatedMetadata = Map<String, dynamic>.from(post.metadata);
            updatedMetadata['isFavorited'] = !isCurrentlyFavorited;

            // Update post with new metadata
            final updatedPost = post.copyWith(metadata: updatedMetadata);
            profilePosts[postIndex] = updatedPost;

            debugPrint(
              'Successfully ${isCurrentlyFavorited ? 'unfavorited' : 'favorited'} post: $postId',
            );
          }
        } catch (e) {
          debugPrint('Error updating favorites in database: $e');
          // Don't update UI if database operation failed
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

  /// Load engagement states for posts
  Future<void> _loadEngagementStates(List<PostModel> postsList) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      for (int i = 0; i < postsList.length; i++) {
        final post = postsList[i];
        final engagement = await _postRepository.getUserPostEngagement(
          post.id,
          userId,
        );

        // Update metadata with engagement state
        final updatedMetadata = Map<String, dynamic>.from(post.metadata);
        updatedMetadata['isLiked'] = engagement['isLiked'];
        updatedMetadata['isFavorited'] = engagement['isFavorited'];

        // Update the post in the list
        postsList[i] = post.copyWith(metadata: updatedMetadata);
      }
    } catch (e) {
      debugPrint('Error loading engagement states: $e');
    }
  }

  /// Get cached posts count for current user
  int getCachedPostsCount() {
    return _cacheService.getCachedPostsCount(currentUserId.value);
  }

  /// Refresh posts for a user (force reload from database)
  Future<void> refreshUserPosts(String userId) async {
    await loadUserPosts(userId, forceRefresh: true);
  }

  /// Invalidate cache and reload posts for a user
  Future<void> invalidateAndReloadUserPosts(String userId) async {
    _cacheService.invalidateUserCache(userId);
    await loadUserPosts(userId);
  }
}

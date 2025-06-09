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

  // Track failed post loads to prevent infinite retries
  final Set<String> _failedPostLoads = <String>{};

  // Track load attempts to prevent infinite loops
  final Set<String> _loadAttempts = <String>{};

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';
  }

  /// Load posts for a specific user profile using cache
  Future<void> loadUserPosts(String userId, {bool forceRefresh = false}) async {
    try {
      // Check if this user's posts have already failed to load
      if (!forceRefresh && _failedPostLoads.contains(userId)) {
        debugPrint(
          'Posts load previously failed for user: $userId - skipping retry',
        );
        return;
      }

      // For other users (non-cached), check if we've already attempted to load
      final currentUserId = _supabase.client.auth.currentUser?.id;
      final isCurrentUser = userId == currentUserId;

      if (!isCurrentUser && !forceRefresh && _loadAttempts.contains(userId)) {
        debugPrint(
          'Posts already attempted to load for other user: $userId - skipping retry',
        );
        return;
      }

      // Mark this load attempt
      _loadAttempts.add(userId);

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

      // If no posts found, ensure we don't keep reloading
      if (posts.isEmpty) {
        debugPrint(
          'No posts found for user $userId - cache updated with empty result',
        );
      }
    } catch (e) {
      debugPrint('Error loading profile posts: $e');

      // Mark this user's posts as failed to prevent infinite retries
      _failedPostLoads.add(userId);
      debugPrint('Marked posts as failed for user: $userId');
    } finally {
      isLoading.value = false;
    }
  }

  /// Toggle post like status
  Future<void> togglePostLike(String postId) async {
    final postIndex = profilePosts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) {
      debugPrint('Post not found in profile posts: $postId');
      return;
    }

    final post = profilePosts[postIndex];
    final isCurrentlyLiked = post.metadata['isLiked'] == true;
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('User not authenticated');
      return;
    }

    // Debug current state
    debugPrint(
      'Profile like toggle started for $postId: currently liked = $isCurrentlyLiked',
    );

    // Optimistic UI update - immediately show the expected state
    final optimisticLiked = !isCurrentlyLiked;
    final optimisticCount = post.likesCount + (optimisticLiked ? 1 : -1);

    debugPrint(
      'Profile optimistic update: $postId -> liked: $optimisticLiked, count: $optimisticCount',
    );

    // Update UI immediately for better UX
    final optimisticMetadata = Map<String, dynamic>.from(post.metadata);
    optimisticMetadata['isLiked'] = optimisticLiked;

    final optimisticPost = post.copyWith(
      likesCount: optimisticCount,
      metadata: optimisticMetadata,
    );

    profilePosts[postIndex] = optimisticPost;
    profilePosts.refresh();

    try {
      // Use the dedicated togglePostLike function instead of togglePostEngagement
      final result = await _postRepository.togglePostLike(postId, userId);

      if (result != null) {
        final newIsLiked = result['isLiked'] as bool;
        final newLikesCount = result['likesCount'] as int;

        debugPrint(
          'Profile like toggle successful. Server state: $newIsLiked, Count: $newLikesCount',
        );

        // Update with actual server response
        final serverMetadata = Map<String, dynamic>.from(post.metadata);
        serverMetadata['isLiked'] = newIsLiked;

        final serverPost = post.copyWith(
          likesCount: newLikesCount,
          metadata: serverMetadata,
        );

        profilePosts[postIndex] = serverPost;
        profilePosts.refresh();

        // Update cache with the new post data
        _cacheService.updatePostInCache(post.userId, serverPost);

        debugPrint(
          'Successfully ${newIsLiked ? 'liked' : 'unliked'} post: $postId',
        );
      } else {
        debugPrint('Profile like toggle failed - reverting optimistic update');
        // Revert optimistic update on failure
        final revertedMetadata = Map<String, dynamic>.from(post.metadata);
        revertedMetadata['isLiked'] = isCurrentlyLiked;

        final revertedPost = post.copyWith(
          likesCount: post.likesCount,
          metadata: revertedMetadata,
        );

        profilePosts[postIndex] = revertedPost;
        profilePosts.refresh();
      }
    } catch (e) {
      debugPrint(
        'Error toggling profile post like: $e - reverting optimistic update',
      );

      // Revert optimistic update on error
      final revertedMetadata = Map<String, dynamic>.from(post.metadata);
      revertedMetadata['isLiked'] = isCurrentlyLiked;

      final revertedPost = post.copyWith(
        likesCount: post.likesCount,
        metadata: revertedMetadata,
      );

      profilePosts[postIndex] = revertedPost;
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

  /// Load engagement states for posts (likes and favorites)
  Future<void> _loadEngagementStates(List<PostModel> postsList) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Batch load favorites for performance
      final userFavorites = await _loadUserFavorites(userId);
      debugPrint(
        'Loaded ${userFavorites.length} favorites for user $userId in profile',
      );

      for (int i = 0; i < postsList.length; i++) {
        final post = postsList[i];

        // Get like state using the optimized function
        final likeState = await _postRepository.getUserPostLikeState(
          post.id,
          userId,
        );

        // Update metadata with engagement state
        final updatedMetadata = Map<String, dynamic>.from(post.metadata);
        updatedMetadata['isLiked'] = likeState?['isLiked'] ?? false;

        // Check if post is favorited using pre-loaded user_favorites data
        final isFavorited = userFavorites.contains(post.id);
        updatedMetadata['isFavorited'] = isFavorited;

        debugPrint(
          'Profile - Post ${post.id} - isLiked: ${updatedMetadata['isLiked']}, isFavorited: $isFavorited',
        );

        // Update the post in the list with correct likes count from database
        final updatedLikesCount = likeState?['likesCount'] ?? post.likesCount;
        postsList[i] = post.copyWith(
          metadata: updatedMetadata,
          likesCount: updatedLikesCount,
        );
      }
    } catch (e) {
      debugPrint('Error loading engagement states in profile: $e');
    }
  }

  /// Load engagement states for cached posts and update the controller
  Future<void> loadEngagementStatesForCachedPosts(
    List<PostModel> cachedPosts,
  ) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Create a copy of the cached posts to update
      final updatedPosts = List<PostModel>.from(cachedPosts);

      // Load engagement states
      await _loadEngagementStates(updatedPosts);

      // Update the controller with the posts that have engagement states
      profilePosts.assignAll(updatedPosts);
      debugPrint(
        'Updated ${updatedPosts.length} cached posts with engagement states',
      );
    } catch (e) {
      debugPrint('Error loading engagement states for cached posts: $e');
    }
  }

  /// Load user favorites for batch processing
  Future<Set<String>> _loadUserFavorites(String userId) async {
    try {
      final response = await _supabase.client
          .from('user_favorites')
          .select('post_id')
          .eq('user_id', userId);

      return response.map((item) => item['post_id'] as String).toSet();
    } catch (e) {
      debugPrint('Error loading user favorites in profile: $e');
      return {};
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

  /// Clear failed post loads to allow retry
  void clearFailedPostLoads() {
    _failedPostLoads.clear();
    debugPrint('Cleared failed post loads cache');
  }

  /// Remove specific user from failed post loads
  void clearFailedPostLoad(String userId) {
    _failedPostLoads.remove(userId);
    debugPrint('Cleared failed post load for user: $userId');
  }

  /// Clear load attempts to allow retry
  void clearLoadAttempts() {
    _loadAttempts.clear();
    debugPrint('Cleared load attempts cache');
  }

  /// Remove specific user from load attempts
  void clearLoadAttempt(String userId) {
    _loadAttempts.remove(userId);
    debugPrint('Cleared load attempt for user: $userId');
  }

  /// Check if load was attempted for user
  bool hasLoadAttempted(String userId) {
    return _loadAttempts.contains(userId);
  }
}

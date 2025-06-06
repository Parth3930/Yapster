import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/startup/feed_loader/feed_loader_service.dart';
import 'package:yapster/app/core/services/user_interaction_service.dart';
import 'package:yapster/app/core/services/intelligent_feed_service.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'dart:async';

class PostsFeedController extends GetxController {
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final PostRepository _postRepository = Get.find<PostRepository>();
  final UserInteractionService _interactionService =
      Get.find<UserInteractionService>();
  final IntelligentFeedService _feedService =
      Get.find<IntelligentFeedService>();
  final UserPostsCacheService _cacheService = Get.find<UserPostsCacheService>();

  // Observable lists
  final RxList<PostModel> posts = <PostModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxString currentUserId = ''.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMorePosts = true.obs;

  // Cache management
  DateTime? _lastPostsLoad;
  static const Duration _postsCacheDuration = Duration(
    minutes: 5,
  ); // Increased cache duration
  int _currentOffset = 0;
  static const int _postsPerPage =
      15; // Increased page size for better performance

  // Realtime subscription
  RealtimeChannel? _postsSubscription;

  // Periodic refresh for empty feed
  Timer? _periodicRefreshTimer;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';

    // Always try to load posts, even if preloaded data exists
    // This ensures consistency on hot reload
    _initializeFeed();
    _setupRealtimeSubscription();
  }

  /// Initialize feed with proper fallback handling
  Future<void> _initializeFeed() async {
    try {
      // Check if we have preloaded posts and they're recent
      if (FeedLoaderService.preloadedPosts.isNotEmpty &&
          _lastPostsLoad == null) {
        posts.assignAll(FeedLoaderService.preloadedPosts);
        hasLoadedOnce.value = true;
        isLoading.value = false;
        _lastPostsLoad = DateTime.now();
        debugPrint('Using preloaded posts: ${posts.length}');
      } else {
        // Load fresh posts
        await loadPosts(forceRefresh: true);
      }

      // Start periodic refresh if feed is empty
      _startPeriodicRefreshIfNeeded();
    } catch (e) {
      debugPrint('Error initializing feed: $e');
      // Fallback to loading posts normally
      await loadPosts();
    }
  }

  @override
  void onClose() {
    _postsSubscription?.unsubscribe();
    _periodicRefreshTimer?.cancel();
    super.onClose();
  }

  /// Start periodic refresh if feed is empty
  void _startPeriodicRefreshIfNeeded() {
    if (posts.isEmpty) {
      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (posts.isEmpty) {
          debugPrint('Feed still empty, checking for new posts...');
          loadPosts(forceRefresh: true);
        } else {
          // Stop timer once we have posts
          timer.cancel();
        }
      });
    }
  }

  /// Stop periodic refresh
  void _stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  /// Setup realtime subscription for posts
  void _setupRealtimeSubscription() {
    _postsSubscription =
        _supabase.client
            .channel('posts_realtime')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                debugPrint('New post inserted: ${payload.newRecord}');
                _handleNewPost(payload.newRecord);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                debugPrint('Post updated: ${payload.newRecord}');
                _handlePostUpdate(payload.newRecord);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                debugPrint('Post deleted: ${payload.oldRecord}');
                _handlePostDelete(payload.oldRecord);
              },
            )
            .subscribe();
  }

  /// Handle new post from realtime
  void _handleNewPost(Map<String, dynamic> postData) {
    try {
      // Don't add current user's posts to feed
      if (postData['user_id'] == currentUserId.value) return;

      // Check if post is active and not deleted
      if (postData['is_active'] == true && postData['is_deleted'] == false) {
        final newPost = PostModel.fromMap(postData);

        // Add to beginning of feed
        posts.insert(0, newPost);
        _currentOffset++;

        // Limit feed size to prevent memory issues
        if (posts.length > 100) {
          posts.removeLast();
        }
      }
    } catch (e) {
      debugPrint('Error handling new post: $e');
    }
  }

  /// Handle post update from realtime
  void _handlePostUpdate(Map<String, dynamic> postData) {
    try {
      final postId = postData['id'];
      final postIndex = posts.indexWhere((post) => post.id == postId);

      if (postIndex != -1) {
        // Check if post should be removed (deleted or inactive)
        if (postData['is_active'] == false || postData['is_deleted'] == true) {
          posts.removeAt(postIndex);
          _currentOffset--;
        } else {
          // Update existing post
          final updatedPost = PostModel.fromMap(postData);
          posts[postIndex] = updatedPost;
        }
      }
    } catch (e) {
      debugPrint('Error handling post update: $e');
    }
  }

  /// Handle post delete from realtime
  void _handlePostDelete(Map<String, dynamic> postData) {
    try {
      final postId = postData['id'];
      final postIndex = posts.indexWhere((post) => post.id == postId);

      if (postIndex != -1) {
        posts.removeAt(postIndex);
        _currentOffset--;
      }
    } catch (e) {
      debugPrint('Error handling post delete: $e');
    }
  }

  /// Load posts feed with intelligent recommendations
  Future<void> loadPosts({bool forceRefresh = false}) async {
    try {
      // Check if we should use cached data
      if (!forceRefresh && _lastPostsLoad != null && hasLoadedOnce.value) {
        final timeSinceLastLoad = DateTime.now().difference(_lastPostsLoad!);
        if (timeSinceLastLoad < _postsCacheDuration) {
          debugPrint('Using cached posts data');
          return;
        }
      }

      // Only show loading on first load or force refresh
      if (!hasLoadedOnce.value || forceRefresh) {
        isLoading.value = true;
        _currentOffset = 0;
        hasMorePosts.value = true;

        // Reset intelligent feed on refresh
        if (forceRefresh) {
          _feedService.resetFeed();
        }
      }

      if (currentUserId.value.isEmpty) return;

      // Load posts from repository using intelligent feed function
      debugPrint(
        'Loading intelligent posts for user: ${currentUserId.value}, offset: ${forceRefresh ? 0 : _currentOffset}',
      );

      // Try intelligent feed first, fallback to regular feed
      List<PostModel> newPosts;
      try {
        final response = await _supabase.client.rpc(
          'get_intelligent_posts_feed',
          params: {
            'p_user_id': currentUserId.value,
            'p_limit': _postsPerPage,
            'p_offset': forceRefresh ? 0 : _currentOffset,
          },
        );
        newPosts =
            (response as List).map((post) => PostModel.fromMap(post)).toList();
        debugPrint('Loaded ${newPosts.length} intelligent posts');
      } catch (e) {
        debugPrint('Intelligent feed failed, using fallback: $e');
        newPosts = await _postRepository.getPostsFeed(
          currentUserId.value,
          limit: _postsPerPage,
          offset: forceRefresh ? 0 : _currentOffset,
        );
        debugPrint('Loaded ${newPosts.length} fallback posts');
      }

      // Fetch likes and favorites for the current user
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
      for (var post in newPosts) {
        post.metadata['isLiked'] = likes.any(
          (like) => like['post_id'] == post.id,
        );
        post.metadata['isFavorited'] = favorites.any(
          (favorite) => favorite['post_id'] == post.id,
        );
      }

      // Filter out already viewed posts and add to intelligent feed
      final filteredPosts =
          newPosts
              .where((post) => !_interactionService.hasViewedPost(post.id))
              .toList();

      // Add posts to intelligent feed service for future recommendations
      await _feedService.addPostsToFeed(filteredPosts, currentUserId.value);

      if (forceRefresh) {
        posts.assignAll(filteredPosts);
        _currentOffset = filteredPosts.length;
        debugPrint('Refreshed posts list with ${filteredPosts.length} posts');
      } else {
        posts.addAll(filteredPosts);
        _currentOffset += filteredPosts.length;
        debugPrint(
          'Added ${filteredPosts.length} posts to existing list. Total: ${posts.length}',
        );
      }

      // Check if there are more posts
      hasMorePosts.value = newPosts.length == _postsPerPage;

      hasLoadedOnce.value = true;
      _lastPostsLoad = DateTime.now();
      debugPrint(
        'Posts loading completed. hasLoadedOnce: ${hasLoadedOnce.value}, total posts: ${posts.length}',
      );

      // Manage periodic refresh based on posts availability
      if (posts.isEmpty) {
        _startPeriodicRefreshIfNeeded();
      } else {
        _stopPeriodicRefresh();
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (isLoadingMore.value || !hasMorePosts.value) return;

    try {
      isLoadingMore.value = true;

      if (currentUserId.value.isEmpty) return;

      final newPosts = await _postRepository.getPostsFeed(
        currentUserId.value,
        limit: _postsPerPage,
        offset: _currentOffset,
      );

      if (newPosts.isNotEmpty) {
        posts.addAll(newPosts);
        _currentOffset += newPosts.length;
      }

      // Check if there are more posts
      hasMorePosts.value = newPosts.length == _postsPerPage;
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Refresh posts feed
  Future<void> refreshPosts() async {
    await loadPosts(forceRefresh: true);

    // Force update of reactive variables
    posts.refresh();

    // Force UI update
    update();
  }

  /// Add new post to the beginning of the feed
  void addNewPost(PostModel post) {
    posts.insert(0, post);
    _currentOffset++;

    // Add to user's posts cache
    _cacheService.addPostToCache(post.userId, post);
  }

  /// Update post engagement
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
      final postIndex = posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = posts[postIndex];
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

        posts[postIndex] = updatedPost;

        // Force UI update
        posts.refresh();
      }
    } catch (e) {
      debugPrint('Error updating post engagement: $e');
    }
  }

  /// Toggle post like status
  Future<void> togglePostLike(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      final isCurrentlyLiked = post.metadata['isLiked'] == true;

      // Track interaction for learning
      await _interactionService.trackPostLike(
        postId,
        post.postType,
        post.userId,
        !isCurrentlyLiked,
      );

      // Update metadata
      final updatedMetadata = Map<String, dynamic>.from(post.metadata);
      updatedMetadata['isLiked'] = !isCurrentlyLiked;

      // Update post with new metadata and like count
      final updatedPost = post.copyWith(
        metadata: updatedMetadata,
        likesCount: post.likesCount + (isCurrentlyLiked ? -1 : 1),
      );

      posts[postIndex] = updatedPost;

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
        } catch (e) {
          debugPrint('Error updating likes in database: $e');
        }
      }

      // Force UI update
      posts.refresh();
    }
  }

  /// Toggle post favorite status
  Future<void> togglePostFavorite(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      final isCurrentlyFavorited = post.metadata['isFavorited'] == true;

      // Update metadata
      final updatedMetadata = Map<String, dynamic>.from(post.metadata);
      updatedMetadata['isFavorited'] = !isCurrentlyFavorited;

      // Update post with new metadata
      final updatedPost = post.copyWith(metadata: updatedMetadata);

      posts[postIndex] = updatedPost;

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
        } catch (e) {
          debugPrint('Error updating favorites in database: $e');
        }
      }

      // Force UI update
      posts.refresh();
    }
  }

  /// Track post view for learning algorithm
  Future<void> trackPostView(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];

      // Track view interaction
      await _interactionService.trackPostView(
        postId,
        post.postType,
        post.userId,
      );

      // Update view count in database
      await updatePostEngagement(postId, 'views', 1);
    }
  }

  /// Track time spent viewing a post
  Future<void> trackTimeSpent(String postId, Duration timeSpent) async {
    await _interactionService.trackTimeSpent(postId, timeSpent);
  }

  /// Track post comment for learning
  Future<void> trackPostComment(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      await _interactionService.trackPostComment(
        postId,
        post.postType,
        post.userId,
      );
    }
  }

  /// Track post share for learning
  Future<void> trackPostShare(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      await _interactionService.trackPostShare(
        postId,
        post.postType,
        post.userId,
      );
    }
  }

  /// Get feed statistics for debugging
  Map<String, dynamic> getFeedStatistics() {
    return {
      'total_posts': posts.length,
      'viewed_posts': _interactionService.viewedPostsCount,
      'user_preferences': _interactionService.getUserPreferencesSummary(),
      'feed_service_stats': _feedService.getFeedStatistics(),
    };
  }

  /// Clear posts cache and reload
  Future<void> clearCacheAndReload() async {
    _lastPostsLoad = null;
    hasLoadedOnce.value = false;
    _currentOffset = 0;
    _feedService.resetFeed();
    await loadPosts(forceRefresh: true);
  }
}

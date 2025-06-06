import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/startup/feed_loader/feed_loader_service.dart';

class PostsFeedController extends GetxController {
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final PostRepository _postRepository = Get.find<PostRepository>();

  // Observable lists
  final RxList<PostModel> posts = <PostModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxString currentUserId = ''.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMorePosts = true.obs;

  // Cache management
  DateTime? _lastPostsLoad;
  static const Duration _postsCacheDuration = Duration(minutes: 3);
  int _currentOffset = 0;
  static const int _postsPerPage = 10;

  // Realtime subscription
  RealtimeChannel? _postsSubscription;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';
    // Use preloaded feed if available
    if (FeedLoaderService.preloadedPosts.isNotEmpty) {
      posts.assignAll(FeedLoaderService.preloadedPosts);
      hasLoadedOnce.value = true;
      isLoading.value = false;
    } else {
      loadPosts();
    }
    _setupRealtimeSubscription();
  }

  @override
  void onClose() {
    _postsSubscription?.unsubscribe();
    super.onClose();
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

  /// Load posts feed
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
      }

      if (currentUserId.value.isEmpty) return;

      // Load posts from repository
      final newPosts = await _postRepository.getPostsFeed(
        currentUserId.value,
        limit: _postsPerPage,
        offset: forceRefresh ? 0 : _currentOffset,
      );

      // Fetch likes and favorites for the current user
      final likesResponse = await _supabase.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', currentUserId.value)
          .select('*');

      final favoritesResponse = await _supabase.client
          .from('user_favorites')
          .select('post_id')
          .eq('user_id', currentUserId.value)
          .select('*');

      // Check for errors in the response
      if (likesResponse.isNotEmpty) {
        debugPrint('Error fetching likes or favorites');
        return;
      }

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

      if (forceRefresh) {
        posts.assignAll(newPosts);
        _currentOffset = newPosts.length;
      } else {
        posts.addAll(newPosts);
        _currentOffset += newPosts.length;
      }

      // Check if there are more posts
      hasMorePosts.value = newPosts.length == _postsPerPage;

      hasLoadedOnce.value = true;
      _lastPostsLoad = DateTime.now();
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

  /// Clear posts cache and reload
  Future<void> clearCacheAndReload() async {
    _lastPostsLoad = null;
    hasLoadedOnce.value = false;
    _currentOffset = 0;
    await loadPosts(forceRefresh: true);
  }
}

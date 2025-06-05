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
                print('New post inserted: ${payload.newRecord}');
                _handleNewPost(payload.newRecord);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                print('Post updated: ${payload.newRecord}');
                _handlePostUpdate(payload.newRecord);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                print('Post deleted: ${payload.oldRecord}');
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
      print('Error handling new post: $e');
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
      print('Error handling post update: $e');
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
      print('Error handling post delete: $e');
    }
  }

  /// Load posts feed
  Future<void> loadPosts({bool forceRefresh = false}) async {
    try {
      // Check if we should use cached data
      if (!forceRefresh && _lastPostsLoad != null && hasLoadedOnce.value) {
        final timeSinceLastLoad = DateTime.now().difference(_lastPostsLoad!);
        if (timeSinceLastLoad < _postsCacheDuration) {
          print('Using cached posts data');
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
      print('Error loading posts: $e');
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
      print('Error loading more posts: $e');
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
      }
    } catch (e) {
      print('Error updating post engagement: $e');
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

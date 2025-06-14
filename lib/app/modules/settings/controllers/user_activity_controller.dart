import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/post_model.dart';

class UserActivityController extends GetxController {
  late SupabaseService _supabaseService;

  @override
  void onInit() {
    super.onInit();
    _initializeService();
  }

  void _initializeService() {
    try {
      _supabaseService = Get.find<SupabaseService>();
      debugPrint('UserActivityController initialized successfully');
    } catch (e) {
      debugPrint('Error finding SupabaseService: $e');
      // Try again after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          _supabaseService = Get.find<SupabaseService>();
          debugPrint(
            'UserActivityController initialized successfully on retry',
          );
        } catch (e2) {
          debugPrint('Failed to initialize SupabaseService on retry: $e2');
        }
      });
    }
  }

  // Liked posts
  final RxList<PostModel> likedPosts = <PostModel>[].obs;
  final RxBool isLoadingLikedPosts = false.obs;
  final RxBool hasLoadedLikedPosts = false.obs;

  // Commented posts
  final RxList<PostModel> commentedPosts = <PostModel>[].obs;
  final RxBool isLoadingCommentedPosts = false.obs;
  final RxBool hasLoadedCommentedPosts = false.obs;

  // Favorite posts
  final RxList<PostModel> favoritePosts = <PostModel>[].obs;
  final RxBool isLoadingFavoritePosts = false.obs;
  final RxBool hasLoadedFavoritePosts = false.obs;

  // Cache timestamps
  DateTime? _likedPostsLastFetch;
  DateTime? _commentedPostsLastFetch;
  DateTime? _favoritePostsLastFetch;

  static const Duration cacheValidDuration = Duration(minutes: 5);

  // Static method to get or create controller instance
  static UserActivityController get instance {
    try {
      return Get.find<UserActivityController>(tag: 'user_activity');
    } catch (e) {
      debugPrint('UserActivityController not found, creating new instance');
      return Get.put(UserActivityController(), tag: 'user_activity');
    }
  }

  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < cacheValidDuration;
  }

  bool _ensureServiceInitialized() {
    try {
      if (_supabaseService == null) {
        _supabaseService = Get.find<SupabaseService>();
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService not available: $e');
      return false;
    }
  }

  Future<void> loadLikedPosts({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        hasLoadedLikedPosts.value &&
        _isCacheValid(_likedPostsLastFetch)) {
      return; // Use cached data
    }

    try {
      isLoadingLikedPosts.value = true;

      if (!_ensureServiceInitialized()) {
        throw Exception('SupabaseService not available');
      }

      final currentUserId = _supabaseService.currentUser.value?.id;

      if (currentUserId == null) {
        debugPrint('User not logged in');
        return;
      }

      final response = await _supabaseService.client.rpc(
        'get_user_liked_posts',
        params: {'user_uuid': currentUserId},
      );

      if (response != null && response is List) {
        final posts = response.map((item) => _mapToPostModel(item)).toList();
        likedPosts.value = posts;
        hasLoadedLikedPosts.value = true;
        _likedPostsLastFetch = DateTime.now();
      } else {
        likedPosts.clear();
      }
    } catch (e) {
      debugPrint('Error loading liked posts: $e');
      Get.snackbar(
        'Error',
        'Failed to load liked posts',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoadingLikedPosts.value = false;
    }
  }

  Future<void> loadCommentedPosts({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        hasLoadedCommentedPosts.value &&
        _isCacheValid(_commentedPostsLastFetch)) {
      return; // Use cached data
    }

    try {
      isLoadingCommentedPosts.value = true;

      if (!_ensureServiceInitialized()) {
        throw Exception('SupabaseService not available');
      }

      final currentUserId = _supabaseService.currentUser.value?.id;

      if (currentUserId == null) {
        debugPrint('User not logged in');
        return;
      }

      final response = await _supabaseService.client.rpc(
        'get_user_commented_posts',
        params: {'user_uuid': currentUserId},
      );

      if (response != null && response is List) {
        final posts = response.map((item) => _mapToPostModel(item)).toList();
        commentedPosts.value = posts;
        hasLoadedCommentedPosts.value = true;
        _commentedPostsLastFetch = DateTime.now();
      } else {
        commentedPosts.clear();
      }
    } catch (e) {
      debugPrint('Error loading commented posts: $e');
      Get.snackbar(
        'Error',
        'Failed to load commented posts',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoadingCommentedPosts.value = false;
    }
  }

  Future<void> loadFavoritePosts({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        hasLoadedFavoritePosts.value &&
        _isCacheValid(_favoritePostsLastFetch)) {
      return; // Use cached data
    }

    try {
      isLoadingFavoritePosts.value = true;

      if (!_ensureServiceInitialized()) {
        throw Exception('SupabaseService not available');
      }

      final currentUserId = _supabaseService.currentUser.value?.id;

      if (currentUserId == null) {
        debugPrint('User not logged in');
        return;
      }

      final response = await _supabaseService.client.rpc(
        'get_user_favorite_posts',
        params: {'user_uuid': currentUserId},
      );

      if (response != null && response is List) {
        final posts = response.map((item) => _mapToPostModel(item)).toList();
        favoritePosts.value = posts;
        hasLoadedFavoritePosts.value = true;
        _favoritePostsLastFetch = DateTime.now();
      } else {
        favoritePosts.clear();
      }
    } catch (e) {
      debugPrint('Error loading favorite posts: $e');
      Get.snackbar(
        'Error',
        'Failed to load favorite posts',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoadingFavoritePosts.value = false;
    }
  }

  PostModel _mapToPostModel(Map<String, dynamic> item) {
    return PostModel(
      id: item['id'],
      content: item['content'] ?? '',
      imageUrl: item['image_url'],
      videoUrl: item['video_url'],
      createdAt: DateTime.parse(item['created_at']),
      updatedAt: DateTime.parse(item['created_at']),
      userId: item['user_id'],
      likesCount: item['likes_count'] ?? 0,
      commentsCount: item['comments_count'] ?? 0,
      starCount: item['stars_count'] ?? 0,
      username: item['username'] ?? '',
      nickname: item['nickname'] ?? '',
      avatar: item['avatar'],
      googleAvatar: item['google_avatar'],
      postType:
          item['video_url'] != null
              ? 'video'
              : item['image_url'] != null
              ? 'image'
              : 'text',
      metadata: {},
    );
  }

  // Helper methods to convert PostModel to Map for compatibility
  List<Map<String, dynamic>> get likedPostMaps =>
      likedPosts.map((post) => _postModelToMap(post)).toList();

  List<Map<String, dynamic>> get commentedPostMaps =>
      commentedPosts.map((post) => _postModelToMap(post)).toList();

  List<Map<String, dynamic>> get favoritePostMaps =>
      favoritePosts.map((post) => _postModelToMap(post)).toList();

  Map<String, dynamic> _postModelToMap(PostModel post) {
    return {
      'id': post.id,
      'content': post.content,
      'image_url': post.imageUrl,
      'video_url': post.videoUrl,
      'created_at': post.createdAt.toIso8601String(),
      'user_id': post.userId,
      'likes_count': post.likesCount,
      'comments_count': post.commentsCount,
      'stars_count': post.starCount,
      'profiles': {
        'username': post.username,
        'nickname': post.nickname,
        'avatar': post.avatar,
        'google_avatar': post.googleAvatar,
      },
    };
  }

  // Clear cache methods
  void clearLikedPostsCache() {
    hasLoadedLikedPosts.value = false;
    _likedPostsLastFetch = null;
  }

  void clearCommentedPostsCache() {
    hasLoadedCommentedPosts.value = false;
    _commentedPostsLastFetch = null;
  }

  void clearFavoritePostsCache() {
    hasLoadedFavoritePosts.value = false;
    _favoritePostsLastFetch = null;
  }

  void clearAllCache() {
    clearLikedPostsCache();
    clearCommentedPostsCache();
    clearFavoritePostsCache();
  }
}

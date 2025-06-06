import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'dart:convert';

/// Service for caching and managing user posts to avoid repeated database calls
class UserPostsCacheService extends GetxService {
  // Lazy initialization to avoid dependency issues
  SupabaseService get _supabase => Get.find<SupabaseService>();
  StorageService get _storage => Get.find<StorageService>();
  PostRepository get _postRepository => Get.find<PostRepository>();

  // Cache for user posts
  final Map<String, List<PostModel>> _userPostsCache = {};
  final Map<String, DateTime> _lastFetchTime = {};
  final Map<String, bool> _isLoading = {};

  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 10);
  static const String _cacheKeyPrefix = 'user_posts_';

  @override
  void onInit() {
    super.onInit();
    _loadCachedPosts();
  }

  /// Load cached posts from local storage
  void _loadCachedPosts() {
    try {
      // Check if services are available before accessing them
      if (!Get.isRegistered<SupabaseService>() ||
          !Get.isRegistered<StorageService>()) {
        debugPrint('Services not ready yet, skipping cache load');
        return;
      }

      final currentUserId = _supabase.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final cachedData = _storage.getString(
          '${_cacheKeyPrefix}$currentUserId',
        );
        if (cachedData != null) {
          final List<dynamic> postsJson = json.decode(cachedData);
          final posts =
              postsJson.map((json) => PostModel.fromMap(json)).toList();
          _userPostsCache[currentUserId] = posts;
          _lastFetchTime[currentUserId] = DateTime.now();
          debugPrint('Loaded ${posts.length} cached posts for current user');
        }
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }
  }

  /// Get user posts with intelligent caching
  Future<List<PostModel>> getUserPosts(
    String userId, {
    bool forceRefresh = false,
  }) async {
    // Check if already loading
    if (_isLoading[userId] == true) {
      // Wait for current loading to complete
      while (_isLoading[userId] == true) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return _userPostsCache[userId] ?? [];
    }

    // Check cache validity
    if (!forceRefresh && _isCacheValid(userId)) {
      debugPrint('Using cached posts for user: $userId');
      return _userPostsCache[userId] ?? [];
    }

    // Load from database
    return await _loadUserPostsFromDatabase(userId);
  }

  /// Check if cache is valid
  bool _isCacheValid(String userId) {
    final lastFetch = _lastFetchTime[userId];
    if (lastFetch == null) return false;

    final cachedPosts = _userPostsCache[userId];
    if (cachedPosts == null || cachedPosts.isEmpty) return false;

    final timeSinceLastFetch = DateTime.now().difference(lastFetch);
    return timeSinceLastFetch < _cacheDuration;
  }

  /// Load posts from database
  Future<List<PostModel>> _loadUserPostsFromDatabase(String userId) async {
    try {
      _isLoading[userId] = true;
      debugPrint('Loading posts from database for user: $userId');

      final posts = await _postRepository.getUserPosts(userId);

      // Update cache
      _userPostsCache[userId] = posts;
      _lastFetchTime[userId] = DateTime.now();

      // Save to local storage for current user
      final currentUserId = _supabase.client.auth.currentUser?.id;
      if (userId == currentUserId) {
        await _saveCachedPosts(userId, posts);
      }

      debugPrint('Loaded and cached ${posts.length} posts for user: $userId');
      return posts;
    } catch (e) {
      debugPrint('Error loading posts from database: $e');
      return _userPostsCache[userId] ?? [];
    } finally {
      _isLoading[userId] = false;
    }
  }

  /// Save posts to local storage
  Future<void> _saveCachedPosts(String userId, List<PostModel> posts) async {
    try {
      final postsJson = posts.map((post) => post.toMap()).toList();
      await _storage.saveString(
        '${_cacheKeyPrefix}$userId',
        json.encode(postsJson),
      );
    } catch (e) {
      debugPrint('Error saving cached posts: $e');
    }
  }

  /// Add a new post to cache
  void addPostToCache(String userId, PostModel post) {
    final cachedPosts = _userPostsCache[userId] ?? [];
    cachedPosts.insert(0, post); // Add to beginning
    _userPostsCache[userId] = cachedPosts;

    // Save to local storage for current user
    final currentUserId = _supabase.client.auth.currentUser?.id;
    if (userId == currentUserId) {
      _saveCachedPosts(userId, cachedPosts);
    }

    debugPrint('Added new post to cache for user: $userId');
  }

  /// Update a post in cache
  void updatePostInCache(String userId, PostModel updatedPost) {
    final cachedPosts = _userPostsCache[userId];
    if (cachedPosts != null) {
      final index = cachedPosts.indexWhere((post) => post.id == updatedPost.id);
      if (index != -1) {
        cachedPosts[index] = updatedPost;
        _userPostsCache[userId] = cachedPosts;

        // Save to local storage for current user
        final currentUserId = _supabase.client.auth.currentUser?.id;
        if (userId == currentUserId) {
          _saveCachedPosts(userId, cachedPosts);
        }

        debugPrint('Updated post in cache for user: $userId');
      }
    }
  }

  /// Remove a post from cache
  void removePostFromCache(String userId, String postId) {
    final cachedPosts = _userPostsCache[userId];
    if (cachedPosts != null) {
      cachedPosts.removeWhere((post) => post.id == postId);
      _userPostsCache[userId] = cachedPosts;

      // Save to local storage for current user
      final currentUserId = _supabase.client.auth.currentUser?.id;
      if (userId == currentUserId) {
        _saveCachedPosts(userId, cachedPosts);
      }

      debugPrint('Removed post from cache for user: $userId');
    }
  }

  /// Get cached posts count for a user
  int getCachedPostsCount(String userId) {
    return _userPostsCache[userId]?.length ?? 0;
  }

  /// Check if user has cached posts
  bool hasCachedPosts(String userId) {
    return _userPostsCache[userId]?.isNotEmpty ?? false;
  }

  /// Clear cache for a specific user
  void clearUserCache(String userId) {
    _userPostsCache.remove(userId);
    _lastFetchTime.remove(userId);
    _isLoading.remove(userId);

    // Remove from local storage
    _storage.remove('${_cacheKeyPrefix}$userId');
    debugPrint('Cleared cache for user: $userId');
  }

  /// Clear all caches
  void clearAllCaches() {
    _userPostsCache.clear();
    _lastFetchTime.clear();
    _isLoading.clear();
    debugPrint('Cleared all user posts caches');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'cached_users': _userPostsCache.keys.length,
      'total_cached_posts': _userPostsCache.values.fold(
        0,
        (sum, posts) => sum + posts.length,
      ),
      'cache_sizes': _userPostsCache.map(
        (userId, posts) => MapEntry(userId, posts.length),
      ),
      'last_fetch_times': _lastFetchTime,
    };
  }

  /// Preload posts for current user
  Future<void> preloadCurrentUserPosts() async {
    final currentUserId = _supabase.client.auth.currentUser?.id;
    if (currentUserId != null) {
      await getUserPosts(currentUserId);
    }
  }

  /// Update post engagement in cache
  void updatePostEngagementInCache(
    String userId,
    String postId,
    String engagementType,
    int increment,
  ) {
    final cachedPosts = _userPostsCache[userId];
    if (cachedPosts != null) {
      final index = cachedPosts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = cachedPosts[index];
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

        cachedPosts[index] = updatedPost;
        _userPostsCache[userId] = cachedPosts;

        // Save to local storage for current user
        final currentUserId = _supabase.client.auth.currentUser?.id;
        if (userId == currentUserId) {
          _saveCachedPosts(userId, cachedPosts);
        }
      }
    }
  }
}

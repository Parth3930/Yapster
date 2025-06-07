import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'dart:convert';

/// Service for caching and managing user posts to avoid repeated database calls
class UserPostsCacheService extends GetxService {
  // Lazy initialization to avoid dependency issues with null safety
  SupabaseService? get _supabase {
    try {
      return Get.find<SupabaseService>();
    } catch (e) {
      debugPrint('SupabaseService not available yet: $e');
      return null;
    }
  }

  StorageService? get _storage {
    try {
      return Get.find<StorageService>();
    } catch (e) {
      debugPrint('StorageService not available yet: $e');
      return null;
    }
  }

  PostRepository? get _postRepository {
    try {
      return Get.find<PostRepository>();
    } catch (e) {
      debugPrint('PostRepository not available yet: $e');
      return null;
    }
  }

  // Cache for user posts
  final Map<String, List<PostModel>> _userPostsCache = {};
  final Map<String, DateTime> _lastFetchTime = {};
  final Map<String, bool> _isLoading = {};

  // Cache duration - reduced to be more responsive to changes
  static const Duration _cacheDuration = Duration(minutes: 2);
  static const String _cacheKeyPrefix = 'user_posts_';

  @override
  void onInit() {
    super.onInit();
    // Only load cached posts if services are available
    if (_supabase != null && _storage != null) {
      _loadCachedPosts();
    } else {
      debugPrint(
        'UserPostsCacheService: Services not ready, skipping cache load',
      );
    }
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

      final currentUserId = _supabase?.client.auth.currentUser?.id;
      if (currentUserId != null && _storage != null) {
        final cachedData = _storage!.getString(
          '${_cacheKeyPrefix}$currentUserId',
        );
        if (cachedData != null) {
          final List<dynamic> postsJson = json.decode(cachedData);
          final posts =
              postsJson.map((json) {
                // Safe type casting for cached JSON data
                if (json is Map<String, dynamic>) {
                  return PostModel.fromMap(json);
                } else if (json is Map) {
                  final safeMap = <String, dynamic>{};
                  json.forEach((key, value) {
                    safeMap[key.toString()] = value;
                  });
                  return PostModel.fromMap(safeMap);
                } else {
                  throw Exception('Invalid post data format in cache');
                }
              }).toList();
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

      if (_postRepository == null) {
        debugPrint('PostRepository not available, returning empty list');
        return [];
      }

      final posts = await _postRepository!.getUserPosts(userId);

      // Validate cached posts against database results
      // Remove any cached posts that no longer exist in the database
      final cachedPosts = _userPostsCache[userId];
      if (cachedPosts != null && cachedPosts.isNotEmpty) {
        final databasePostIds = posts.map((p) => p.id).toSet();
        final removedPosts =
            cachedPosts
                .where((cachedPost) => !databasePostIds.contains(cachedPost.id))
                .toList();

        if (removedPosts.isNotEmpty) {
          debugPrint(
            'Found ${removedPosts.length} posts in cache that no longer exist in database',
          );
          for (final removedPost in removedPosts) {
            debugPrint('Removing deleted post from cache: ${removedPost.id}');
          }
        }
      }

      // Update cache with fresh database results
      _userPostsCache[userId] = posts;
      _lastFetchTime[userId] = DateTime.now();

      // Save to local storage for current user
      final currentUserId = _supabase?.client.auth.currentUser?.id;
      if (userId == currentUserId && _storage != null) {
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
      if (_storage == null) {
        debugPrint('StorageService not available, skipping cache save');
        return;
      }

      final postsJson = posts.map((post) => post.toMap()).toList();
      await _storage!.saveString(
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
    final currentUserId = _supabase?.client.auth.currentUser?.id;
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
        final currentUserId = _supabase?.client.auth.currentUser?.id;
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
      final currentUserId = _supabase?.client.auth.currentUser?.id;
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
    _storage?.remove('${_cacheKeyPrefix}$userId');
    debugPrint('Cleared cache for user: $userId');
  }

  /// Invalidate cache for a user (forces next load to fetch from database)
  void invalidateUserCache(String userId) {
    _lastFetchTime.remove(userId);
    debugPrint(
      'Invalidated cache for user: $userId - next load will fetch from database',
    );
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
    final currentUserId = _supabase?.client.auth.currentUser?.id;
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
        final currentUserId = _supabase?.client.auth.currentUser?.id;
        if (userId == currentUserId) {
          _saveCachedPosts(userId, cachedPosts);
        }
      }
    }
  }
}

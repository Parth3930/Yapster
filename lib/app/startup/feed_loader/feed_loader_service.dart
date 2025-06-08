import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/startup/preloader/cache_manager.dart';

class FeedLoaderService {
  // This will hold the preloaded posts
  static List<PostModel> preloadedPosts = [];

  /// Preload the feed and apply the algorithm (placeholder)
  static Future<void> preloadFeed() async {
    try {
      // Always check database first for real-time data
      // Ensure PostRepository is available
      PostRepository postRepository;
      try {
        postRepository = Get.find<PostRepository>();
      } catch (e) {
        debugPrint('PostRepository not available yet, skipping feed preload');
        preloadedPosts = [];
        return;
      }

      final supabaseService = Get.find<SupabaseService>();
      final user = supabaseService.currentUser.value;
      if (user == null) {
        preloadedPosts = [];
        return;
      }

      debugPrint('Loading fresh posts from database for preload');
      final posts = await postRepository.getPostsFeed(
        user.id,
        limit: 30,
        offset: 0,
      );

      // If no posts found in database, clear all cached data and don't use cache
      if (posts.isEmpty) {
        debugPrint('No posts found in database, clearing all cached data');
        preloadedPosts = [];
        await _clearCache();
        return;
      }

      // Only use cached data if database has posts
      if (posts.isNotEmpty) {
        preloadedPosts = _applyFeedAlgorithm(posts);

        // Cache the posts with user data for hot restart
        await _saveToCache();
        debugPrint(
          'Preloaded and cached ${preloadedPosts.length} posts with user data',
        );
      } else {
        // If database is empty, don't use any cached data
        preloadedPosts = [];
        await _clearCache();
      }
    } catch (e) {
      debugPrint('Error preloading feed: $e');
      preloadedPosts = [];
    }
  }

  /// Clear preloaded posts and cache (public method)
  static Future<void> clearPreloadedPosts() async {
    preloadedPosts.clear();
    await _clearCache();
    debugPrint('Cleared preloaded posts and cache');
  }

  /// Placeholder for the feed algorithm
  static List<PostModel> _applyFeedAlgorithm(List<PostModel> posts) {
    // TODO: Implement your custom algorithm here
    // Example: sort by recency, filter by user preferences, etc.
    return posts;
  }

  /// Save preloaded posts to cache
  static Future<void> _saveToCache() async {
    try {
      final cacheManager = Get.find<CacheManager>();

      // Get existing cached data or create new
      final existingData =
          await cacheManager.getCachedHomeData() ?? <String, dynamic>{};

      // Add preloaded posts to cache data
      existingData['preloaded_posts'] =
          preloadedPosts.map((post) => post.toMap()).toList();

      // Save updated cache
      await cacheManager.cacheHomeData(existingData);
      debugPrint('Saved ${preloadedPosts.length} posts to cache');
    } catch (e) {
      debugPrint('Error saving preloaded posts to cache: $e');
    }
  }

  /// Clear all cached data
  static Future<void> _clearCache() async {
    try {
      final cacheManager = Get.find<CacheManager>();
      await cacheManager.clearCache('cached_home_data');
      debugPrint('Cleared all cached feed data');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}

import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class FeedLoaderService {
  // This will hold the preloaded posts
  static List<PostModel> preloadedPosts = [];

  /// Preload the feed and apply the algorithm (placeholder)
  static Future<void> preloadFeed() async {
    try {
      // Ensure PostRepository is available
      PostRepository postRepository;
      try {
        postRepository = Get.find<PostRepository>();
      } catch (e) {
        print('PostRepository not available yet, skipping feed preload');
        preloadedPosts = [];
        return;
      }

      final supabaseService = Get.find<SupabaseService>();
      final user = supabaseService.currentUser.value;
      if (user == null) {
        preloadedPosts = [];
        return;
      }
      final posts = await postRepository.getPostsFeed(
        user.id,
        limit: 30,
        offset: 0,
      );
      preloadedPosts = _applyFeedAlgorithm(posts);
    } catch (e) {
      print('Error preloading feed: $e');
      preloadedPosts = [];
    }
  }

  /// Placeholder for the feed algorithm
  static List<PostModel> _applyFeedAlgorithm(List<PostModel> posts) {
    // TODO: Implement your custom algorithm here
    // Example: sort by recency, filter by user preferences, etc.
    return posts;
  }
}

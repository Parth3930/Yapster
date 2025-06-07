import 'dart:math';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/core/services/user_interaction_service.dart';
import 'package:yapster/app/core/algorithms/post_scoring_algorithm.dart';

/// Service for managing intelligent post feed with deduplication and scoring
class IntelligentFeedService extends GetxService {
  UserInteractionService get _interactionService =>
      Get.find<UserInteractionService>();
  late final PostScoringAlgorithm _scoringAlgorithm;

  // Feed management
  final PriorityQueue<ScoredPost> _postQueue = PriorityQueue<ScoredPost>();
  final Set<String> _seenPostIds = <String>{};
  final List<PostModel> _currentFeed = <PostModel>[];

  // Feed configuration
  static const int _maxFeedSize = 100;
  static const int _batchSize = 20;
  static const double _diversityThreshold = 0.3;

  // Content balancing
  final Map<String, int> _contentTypeCount = {};
  final Map<String, int> _authorCount = {};

  @override
  void onInit() {
    super.onInit();
    _scoringAlgorithm = PostScoringAlgorithm(_interactionService);
  }

  /// Add posts to the intelligent feed system
  Future<void> addPostsToFeed(
    List<PostModel> posts,
    String currentUserId,
  ) async {
    for (final post in posts) {
      // Skip if already seen
      if (_seenPostIds.contains(post.id)) continue;

      // Skip user's own posts
      if (post.userId == currentUserId) continue;

      // Calculate score
      final score = _scoringAlgorithm.calculatePostScore(post, currentUserId);
      final category = _scoringAlgorithm.categorizePost(post);

      // Apply diversity filtering
      if (_shouldIncludeForDiversity(post)) {
        final scoredPost = ScoredPost(
          post: post,
          score: score,
          category: category,
          addedAt: DateTime.now(),
        );

        _postQueue.add(scoredPost);
        _seenPostIds.add(post.id);

        // Update content tracking
        _updateContentTracking(post);
      }
    }

    // Maintain queue size
    _maintainQueueSize();
  }

  /// Get next batch of posts for the feed
  List<PostModel> getNextBatch({int batchSize = _batchSize}) {
    final batch = <PostModel>[];
    final tempQueue = PriorityQueue<ScoredPost>();

    // Extract posts while maintaining diversity
    while (batch.length < batchSize && _postQueue.isNotEmpty) {
      final scoredPost = _postQueue.removeFirst();

      // Check if post still meets criteria
      if (_isPostStillRelevant(scoredPost)) {
        batch.add(scoredPost.post);
        _currentFeed.add(scoredPost.post);
      }
    }

    // Re-add remaining posts
    while (tempQueue.isNotEmpty) {
      _postQueue.add(tempQueue.removeFirst());
    }

    return batch;
  }

  /// Check if post should be included for diversity
  bool _shouldIncludeForDiversity(PostModel post) {
    final currentFeedSize = _currentFeed.length;
    if (currentFeedSize == 0) return true;

    // Check content type diversity
    final contentTypeRatio =
        (_contentTypeCount[post.postType] ?? 0) / currentFeedSize;
    if (contentTypeRatio > _diversityThreshold) {
      return false; // Too much of this content type
    }

    // Check author diversity
    final authorRatio = (_authorCount[post.userId] ?? 0) / currentFeedSize;
    if (authorRatio > _diversityThreshold) {
      return false; // Too much from this author
    }

    return true;
  }

  /// Update content tracking for diversity
  void _updateContentTracking(PostModel post) {
    _contentTypeCount[post.postType] =
        (_contentTypeCount[post.postType] ?? 0) + 1;
    _authorCount[post.userId] = (_authorCount[post.userId] ?? 0) + 1;
  }

  /// Check if post is still relevant
  bool _isPostStillRelevant(ScoredPost scoredPost) {
    final postAge = DateTime.now().difference(scoredPost.post.createdAt);

    // Remove very old posts unless they're viral
    if (postAge.inDays > 7 && scoredPost.category != PostCategory.viral) {
      return false;
    }

    // Remove posts user has already interacted with
    if (_interactionService.hasViewedPost(scoredPost.post.id)) {
      return false;
    }

    return true;
  }

  /// Maintain queue size to prevent memory issues
  void _maintainQueueSize() {
    while (_postQueue.length > _maxFeedSize) {
      final removed = _postQueue.removeFirst();
      _seenPostIds.remove(removed.post.id);
    }
  }

  /// Get feed statistics
  Map<String, dynamic> getFeedStatistics() {
    final categoryCount = <String, int>{};
    final scoreDistribution = <String, int>{};

    for (final scoredPost in _postQueue.toList()) {
      final category = scoredPost.category.displayName;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;

      final scoreRange =
          '${(scoredPost.score / 10).floor() * 10}-${(scoredPost.score / 10).floor() * 10 + 9}';
      scoreDistribution[scoreRange] = (scoreDistribution[scoreRange] ?? 0) + 1;
    }

    return {
      'total_posts': _postQueue.length,
      'seen_posts': _seenPostIds.length,
      'current_feed_size': _currentFeed.length,
      'category_distribution': categoryCount,
      'score_distribution': scoreDistribution,
      'content_type_count': _contentTypeCount,
      'author_count': _authorCount,
    };
  }

  /// Clear old posts from feed
  void clearOldPosts() {
    final now = DateTime.now();
    final postsToRemove = <ScoredPost>[];

    for (final scoredPost in _postQueue.toList()) {
      final postAge = now.difference(scoredPost.post.createdAt);
      final addedAge = now.difference(scoredPost.addedAt);

      // Remove posts older than 7 days or added more than 1 day ago
      if (postAge.inDays > 7 || addedAge.inDays > 1) {
        postsToRemove.add(scoredPost);
      }
    }

    for (final post in postsToRemove) {
      _postQueue.remove(post);
      _seenPostIds.remove(post.post.id);
    }
  }

  /// Reset feed (for refresh)
  void resetFeed() {
    _postQueue.clear();
    _seenPostIds.clear();
    _currentFeed.clear();
    _contentTypeCount.clear();
    _authorCount.clear();
  }

  /// Get recommended posts based on user preferences
  List<PostModel> getRecommendedPosts(
    List<PostModel> candidatePosts,
    String currentUserId, {
    int limit = 10,
  }) {
    final scoredPosts =
        candidatePosts
            .where(
              (post) =>
                  post.userId != currentUserId &&
                  !_interactionService.hasViewedPost(post.id),
            )
            .map(
              (post) => ScoredPost(
                post: post,
                score: _scoringAlgorithm.calculatePostScore(
                  post,
                  currentUserId,
                ),
                category: _scoringAlgorithm.categorizePost(post),
                addedAt: DateTime.now(),
              ),
            )
            .toList();

    // Sort by score descending
    scoredPosts.sort((a, b) => b.score.compareTo(a.score));

    // Apply diversity filtering
    final diversePosts = <PostModel>[];
    final tempContentCount = <String, int>{};
    final tempAuthorCount = <String, int>{};

    for (final scoredPost in scoredPosts) {
      if (diversePosts.length >= limit) break;

      final post = scoredPost.post;
      final contentRatio =
          (tempContentCount[post.postType] ?? 0) / max(diversePosts.length, 1);
      final authorRatio =
          (tempAuthorCount[post.userId] ?? 0) / max(diversePosts.length, 1);

      if (contentRatio <= _diversityThreshold &&
          authorRatio <= _diversityThreshold) {
        diversePosts.add(post);
        tempContentCount[post.postType] =
            (tempContentCount[post.postType] ?? 0) + 1;
        tempAuthorCount[post.userId] = (tempAuthorCount[post.userId] ?? 0) + 1;
      }
    }

    return diversePosts;
  }

  /// Check if feed needs refresh
  bool needsRefresh() {
    return _postQueue.length < _batchSize;
  }
}

/// Scored post for priority queue
class ScoredPost implements Comparable<ScoredPost> {
  final PostModel post;
  final double score;
  final PostCategory category;
  final DateTime addedAt;

  ScoredPost({
    required this.post,
    required this.score,
    required this.category,
    required this.addedAt,
  });

  @override
  int compareTo(ScoredPost other) {
    // Higher scores first
    final scoreComparison = other.score.compareTo(score);
    if (scoreComparison != 0) return scoreComparison;

    // Then by category priority
    final categoryComparison = other.category.priorityMultiplier.compareTo(
      category.priorityMultiplier,
    );
    if (categoryComparison != 0) return categoryComparison;

    // Finally by recency
    return other.post.createdAt.compareTo(post.createdAt);
  }
}

/// Simple priority queue implementation
class PriorityQueue<T extends Comparable<T>> {
  final List<T> _items = [];

  void add(T item) {
    _items.add(item);
    _items.sort();
  }

  T removeFirst() {
    return _items.removeAt(0);
  }

  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  void clear() => _items.clear();

  List<T> toList() => List.from(_items);

  void remove(T item) => _items.remove(item);
}

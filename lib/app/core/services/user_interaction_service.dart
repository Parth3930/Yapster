import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'dart:convert';

import 'package:yapster/app/core/utils/supabase_service.dart';

/// Service for tracking user interactions and learning preferences
class UserInteractionService extends GetxService {
  // Lazy initialization to avoid dependency issues
  SupabaseService? get _supabase {
    try {
      return Get.find<SupabaseService>();
    } catch (e) {
      debugPrint('SupabaseService not available yet: $e');
      return null;
    }
  }

  StorageService get _storage => Get.find<StorageService>();

  // Local cache for user preferences
  final Map<String, dynamic> _userPreferences = {};
  final Map<String, DateTime> _postViewTimes = {};
  final Set<String> _viewedPosts = {};

  // Interaction tracking
  static const String _preferencesKey = 'user_preferences';
  static const String _viewedPostsKey = 'viewed_posts';

  // Cache for batch loaded viewed posts
  DateTime? _lastViewedPostsLoad;
  static const Duration _viewedPostsCacheDuration = Duration(minutes: 10);
  bool _isLoadingViewedPosts = false;

  @override
  void onInit() {
    super.onInit();
    _loadUserPreferences();
    // No longer preloading viewed posts - using feed_queue instead
  }

  /// Load user preferences from local storage
  void _loadUserPreferences() {
    try {
      final prefsData = _storage.getString(_preferencesKey);
      if (prefsData != null) {
        _userPreferences.addAll(
          Map<String, dynamic>.from(json.decode(prefsData)),
        );
      }

      // No longer loading viewed posts from cache - using feed_queue instead
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
    }
  }

  /// Save user preferences to local storage
  Future<void> _saveUserPreferences() async {
    try {
      await _storage.saveString(_preferencesKey, json.encode(_userPreferences));
      // No longer saving viewed posts to cache - using feed_queue instead
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
    }
  }

  /// Track when user views a post
  Future<void> trackPostView(
    String postId,
    String postType,
    String authorId,
  ) async {
    // Don't check cache, just track the view
    _postViewTimes[postId] = DateTime.now();

    // Update view preferences
    _updateContentTypePreference(postType, 0.1);
    _updateAuthorPreference(authorId, 0.05);

    // Track in database
    await _trackInteractionInDatabase(postId, 'view', {
      'post_type': postType,
      'author_id': authorId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Mark post as consumed in feed_queue since user viewed it
    await _markPostConsumedInFeedQueue(postId);

    await _saveUserPreferences();
  }

  /// Track when user likes a post
  Future<void> trackPostLike(
    String postId,
    String postType,
    String authorId,
    bool isLike,
  ) async {
    final weight = isLike ? 0.5 : -0.3;

    _updateContentTypePreference(postType, weight);
    _updateAuthorPreference(authorId, weight);

    // Track the like interaction in the database for the intelligent feed algorithm
    // This works alongside the toggle_post_like function to ensure we have
    // interaction data for recommendations
    if (isLike) {
      await _trackInteractionInDatabase(postId, 'like', {
        'post_type': postType,
        'author_id': authorId,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'liked',
      });
    }

    await _saveUserPreferences();
  }

  /// Track when user comments on a post
  Future<void> trackPostComment(
    String postId,
    String postType,
    String authorId,
  ) async {
    _updateContentTypePreference(postType, 0.8);
    _updateAuthorPreference(authorId, 0.6);

    await _trackInteractionInDatabase(postId, 'comment', {
      'post_type': postType,
      'author_id': authorId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _saveUserPreferences();
  }

  /// Track when user shares a post
  Future<void> trackPostShare(
    String postId,
    String postType,
    String authorId,
  ) async {
    _updateContentTypePreference(postType, 1.0);
    _updateAuthorPreference(authorId, 0.8);

    await _trackInteractionInDatabase(postId, 'share', {
      'post_type': postType,
      'author_id': authorId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _saveUserPreferences();
  }

  /// Track time spent viewing a post
  Future<void> trackTimeSpent(String postId, Duration timeSpent) async {
    if (timeSpent.inSeconds < 2) return; // Ignore very short views

    final startTime = _postViewTimes[postId];
    if (startTime == null) return;

    // Weight based on time spent (more time = higher preference)
    final weight = (timeSpent.inSeconds / 30.0).clamp(0.1, 1.0);

    // Apply weight to content preferences if we have post info
    // This would need post info to be more effective, for now just track

    await _trackInteractionInDatabase(postId, 'time_spent', {
      'duration_seconds': timeSpent.inSeconds,
      'weight': weight,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Update content type preference
  void _updateContentTypePreference(String postType, double weight) {
    final currentWeight = _userPreferences['content_types']?[postType] ?? 0.0;
    _userPreferences['content_types'] ??= {};
    _userPreferences['content_types'][postType] = (currentWeight + weight)
        .clamp(-2.0, 5.0);
  }

  /// Update author preference
  void _updateAuthorPreference(String authorId, double weight) {
    final currentWeight = _userPreferences['authors']?[authorId] ?? 0.0;
    _userPreferences['authors'] ??= {};
    _userPreferences['authors'][authorId] = (currentWeight + weight).clamp(
      -2.0,
      5.0,
    );
  }

  /// Track interaction in database
  Future<void> _trackInteractionInDatabase(
    String postId,
    String interactionType,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint(
          'SupabaseService not available, skipping interaction tracking',
        );
        return;
      }

      final userId = supabase.client.auth.currentUser?.id;
      if (userId == null) return;

      // First check if there's an existing record for this user-post pair
      final existingRecord =
          await supabase.client
              .from('user_interactions')
              .select()
              .eq('user_id', userId)
              .eq('post_id', postId)
              .maybeSingle();

      if (existingRecord != null) {
        // Update existing record by adding the new interaction to the JSON
        Map<String, dynamic> existingMetadata =
            existingRecord['metadata'] is Map
                ? Map<String, dynamic>.from(existingRecord['metadata'])
                : {};

        // Add the new interaction to the existing metadata
        existingMetadata[interactionType] = metadata;
        existingMetadata['last_updated'] = DateTime.now().toIso8601String();

        // Determine the primary interaction type (most recent or most important)
        String primaryInteractionType = _determinePrimaryInteractionType(
          existingMetadata,
        );

        // Update the record with both metadata and interaction_type
        await supabase.client
            .from('user_interactions')
            .update({
              'interaction_type': primaryInteractionType,
              'metadata': existingMetadata,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('post_id', postId);
      } else {
        // Create a new record with this interaction as the first in JSON
        final interactionsJson = {
          interactionType: metadata,
          'created_at': DateTime.now().toIso8601String(),
          'last_updated': DateTime.now().toIso8601String(),
        };

        // Insert new record with both interaction_type and metadata
        await supabase.client.from('user_interactions').insert({
          'user_id': userId,
          'post_id': postId,
          'interaction_type': interactionType,
          'metadata': interactionsJson,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error tracking interaction in database: $e');
    }
  }

  /// Determine the primary interaction type based on importance hierarchy
  String _determinePrimaryInteractionType(Map<String, dynamic> metadata) {
    // Priority order: share > comment > like > view > time_spent
    const priorityOrder = ['share', 'comment', 'like', 'view', 'time_spent'];

    for (final interactionType in priorityOrder) {
      if (metadata.containsKey(interactionType)) {
        return interactionType;
      }
    }

    // Fallback to 'view' if no known interaction types found
    return 'view';
  }

  /// Mark post as consumed in feed_queue table
  Future<void> _markPostConsumedInFeedQueue(String postId) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint('SupabaseService not available, skipping feed_queue update');
        return;
      }

      final userId = supabase.client.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.client
          .from('feed_queue')
          .update({'consumed': true})
          .eq('user_id', userId)
          .eq('post_id', postId);

      debugPrint('Marked post $postId as consumed in feed_queue');
    } catch (e) {
      debugPrint('Error marking post consumed in feed_queue: $e');
    }
  }

  /// Get user preference score for a post type
  double getContentTypePreference(String postType) {
    return _userPreferences['content_types']?[postType] ?? 0.0;
  }

  /// Get user preference score for an author
  double getAuthorPreference(String authorId) {
    return _userPreferences['authors']?[authorId] ?? 0.0;
  }

  /// Check if user has viewed a post - now relies on feed_queue consumed status
  /// This method is deprecated and should not be used for filtering
  @deprecated
  Future<bool> hasViewedPost(String postId) async {
    debugPrint(
      'hasViewedPost is deprecated - use feed_queue consumed status instead',
    );
    return false;
  }

  /// Synchronous version - deprecated, use feed_queue instead
  @deprecated
  bool hasViewedPostSync(String postId) {
    debugPrint(
      'hasViewedPostSync is deprecated - use feed_queue consumed status instead',
    );
    return false;
  }

  /// Batch load viewed posts - deprecated, use feed_queue instead
  @deprecated
  Future<void> _batchLoadViewedPosts() async {
    debugPrint(
      '_batchLoadViewedPosts is deprecated - using feed_queue instead',
    );
  }

  /// Force refresh viewed posts cache - deprecated, use feed_queue instead
  @deprecated
  Future<void> refreshViewedPostsCache() async {
    debugPrint(
      'refreshViewedPostsCache is deprecated - using feed_queue instead',
    );
  }

  /// Get viewed posts count
  int get viewedPostsCount => _viewedPosts.length;

  /// Clear old viewed posts - deprecated, feed_queue handles this automatically
  @deprecated
  Future<void> clearOldViewedPosts() async {
    debugPrint(
      'clearOldViewedPosts is deprecated - feed_queue handles cleanup automatically',
    );
  }

  /// Get user preferences summary with enhanced analytics
  Map<String, dynamic> getUserPreferencesSummary() {
    return {
      'content_types': _userPreferences['content_types'] ?? {},
      'authors': _userPreferences['authors'] ?? {},
      'viewed_posts_count': _viewedPosts.length,
      'interaction_patterns': _getInteractionPatterns(),
      'preference_strength': _calculatePreferenceStrength(),
    };
  }

  /// Get detailed interaction patterns
  Map<String, dynamic> _getInteractionPatterns() {
    // Safe type casting for content types
    Map<String, dynamic> contentTypes = {};
    if (_userPreferences['content_types'] is Map<String, dynamic>) {
      contentTypes = _userPreferences['content_types'] as Map<String, dynamic>;
    } else if (_userPreferences['content_types'] is Map) {
      (_userPreferences['content_types'] as Map).forEach((key, value) {
        contentTypes[key.toString()] = value;
      });
    }

    // Safe type casting for authors
    Map<String, dynamic> authors = {};
    if (_userPreferences['authors'] is Map<String, dynamic>) {
      authors = _userPreferences['authors'] as Map<String, dynamic>;
    } else if (_userPreferences['authors'] is Map) {
      (_userPreferences['authors'] as Map).forEach((key, value) {
        authors[key.toString()] = value;
      });
    }

    // Categorize preferences
    final strongContentPreferences = <String>[];
    final weakContentPreferences = <String>[];
    final dislikedContent = <String>[];

    contentTypes.forEach((type, score) {
      if (score > 2.0) {
        strongContentPreferences.add(type);
      } else if (score > 0.5) {
        weakContentPreferences.add(type);
      } else if (score < -1.0) {
        dislikedContent.add(type);
      }
    });

    final favoriteAuthors = <String>[];
    final dislikedAuthors = <String>[];

    authors.forEach((authorId, score) {
      if (score > 2.0) {
        favoriteAuthors.add(authorId);
      } else if (score < -1.0) {
        dislikedAuthors.add(authorId);
      }
    });

    return {
      'strong_content_preferences': strongContentPreferences,
      'weak_content_preferences': weakContentPreferences,
      'disliked_content': dislikedContent,
      'favorite_authors': favoriteAuthors,
      'disliked_authors': dislikedAuthors,
      'engagement_ratio': _calculateEngagementRatio(),
    };
  }

  /// Calculate overall preference strength
  double _calculatePreferenceStrength() {
    final contentTypes =
        _userPreferences['content_types'] as Map<String, dynamic>? ?? {};
    final authors = _userPreferences['authors'] as Map<String, dynamic>? ?? {};

    double totalContentScore = 0.0;
    double totalAuthorScore = 0.0;

    for (final score in contentTypes.values) {
      totalContentScore += (score as double).abs();
    }

    for (final score in authors.values) {
      totalAuthorScore += (score as double).abs();
    }

    return (totalContentScore + totalAuthorScore) /
        (contentTypes.length + authors.length + 1);
  }

  /// Calculate engagement ratio (likes/comments vs views)
  double _calculateEngagementRatio() {
    // This would be enhanced with actual interaction tracking
    // For now, return a placeholder based on preference strength
    return _calculatePreferenceStrength() / 5.0;
  }

  /// Get content type recommendation score
  double getContentTypeRecommendationScore(String postType) {
    final contentTypes =
        _userPreferences['content_types'] as Map<String, dynamic>? ?? {};
    final score = contentTypes[postType] ?? 0.0;

    // Enhanced scoring with context
    if (score > 3.0) return 1.0; // Strong positive
    if (score > 1.5) return 0.7; // Moderate positive
    if (score > 0.5) return 0.4; // Weak positive
    if (score > -0.5) return 0.0; // Neutral
    if (score > -1.5) return -0.3; // Weak negative
    return -0.7; // Strong negative
  }

  /// Get author recommendation score
  double getAuthorRecommendationScore(String authorId) {
    final authors = _userPreferences['authors'] as Map<String, dynamic>? ?? {};
    final score = authors[authorId] ?? 0.0;

    // Enhanced scoring with context
    if (score > 3.0) return 1.0; // Favorite author
    if (score > 1.5) return 0.8; // Liked author
    if (score > 0.5) return 0.5; // Somewhat liked
    if (score > -0.5) return 0.0; // Neutral
    if (score > -1.5) return -0.4; // Somewhat disliked
    return -0.8; // Disliked author
  }
}

import 'dart:math';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/core/services/user_interaction_service.dart';

/// Algorithm for scoring posts based on engagement and user preferences
class PostScoringAlgorithm {
  final UserInteractionService _interactionService;

  PostScoringAlgorithm(this._interactionService);

  /// Calculate comprehensive score for a post
  double calculatePostScore(PostModel post, String currentUserId) {
    final engagementScore = _calculateEngagementScore(post);
    final viralityScore = _calculateViralityScore(post);
    final freshnessScore = _calculateFreshnessScore(post);
    final personalizedScore = _calculatePersonalizedScore(post, currentUserId);
    final diversityScore = _calculateDiversityScore(post);

    // Weighted combination of all scores
    final totalScore =
        (engagementScore * 0.3 +
            viralityScore * 0.25 +
            freshnessScore * 0.2 +
            personalizedScore * 0.2 +
            diversityScore * 0.05);

    return totalScore.clamp(0.0, 100.0);
  }

  /// Calculate engagement score based on likes, comments, shares, views
  double _calculateEngagementScore(PostModel post) {
    final likes = post.likesCount.toDouble();
    final comments = post.commentsCount.toDouble();
    final shares = post.sharesCount.toDouble();
    final views = post.viewsCount.toDouble();

    // Weighted engagement calculation
    final engagementPoints =
        (likes * 1.0 +
            comments * 3.0 + // Comments are more valuable
            shares * 5.0 + // Shares are most valuable
            views *
                0.1 // Views have minimal weight
                );

    // Normalize based on typical engagement patterns
    final normalizedScore = (engagementPoints / max(views, 1)) * 100;

    return normalizedScore.clamp(0.0, 100.0);
  }

  /// Calculate virality score based on engagement velocity
  double _calculateViralityScore(PostModel post) {
    final now = DateTime.now();
    final postAge = now.difference(post.createdAt);
    final ageInHours = postAge.inHours.toDouble();

    if (ageInHours == 0) return 0.0;

    // Calculate engagement per hour
    final totalEngagement =
        post.likesCount + post.commentsCount + post.sharesCount;
    final engagementVelocity = totalEngagement / ageInHours;

    // Viral threshold calculation
    double viralityMultiplier = 1.0;

    // Recent posts with high engagement velocity get bonus
    if (ageInHours <= 24) {
      viralityMultiplier = 2.0;
    } else if (ageInHours <= 72) {
      viralityMultiplier = 1.5;
    }

    // Calculate virality score
    final viralityScore = engagementVelocity * viralityMultiplier;

    // Normalize to 0-100 scale
    return (viralityScore * 10).clamp(0.0, 100.0);
  }

  /// Calculate freshness score based on post age
  double _calculateFreshnessScore(PostModel post) {
    final now = DateTime.now();
    final postAge = now.difference(post.createdAt);
    final ageInHours = postAge.inHours.toDouble();

    // Freshness decay function
    if (ageInHours <= 1) {
      return 100.0; // Very fresh
    } else if (ageInHours <= 6) {
      return 90.0 - (ageInHours - 1) * 2; // Gradual decay
    } else if (ageInHours <= 24) {
      return 80.0 - (ageInHours - 6) * 2; // Faster decay
    } else if (ageInHours <= 72) {
      return 50.0 - (ageInHours - 24) * 0.5; // Slow decay
    } else {
      return max(10.0, 50.0 - (ageInHours - 72) * 0.1); // Minimum score
    }
  }

  /// Calculate personalized score based on user preferences
  double _calculatePersonalizedScore(PostModel post, String currentUserId) {
    // Don't show user their own posts in recommendations
    if (post.userId == currentUserId) {
      return 0.0;
    }

    double personalizedScore = 50.0; // Base score

    // Content type preference (weighted by interaction quality)
    final contentTypePreference = _interactionService.getContentTypePreference(
      post.postType,
    );
    personalizedScore += contentTypePreference * 12; // Increased weight

    // Author preference (heavily weighted for liked vs viewed)
    final authorPreference = _interactionService.getAuthorPreference(
      post.userId,
    );
    personalizedScore += authorPreference * 20; // Increased weight

    // Enhanced preference scoring based on interaction patterns
    final userPreferences = _interactionService.getUserPreferencesSummary();

    // Boost posts from authors user frequently likes (not just views)
    Map<String, dynamic> authorInteractions = {};
    if (userPreferences['authors'] is Map<String, dynamic>) {
      authorInteractions = userPreferences['authors'] as Map<String, dynamic>;
    } else if (userPreferences['authors'] is Map) {
      (userPreferences['authors'] as Map).forEach((key, value) {
        authorInteractions[key.toString()] = value;
      });
    }
    final authorScore = authorInteractions[post.userId] ?? 0.0;
    if (authorScore > 2.0) {
      personalizedScore += 15.0; // Significant boost for liked authors
    } else if (authorScore > 1.0) {
      personalizedScore += 8.0; // Moderate boost
    } else if (authorScore < -1.0) {
      personalizedScore -= 20.0; // Penalty for disliked authors
    }

    // Content type affinity boost
    Map<String, dynamic> contentTypes = {};
    if (userPreferences['content_types'] is Map<String, dynamic>) {
      contentTypes = userPreferences['content_types'] as Map<String, dynamic>;
    } else if (userPreferences['content_types'] is Map) {
      (userPreferences['content_types'] as Map).forEach((key, value) {
        contentTypes[key.toString()] = value;
      });
    }
    final contentScore = contentTypes[post.postType] ?? 0.0;
    if (contentScore > 2.0) {
      personalizedScore += 12.0; // Strong preference for this content type
    } else if (contentScore > 1.0) {
      personalizedScore += 6.0; // Moderate preference
    } else if (contentScore < -1.0) {
      personalizedScore -= 15.0; // User dislikes this content type
    }

    // Time-based preference (user's active hours)
    final currentHour = DateTime.now().hour;
    if (currentHour >= 18 && currentHour <= 23) {
      personalizedScore += 5.0; // Evening boost (peak social media time)
    } else if (currentHour >= 12 && currentHour <= 14) {
      personalizedScore += 3.0; // Lunch time boost
    }

    // Penalty for already viewed posts
    if (!_interactionService.hasViewedPostSync(post.id)) {
      personalizedScore *= 0.05; // Very heavy penalty for already seen posts
    }

    return personalizedScore.clamp(0.0, 100.0);
  }

  /// Calculate diversity score to ensure feed variety
  double _calculateDiversityScore(PostModel post) {
    // This would be enhanced with more context about recent posts shown
    // For now, give slight preference to different post types

    double diversityScore = 50.0;

    // Boost less common post types
    switch (post.postType) {
      case 'text':
        diversityScore += 5.0;
        break;
      case 'image':
        diversityScore += 0.0; // Neutral
        break;
      case 'gif':
        diversityScore += 10.0; // Boost GIFs
        break;
      case 'sticker':
        diversityScore += 15.0; // Boost stickers
        break;
      default:
        diversityScore += 0.0;
    }

    return diversityScore.clamp(0.0, 100.0);
  }

  /// Determine if a post has viral potential
  bool hasViralPotential(PostModel post) {
    final viralityScore = _calculateViralityScore(post);
    final engagementScore = _calculateEngagementScore(post);

    // A post has viral potential if:
    // 1. High virality score (rapid engagement)
    // 2. Good engagement score
    // 3. Not too old
    final postAge = DateTime.now().difference(post.createdAt);

    return viralityScore > 30.0 &&
        engagementScore > 20.0 &&
        postAge.inHours <= 48;
  }

  /// Calculate engagement rate for a post
  double calculateEngagementRate(PostModel post) {
    final totalEngagement =
        post.likesCount + post.commentsCount + post.sharesCount;
    final views = max(post.viewsCount, 1);

    return (totalEngagement / views) * 100;
  }

  /// Get post category based on engagement metrics
  PostCategory categorizePost(PostModel post) {
    final score = calculatePostScore(post, '');
    final viralPotential = hasViralPotential(post);
    final engagementRate = calculateEngagementRate(post);

    if (viralPotential && score > 70) {
      return PostCategory.viral;
    } else if (score > 60) {
      return PostCategory.trending;
    } else if (engagementRate > 5) {
      return PostCategory.engaging;
    } else if (DateTime.now().difference(post.createdAt).inHours <= 6) {
      return PostCategory.fresh;
    } else {
      return PostCategory.regular;
    }
  }
}

/// Categories for posts based on their characteristics
enum PostCategory {
  viral, // High engagement velocity, trending
  trending, // High overall score
  engaging, // High engagement rate
  fresh, // Recently posted
  regular, // Standard posts
}

/// Extension to get category properties
extension PostCategoryExtension on PostCategory {
  String get displayName {
    switch (this) {
      case PostCategory.viral:
        return 'Viral';
      case PostCategory.trending:
        return 'Trending';
      case PostCategory.engaging:
        return 'Engaging';
      case PostCategory.fresh:
        return 'Fresh';
      case PostCategory.regular:
        return 'Regular';
    }
  }

  double get priorityMultiplier {
    switch (this) {
      case PostCategory.viral:
        return 2.0;
      case PostCategory.trending:
        return 1.5;
      case PostCategory.engaging:
        return 1.3;
      case PostCategory.fresh:
        return 1.1;
      case PostCategory.regular:
        return 1.0;
    }
  }
}

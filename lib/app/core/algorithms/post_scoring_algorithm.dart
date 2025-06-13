import 'dart:math';
import 'package:yapster/app/data/models/post_model.dart';

/// Algorithm for scoring posts based on engagement and user preferences
class PostScoringAlgorithm {
  PostScoringAlgorithm();

  /// Calculate comprehensive score for a post
  double calculatePostScore(PostModel post, String currentUserId) {
    final engagementScore = _calculateEngagementScore(post);
    final viralityScore = _calculateViralityScore(post);
    final freshnessScore = _calculateFreshnessScore(post);
    final personalizedScore = _calculatePersonalizedScore(post, currentUserId);
    final diversityScore = _calculateDiversityScore(post);

    // Weighted combination of all scores (increased weight for engagement and virality)
    final totalScore =
        (engagementScore * 0.4 +
            viralityScore * 0.3 +
            freshnessScore * 0.2 +
            personalizedScore * 0.05 +
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

  /// Calculate personalized score based on basic criteria
  double _calculatePersonalizedScore(PostModel post, String currentUserId) {
    // Don't show user their own posts in recommendations
    if (post.userId == currentUserId) {
      return 0.0;
    }

    double personalizedScore = 50.0; // Base score

    // Time-based preference (user's active hours)
    final currentHour = DateTime.now().hour;
    if (currentHour >= 18 && currentHour <= 23) {
      personalizedScore += 5.0; // Evening boost (peak social media time)
    } else if (currentHour >= 12 && currentHour <= 14) {
      personalizedScore += 3.0; // Lunch time boost
    }

    // Basic content type preferences (simplified without user interaction data)
    switch (post.postType) {
      case 'text':
        personalizedScore += 2.0;
        break;
      case 'image':
        personalizedScore += 5.0; // Images generally more engaging
        break;
      case 'gif':
        personalizedScore += 8.0; // GIFs are popular
        break;
      case 'video':
        personalizedScore += 10.0; // Videos get highest preference
        break;
      default:
        personalizedScore += 0.0;
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

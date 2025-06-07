import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/data/models/post_model.dart';

/// Optimized avatar widget for post headers that handles caching and fallbacks properly
class PostAvatarWidget extends StatelessWidget {
  final PostModel post;
  final double radius;
  final VoidCallback? onTap;

  const PostAvatarWidget({
    super.key,
    required this.post,
    this.radius = 20.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: _buildAvatar());
  }

  Widget _buildAvatar() {
    // Get the best available avatar URL
    final avatarUrl = _getBestAvatarUrl();

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // Remove fade animation and placeholder for instant display
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: null, // No placeholder for instant display
          errorWidget: (context, url, error) => _buildDefaultAvatar(),
          // Use memory cache for better performance
          memCacheWidth: (radius * 2 * 2).toInt(), // 2x for high DPI
          memCacheHeight: (radius * 2 * 2).toInt(),
        ),
      );
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      child: Icon(Icons.person, color: Colors.grey[600], size: radius * 0.8),
    );
  }

  /// Get the best available avatar URL with proper fallback logic
  String? _getBestAvatarUrl() {
    // Debug: Log the current state of user data for this post
    debugPrint(
      'PostAvatar Debug - Post ID: ${post.id}, UserID: ${post.userId}',
    );
    debugPrint('  - avatar: ${post.avatar}');
    debugPrint('  - googleAvatar: ${post.googleAvatar}');
    debugPrint('  - username: ${post.username}');
    debugPrint('  - nickname: ${post.nickname}');

    // First check if we have a regular avatar that's not "skiped" or "null"
    if (post.avatar != null &&
        post.avatar!.isNotEmpty &&
        post.avatar != "skiped" &&
        post.avatar != "null") {
      debugPrint('  - Using regular avatar: ${post.avatar}');
      return post.avatar;
    }

    // SPECIFIC CHECK: If avatar == 'skiped', use google_avatar as fallback
    if (post.avatar == "skiped" ||
        post.avatar == null ||
        post.avatar!.isEmpty) {
      if (post.googleAvatar != null &&
          post.googleAvatar!.isNotEmpty &&
          post.googleAvatar != "skiped" &&
          post.googleAvatar != "null") {
        debugPrint(
          '  - Avatar is skiped/empty, using google avatar: ${post.googleAvatar}',
        );
        return post.googleAvatar;
      }
    }

    // Fallback: try to get google_avatar from metadata
    if (post.metadata.containsKey('google_avatar')) {
      final googleAvatar = post.metadata['google_avatar'];
      if (googleAvatar != null &&
          googleAvatar.toString().isNotEmpty &&
          googleAvatar != "skiped" &&
          googleAvatar != "null") {
        debugPrint('  - Using google avatar from metadata: $googleAvatar');
        return googleAvatar.toString();
      }
    }

    // Try to get google_avatar from profile_data in metadata
    if (post.metadata.containsKey('profile_data')) {
      final profileData = post.metadata['profile_data'];
      if (profileData is Map<String, dynamic> &&
          profileData.containsKey('google_avatar')) {
        final googleAvatar = profileData['google_avatar'];
        if (googleAvatar != null &&
            googleAvatar.toString().isNotEmpty &&
            googleAvatar != "skiped" &&
            googleAvatar != "null") {
          debugPrint(
            '  - Using google avatar from profile_data: $googleAvatar',
          );
          return googleAvatar.toString();
        }
      }
    }

    // No avatar found - this indicates missing user data
    debugPrint('  - NO AVATAR FOUND - falling back to default icon');
    return null;
  }
}

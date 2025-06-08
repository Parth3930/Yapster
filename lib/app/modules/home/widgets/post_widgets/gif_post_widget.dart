import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_avatar_widget.dart';
import 'base_post_widget.dart';

/// Widget for displaying GIF posts
class GifPostWidget extends BasePostWidget {
  const GifPostWidget({
    super.key,
    required super.post,
    required super.controller,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth * 0.95,
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(),
          SizedBox(height: 12),
          buildPostContent(),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text content (if any)
        if (post.content.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              post.content,
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            ),
          ),

        // GIF content
        _buildGifContent(),

        // Post type indicator
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gif, size: 14, color: Colors.purple[300]),
              SizedBox(width: 4),
              Text(
                'GIF Post',
                style: TextStyle(
                  color: Colors.purple[300],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGifContent() {
    final gifUrl = post.gifUrl ?? _getMetadataValue(post.metadata, 'gif_url');

    if (gifUrl == null || gifUrl.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gif, color: Colors.purple[300], size: 48),
            SizedBox(height: 8),
            Text(
              'GIF not available',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showGifFullscreen(gifUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 500, minHeight: 200),
                child: Image.network(
                  gifUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[800],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.purple[300]!,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading GIF...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[800],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.purple[300],
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load GIF',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // GIF indicator overlay
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'GIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Play/Pause overlay (for user interaction)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Engagement bar (glassy) inside the GIF
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: PostInteractionButtons(
                    post: post,
                    controller: controller,
                    glassy: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGifFullscreen(String gifUrl) {
    // TODO: Implement fullscreen GIF viewer with controls
    print('Show fullscreen GIF: $gifUrl');
  }

  Widget _buildPostHeader() {
    return Row(
      children: [
        PostAvatarWidget(
          post: post,
          radius: 20,
          onTap: () => _navigateToProfile(),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(),
                        child: Text(
                          post.username ?? 'Unknown User',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      if (_getMetadataValue(post.metadata, 'verified') == true)
                        Icon(Icons.verified, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      // Only show follow button if this is not the current user's post
                      if (!_isCurrentUserPost())
                        Obx(() {
                          final exploreController =
                              Get.find<ExploreController>();
                          final isFollowing = exploreController.isFollowingUser(
                            post.userId,
                          );

                          // Don't show follow button if already following
                          if (isFollowing) {
                            return SizedBox.shrink();
                          }

                          return TextButton(
                            onPressed: () async {
                              await exploreController.toggleFollowUser(
                                post.userId,
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Follow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                  Text(
                    _formatTimeAgo(post.createdAt),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToProfile() async {
    // Navigate to profile page with user data
    // Ensure ExploreController is available
    ExploreController exploreController;
    try {
      exploreController = Get.find<ExploreController>();
    } catch (e) {
      debugPrint('ExploreController not found, registering it now');
      exploreController = ExploreController();
      Get.put(exploreController);
    }

    // Create user data object for profile loading
    final userData = {
      'user_id': post.userId,
      'username': post.username ?? '',
      'nickname': post.nickname ?? '',
      'avatar': post.avatar ?? '',
    };

    // Use the same method as explore to properly load profile data
    exploreController.openUserProfile(userData);
  }

  bool _isCurrentUserPost() {
    final currentUserId = Get.find<SupabaseService>().currentUser.value?.id;
    return currentUserId != null && currentUserId == post.userId;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  // Helper method to safely access metadata values
  dynamic _getMetadataValue(Map<String, dynamic> metadata, String key) {
    try {
      return metadata[key];
    } catch (e) {
      // If there's any type casting issue, return null
      debugPrint('Error accessing metadata key "$key": $e');
      return null;
    }
  }
}

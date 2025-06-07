import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_avatar_widget.dart';

/// Widget for displaying image posts
class ImagePostWidget extends StatelessWidget {
  const ImagePostWidget({
    super.key,
    required this.post,
    required this.controller,
  });

  final post;
  final controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with overlays
            Stack(
              children: [
                GestureDetector(
                  onTap:
                      () => _showImageFullscreen(context, post.imageUrl ?? ''),
                  child: SizedBox(
                    height: 500,
                    child: Image.network(
                      post.imageUrl ?? '',
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey[600],
                                size: 48,
                              ),
                            ),
                          ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // User info bar (top left)
                Positioned(
                  left: 16,
                  top: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PostAvatarWidget(
                        post: post,
                        radius: 20,
                        onTap: () => _navigateToProfile(),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _navigateToProfile(),
                        child: Text(
                          _getDisplayName(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_getMetadataValue(post.metadata, 'verified') ==
                          true) ...[
                        SizedBox(width: 4),
                        Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
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

                          return GestureDetector(
                            onTap: () async {
                              await exploreController.toggleFollowUser(
                                post.userId,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Follow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      Spacer(),
                      Text(
                        _formatTimeAgo(post.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Post content (bottom, above engagement)
                if (post.content.isNotEmpty)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 60,
                    child: Text(
                      post.content.length > 50
                          ? post.content.substring(0, 50) + '... More'
                          : post.content,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Engagement bar (glassy) inside the image
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
          ],
        ),
      ),
    );
  }

  String _getDisplayName() {
    // Show nickname if available, otherwise show username, fallback to 'Yapper'
    if (post.nickname != null && post.nickname!.isNotEmpty) {
      return post.nickname!;
    } else if (post.username != null && post.username!.isNotEmpty) {
      return post.username!;
    } else {
      return 'Yapper';
    }
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
      return '${difference.inDays} Days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} Hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} Minutes ago';
    } else {
      return 'now';
    }
  }

  void _showImageFullscreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey[600],
                              size: 48,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
    );
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

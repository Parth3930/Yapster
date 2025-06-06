import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'base_post_widget.dart';
import 'post_interaction_buttons.dart';
import 'post_avatar_widget.dart';

/// Widget for displaying text-only posts
class TextPostWidget extends BasePostWidget {
  const TextPostWidget({
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
          // Use the same header as BasePostWidget
          _buildPostHeader(),
          SizedBox(height: 12),
          buildPostContent(),
          SizedBox(height: 12),
          PostInteractionButtons(
            post: post,
            controller: controller,
            glassy: false,
          ),
        ],
      ),
    );
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
                          _getDisplayName(),
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

  @override
  Widget buildPostContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              post.content,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'base_post_widget.dart';

/// Widget for displaying video posts
class VideoPostWidget extends BasePostWidget {
  const VideoPostWidget({
    super.key,
    required super.post,
    required super.controller,
  });

  // Remove the build method override and use the base class implementation
  // The base class already handles the layout properly

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

        // Video content
        _buildVideoContent(),
      ],
    );
  }

  Widget _buildVideoContent() {
    // Check both direct property and metadata for video URL
    String? videoUrl = post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      videoUrl = _getMetadataValue(post.metadata, 'video_url') as String?;
    }

    final thumbnailUrl =
        _getMetadataValue(post.metadata, 'video_thumbnail') as String?;
    final duration =
        _getMetadataValue(post.metadata, 'video_duration') as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.red[300], size: 48),
            SizedBox(height: 8),
            Text(
              'Video not available',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _playVideo(videoUrl!),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Video thumbnail or placeholder
              Container(
                width: double.infinity,
                height: 500,
                color: Colors.grey[800],
                child:
                    thumbnailUrl != null && thumbnailUrl.isNotEmpty
                        ? Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[800],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.red[300]!,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildVideoPlaceholder();
                          },
                        )
                        : _buildVideoPlaceholder(),
              ),

              // Play button overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),

              // Duration indicator
              if (duration != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      duration,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Video quality indicator
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hd, color: Colors.white, size: 12),
                      SizedBox(width: 2),
                      Text(
                        'HD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Engagement bar (glassy) inside the video
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

  Widget _buildVideoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam, color: Colors.red[300], size: 48),
          SizedBox(height: 8),
          Text(
            'Video Preview',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _playVideo(String videoUrl) {
    debugPrint('Play video: $videoUrl');

    // Get all video posts from the feed controller
    final feedController = Get.find<PostsFeedController>();
    final videos =
        feedController.posts
            .where(
              (p) =>
                  p.postType.toLowerCase() == 'video' ||
                  p.videoUrl != null ||
                  p.metadata['video_url'] != null,
            )
            .toList();

    // Find the index of the current video
    int initialIndex = 0;
    for (int i = 0; i < videos.length; i++) {
      final post = videos[i];
      final postVideoUrl =
          post.videoUrl?.isNotEmpty == true
              ? post.videoUrl!
              : post.metadata['video_url'] as String?;

      if (postVideoUrl == videoUrl) {
        initialIndex = i;
        break;
      }
    }

    // Navigate to videos view with the video list and initial index
    Get.toNamed(
      '/videos',
      arguments: {'videos': videos, 'initialIndex': initialIndex},
    );
  }

  // Helper method to safely access metadata values
  dynamic _getMetadataValue(Map<String, dynamic>? metadata, String key) {
    if (metadata == null || metadata.isEmpty) {
      return null;
    }
    try {
      return metadata[key];
    } catch (e) {
      // If there's any type casting issue, return null
      debugPrint('Error accessing metadata key "$key": $e');
      return null;
    }
  }
}

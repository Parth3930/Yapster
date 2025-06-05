import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'base_post_widget.dart';

/// Widget for displaying video posts
class VideoPostWidget extends BasePostWidget {
  const VideoPostWidget({
    super.key,
    required super.post,
    required super.controller,
  });

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

        // Post type indicator
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline, size: 14, color: Colors.red[300]),
              SizedBox(width: 4),
              Text(
                'Video Post',
                style: TextStyle(
                  color: Colors.red[300],
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

  Widget _buildVideoContent() {
    final videoUrl = post.metadata['video_url'] as String?;
    final thumbnailUrl = post.metadata['video_thumbnail'] as String?;
    final duration = post.metadata['video_duration'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
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
      onTap: () => _playVideo(videoUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Video thumbnail or placeholder
              Container(
                width: double.infinity,
                height: 250,
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
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
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
                      color: Colors.black.withOpacity(0.7),
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
                    color: Colors.black.withOpacity(0.7),
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
    // TODO: Implement video player
    // You can use video_player package or chewie for better video controls
    debugPrint('Play video: $videoUrl');

    // For now, show a dialog indicating video would play
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Video Player', style: TextStyle(color: Colors.white)),
        content: Text(
          'Video player would open here.\nURL: $videoUrl',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }
}

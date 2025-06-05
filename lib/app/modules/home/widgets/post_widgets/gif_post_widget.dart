import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'base_post_widget.dart';

/// Widget for displaying GIF posts
class GifPostWidget extends BasePostWidget {
  const GifPostWidget({
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

        // GIF content
        _buildGifContent(),

        // Post type indicator
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
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
    final gifUrl = post.gifUrl ?? post.metadata['gif_url'];

    if (gifUrl == null || gifUrl.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
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
          border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 300, minHeight: 200),
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
                    color: Colors.black.withOpacity(0.7),
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
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white.withOpacity(0.8),
                        size: 24,
                      ),
                    ),
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
}

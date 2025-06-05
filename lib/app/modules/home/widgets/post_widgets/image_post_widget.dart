import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'base_post_widget.dart';

/// Widget for displaying image posts
class ImagePostWidget extends BasePostWidget {
  const ImagePostWidget({
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

        // Image content
        _buildImageContent(),

        // Post type indicator
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image, size: 14, color: Colors.green[300]),
              SizedBox(width: 4),
              Text(
                'Image Post',
                style: TextStyle(
                  color: Colors.green[300],
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

  Widget _buildImageContent() {
    // Check for multiple images in metadata
    final imageUrls = post.metadata['image_urls'] as List?;

    if (imageUrls != null && imageUrls.isNotEmpty) {
      return _buildMultipleImages(imageUrls);
    }

    // Check for single image URL
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return _buildSingleImage(post.imageUrl!);
    }

    return SizedBox.shrink();
  }

  Widget _buildSingleImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showImageFullscreen(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: 400, minHeight: 200),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey[800],
                child: Center(
                  child: CircularProgressIndicator(
                    value:
                        loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
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
                    Icon(Icons.broken_image, color: Colors.grey[600], size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleImages(List imageUrls) {
    if (imageUrls.length == 1) {
      return _buildSingleImage(imageUrls[0]);
    } else if (imageUrls.length == 2) {
      return _buildTwoImages(imageUrls);
    } else if (imageUrls.length >= 3) {
      return _buildThreeOrMoreImages(imageUrls);
    }
    return SizedBox.shrink();
  }

  Widget _buildTwoImages(List imageUrls) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showImageFullscreen(imageUrls[0]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[0],
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: Icon(Icons.broken_image, color: Colors.grey[600]),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            onTap: () => _showImageFullscreen(imageUrls[1]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[1],
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: Icon(Icons.broken_image, color: Colors.grey[600]),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeOrMoreImages(List imageUrls) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showImageFullscreen(imageUrls[0]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrls[0],
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  color: Colors.grey[800],
                  child: Icon(Icons.broken_image, color: Colors.grey[600]),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showImageFullscreen(imageUrls[1]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrls[1],
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () => _showImageGallery(imageUrls, 2),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrls[2],
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            color: Colors.grey[800],
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ),
                    if (imageUrls.length > 3)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+${imageUrls.length - 3}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showImageFullscreen(String imageUrl) {
    // TODO: Implement fullscreen image viewer
    print('Show fullscreen image: $imageUrl');
  }

  void _showImageGallery(List imageUrls, int initialIndex) {
    // TODO: Implement image gallery viewer
    print('Show image gallery starting at index: $initialIndex');
  }
}

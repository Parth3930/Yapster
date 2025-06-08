import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'base_post_widget.dart';

/// Widget for displaying sticker posts
class StickerPostWidget extends BasePostWidget {
  const StickerPostWidget({
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

        // Sticker content
        _buildStickerContent(),

        // Post type indicator
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_emotions, size: 14, color: Colors.orange[300]),
              SizedBox(width: 4),
              Text(
                'Sticker Post',
                style: TextStyle(
                  color: Colors.orange[300],
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

  Widget _buildStickerContent() {
    final stickerUrl =
        post.stickerUrl ?? _getMetadataValue(post.metadata, 'sticker_url');
    final stickerPack =
        _getMetadataValue(post.metadata, 'sticker_pack') as String?;
    final stickerName =
        _getMetadataValue(post.metadata, 'sticker_name') as String?;

    if (stickerUrl == null || stickerUrl.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              color: Colors.orange[300],
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Sticker not available',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showStickerDetails(stickerUrl, stickerPack, stickerName),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 200,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.withOpacity(0.1),
                      Colors.yellow.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Image.network(
                    stickerUrl,
                    fit: BoxFit.contain,
                    height: 120,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 120,
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
                                Colors.orange[300]!,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Loading sticker...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.orange[300],
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load sticker',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Sticker pack info
              if (stickerPack != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stickerPack,
                      style: TextStyle(
                        color: Colors.orange[300],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Sticker name
              if (stickerName != null)
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
                      stickerName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Tap indicator
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.touch_app,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
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

  void _showStickerDetails(
    String stickerUrl,
    String? stickerPack,
    String? stickerName,
  ) {
    // TODO: Implement sticker details view or sticker pack browser
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.emoji_emotions, color: Colors.orange[300]),
            SizedBox(width: 8),
            Text('Sticker Details', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stickerName != null) ...[
              Text(
                'Name: $stickerName',
                style: TextStyle(color: Colors.grey[300]),
              ),
              SizedBox(height: 8),
            ],
            if (stickerPack != null) ...[
              Text(
                'Pack: $stickerPack',
                style: TextStyle(color: Colors.grey[300]),
              ),
              SizedBox(height: 8),
            ],
            Text(
              'URL: $stickerUrl',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: Colors.orange[300])),
          ),
        ],
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

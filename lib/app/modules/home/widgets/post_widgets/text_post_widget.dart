import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'base_post_widget.dart';

/// Widget for displaying text-only posts
class TextPostWidget extends BasePostWidget {
  const TextPostWidget({
    super.key,
    required super.post,
    required super.controller,
  });

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
                fontSize: 16,
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
          ),

        // Show post type indicator for text posts
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.text_fields, size: 14, color: Colors.blue[300]),
              SizedBox(width: 4),
              Text(
                'Text Post',
                style: TextStyle(
                  color: Colors.blue[300],
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
}

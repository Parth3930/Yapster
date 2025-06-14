import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'package:yapster/app/global_widgets/video_thumbnail_auto_saver.dart';

/// Widget for displaying activity-based posts (liked, commented, favorited)
/// This is separate from the profile posts grid to avoid conflicts
class ActivityPostsGrid extends StatelessWidget {
  final List<PostModel> posts;
  final bool isLoading;
  final String emptyStateTitle;
  final String emptyStateSubtitle;
  final IconData emptyStateIcon;

  const ActivityPostsGrid({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.emptyStateTitle,
    required this.emptyStateSubtitle,
    required this.emptyStateIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Show loading indicator
    if (isLoading && posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    // Show empty state
    if (posts.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyStateIcon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyStateTitle,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              emptyStateSubtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Show posts in a Pinterest-like masonry layout
    return MasonryGridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: posts.length,
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemBuilder: (context, index) {
        final post = posts[index];

        // Determine aspect ratio for the post card to achieve masonry effect
        double aspectRatio;
        if (post.postType.toLowerCase() == 'image' ||
            post.postType.toLowerCase() == 'video') {
          // Use a set of predefined aspect ratios and cycle through for visual variety
          const ratios = [0.8, 1.0, 1.25, 1.5];
          aspectRatio = ratios[index % ratios.length];
        } else {
          // Text posts: scale height with content length for visual balance
          final textLength = post.content.length;
          if (textLength > 120) {
            aspectRatio = 1.4;
          } else if (textLength > 60) {
            aspectRatio = 1.1;
          } else {
            aspectRatio = 0.9;
          }
        }

        return Card(
          color: const Color(0xFF242424),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1 / aspectRatio, // width : height ratio
            child: GestureDetector(
              onTap: () {
                // Navigate to post detail page
                Get.toNamed(
                  '${Routes.POST_DETAIL}/${post.id}',
                  arguments: {'post': post},
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (post.postType.toLowerCase() == 'image' &&
                      post.imageUrl != null)
                    Image.network(post.imageUrl!, fit: BoxFit.cover)
                  else if (post.postType.toLowerCase() == 'video')
                    (() {
                      final thumb = post.metadata['video_thumbnail'] as String?;
                      if (thumb != null && thumb.isNotEmpty) {
                        return Image.network(thumb, fit: BoxFit.cover);
                      }
                      // Generate thumbnail, upload and cache automatically
                      return VideoThumbnailAutoSaver(post: post);
                    })()
                  else
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        post.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  // Add a subtle overlay to indicate this is not the user's own post
                  Container(
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
                  ),
                  // Show post author info in bottom corner
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        // Author avatar
                        CircleAvatar(
                          radius: 12,
                          backgroundImage:
                              post.avatar != null
                                  ? NetworkImage(post.avatar!)
                                  : post.googleAvatar != null
                                  ? NetworkImage(post.googleAvatar!)
                                  : null,
                          backgroundColor: Colors.grey[600],
                          child:
                              (post.avatar == null && post.googleAvatar == null)
                                  ? Text(
                                    post.username != null &&
                                            post.username!.isNotEmpty
                                        ? post.username![0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 6),
                        // Author username
                        Expanded(
                          child: Text(
                            '@${post.username}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

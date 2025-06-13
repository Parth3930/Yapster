import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'package:yapster/app/modules/profile/controllers/profile_posts_controller.dart';
import 'package:yapster/app/global_widgets/video_thumbnail_auto_saver.dart';

Widget buildVideosTab() {
  // Find the ProfilePostsController to get posts
  ProfilePostsController? profilePostsController;
  try {
    profilePostsController = Get.find<ProfilePostsController>(
      tag: 'profile_posts_${Get.parameters['id'] ?? 'current'}',
    );
  } catch (e) {
    // If controller not found, fallback to empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 64, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'No videos yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Wrap the UI in Obx so that it rebuilds when the reactive list changes
  return Obx(() {
    final videoPosts =
        profilePostsController!.profilePosts
            .where((post) => post.postType.toLowerCase() == 'video')
            .toList();

    // Loading indicator while fetching videos
    if (profilePostsController.isLoading.value && videoPosts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (videoPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              'No videos yet',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Show videos in a Pinterest-like masonry layout
    return MasonryGridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: videoPosts.length,
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemBuilder: (context, index) {
        final post = videoPosts[index];

        // Calculate a variable height for videos
        // Videos typically have different aspect ratios
        final aspectRatio = [0.8, 1.0, 1.3, 1.1, 0.9][index % 5];

        return SizedBox(
          height: max(200, 210 * aspectRatio),
          child: Card(
            color: const Color(0xFF242424),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                // Navigate to post detail page when tapped
                Get.toNamed(
                  '${Routes.POST_DETAIL}/${post.id}',
                  arguments: {'post': post},
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video thumbnail/preview
                  (() {
                    final thumb = post.metadata['video_thumbnail'] as String?;
                    if (thumb != null && thumb.isNotEmpty) {
                      return Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.movie,
                              size: 40,
                              color: Colors.grey,
                            ),
                      );
                    }
                    // If no cached thumbnail, generate/upload/cache automatically
                    return VideoThumbnailAutoSaver(post: post);
                  })(),
                ],
              ),
            ),
          ),
        );
      },
    );
  });
}

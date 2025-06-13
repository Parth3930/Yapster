import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/videos_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/videos/views/videos_player_view.dart';

class VideosView extends GetView<VideosController> {
  const VideosView({super.key});

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      period: const Duration(milliseconds: 800),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 20),
            Container(width: 200, height: 15, color: Colors.white),
            const SizedBox(height: 12),
            Container(width: 150, height: 15, color: Colors.white),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get initial index from arguments if provided
    final initialIndex = Get.arguments?['initialIndex'] as int? ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          GetX<PostsFeedController>(
            init: PostsFeedController(),
            builder: (feedCtrl) {
              final videos =
                  feedCtrl.posts
                      .where((p) => p.postType.toLowerCase() == 'video')
                      .toList();

              if (feedCtrl.isLoading.value && videos.isEmpty) {
                return _buildShimmerLoading();
              }

              if (videos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No videos yet',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              // Navigate to the video player with the videos list
              Get.toNamed('/videos', arguments: {
                'videos': videos,
                'initialIndex': initialIndex,
              });
              return const SizedBox.shrink();
            },
          ),

          // Custom header with gradient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 4,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                  const Expanded(
                    child: Text(
                      'Yap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Implement star functionality
                      if (controller.currentVideo.value != null) {
                        controller.toggleVideoFavorite(
                          controller.currentVideo.value!.id,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        controller
                                    .currentVideo
                                    .value
                                    ?.metadata['isFavorited'] ==
                                true
                            ? 'assets/postIcons/star_selected.png'
                            : 'assets/postIcons/star.png',
                        width: 28,
                        height: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      floatingActionButton: const BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

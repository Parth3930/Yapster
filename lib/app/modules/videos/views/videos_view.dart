import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/videos_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/videos/views/videos_player_view.dart';

class VideosView extends GetView<VideosController> {
  const VideosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Videos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: GetX<PostsFeedController>(
        init: PostsFeedController(),
        builder: (feedCtrl) {
          final videos =
              feedCtrl.posts
                  .where((p) => p.postType.toLowerCase() == 'video')
                  .toList();

          if (feedCtrl.isLoading.value && videos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No videos yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // Directly show full-screen swipeable video feed
          return VideosPlayerView(videos: videos);
        },
      ),
      extendBody: true,
      floatingActionButton: const BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

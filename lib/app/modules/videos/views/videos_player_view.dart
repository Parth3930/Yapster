import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/videos/controllers/videos_player_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_comment_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_share_dialog.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/comment_dialog.dart';

/// Full-screen vertical video feed similar to Instagram Reels / TikTok
class VideosPlayerView extends GetView<VideosPlayerController> {
  const VideosPlayerView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: controller.videos.length,
        onPageChanged: controller.onPageChanged,
        itemBuilder: (context, index) {
          final post = controller.videos[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // Video content
              Obx(() {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!controller.isInitialized) {
                  return const Center(child: Text('Video not available'));
                }

                return GestureDetector(
                  onTap: controller.togglePlayPause,
                  child: AspectRatio(
                    aspectRatio:
                        controller.videoController?.value.aspectRatio ?? 9 / 16,
                    child: VideoPlayer(controller.videoController!),
                  ),
                );
              }),

              // Video Controls Overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: controller.togglePlayPause,
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        // Play/Pause Icon
                        Obx(
                          () =>
                              controller.isPlaying
                                  ? const SizedBox.shrink()
                                  : const Center(
                                    child: Icon(
                                      Icons.play_arrow,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),

                        // Mute Button
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: IconButton(
                            icon: Icon(
                              controller.isMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: Colors.white,
                            ),
                            onPressed: controller.toggleMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // User Info Overlay
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username and Follow Button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Get.toNamed('/profile/${post.userId}'),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(
                                  post.avatar == 'skiped'
                                      ? post.googleAvatar ?? ''
                                      : post.avatar ?? '',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                post.username ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Obx(() {
                          final isCurrentUser =
                              controller.currentUserId == post.userId;
                          if (!isCurrentUser &&
                              !controller.isFollowing(post.userId)) {
                            return Container(
                              height: 32,
                              child: ElevatedButton(
                                onPressed:
                                    () => controller.followUser(post.userId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Follow',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Content
                    if (post.content.isNotEmpty)
                      Text(
                        post.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Time ago
                    Text(
                      controller.getTimeAgo(post.createdAt),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmer(String? thumb) {
    return thumb != null && thumb.isNotEmpty
        ? Image.network(
          thumb,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (_, _, __) => _placeholder(),
        )
        : _placeholder();
  }

  Widget _placeholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(color: Colors.grey.shade800),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/create_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PostCreateView extends GetView<CreateController> {
  const PostCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    // Get arguments
    final Map<String, dynamic> args = Get.arguments;
    final List<File> images = args['selectedImages'] as List<File>? ?? [];
    final String? videoPath = args['videoPath'] as String?;

    // Create a local RxBool for the global toggle
    final RxBool isGlobalPost = false.obs;

    // Set up video player if video is provided
    VideoPlayerController? videoController;
    if (videoPath != null) {
      videoController = VideoPlayerController.file(File(videoPath))
        ..initialize().then((_) {
          videoController?.setLooping(true);
          videoController?.play();
        });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          controller.username.value,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(
            () => TextButton(
              onPressed:
                  controller.isLoading.value
                      ? null
                      : () {
                        // Create post with global setting from the toggle
                        controller.createPost(isGlobal: isGlobalPost.value);
                        Get.until((route) => route.settings.name == '/home');
                      },
              child: const Text(
                'Post',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(
        () =>
            controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Media preview
                    if (images.isNotEmpty)
                      SizedBox(
                        height:
                            MediaQuery.of(context).size.width *
                            5 /
                            4, // 4:5 ratio
                        width: MediaQuery.of(context).size.width,
                        child: Image.file(images.first, fit: BoxFit.cover),
                      )
                    else if (videoPath != null && videoController != null)
                      Container(
                        height:
                            MediaQuery.of(context).size.width *
                            16 /
                            9, // 16:9 ratio for videos
                        width: MediaQuery.of(context).size.width,
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: videoController.value.aspectRatio,
                            child: VideoPlayer(videoController),
                          ),
                        ),
                      ),

                    // Caption input
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: controller.postTextController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        maxLines: 5,
                        minLines: 1,
                      ),
                    ),

                    // Global switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Global Post',
                            style: TextStyle(color: Colors.white),
                          ),
                          Obx(
                            () => Switch(
                              value: isGlobalPost.value,
                              onChanged: (value) {
                                isGlobalPost.value = value;
                              },
                              activeColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up when done
    controller.postTextController.clear();
    controller.selectedImages.clear();
  }
}

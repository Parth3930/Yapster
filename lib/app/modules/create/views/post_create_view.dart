import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/post_create_controller.dart';
import 'package:video_player/video_player.dart';

class PostCreateView extends GetView<PostCreateController> {
  const PostCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          controller.createController.username.value,
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
                      : () => controller.createPost(),
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
                    Obx(() {
                      if (controller.selectedImages.isNotEmpty) {
                        return SizedBox(
                          height:
                              MediaQuery.of(context).size.width *
                              5 /
                              4, // 4:5 ratio
                          width: MediaQuery.of(context).size.width,
                          child: Image.file(
                            controller.selectedImages.first,
                            fit: BoxFit.cover,
                          ),
                        );
                      } else if (controller.videoPath.isNotEmpty &&
                          controller.videoController != null) {
                        return Container(
                          height:
                              MediaQuery.of(context).size.width *
                              16 /
                              9, // 16:9 ratio for videos
                          width: MediaQuery.of(context).size.width,
                          color: Colors.black,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio:
                                  controller.videoController!.value.aspectRatio,
                              child: VideoPlayer(controller.videoController!),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox();
                      }
                    }),

                    // Caption input
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller:
                            controller.createController.postTextController,
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
                              value: controller.isGlobalPost.value,
                              onChanged:
                                  (value) => controller.toggleGlobalPost(value),
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
}

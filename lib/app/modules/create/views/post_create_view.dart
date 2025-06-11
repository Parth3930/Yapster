import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../controllers/post_create_controller.dart';
import 'package:video_player/video_player.dart';

class PostCreateView extends GetView<PostCreateController> {
  const PostCreateView({super.key});

  AccountDataProvider get accountDataProvider =>
      Get.find<AccountDataProvider>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          // cross icon
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(
        () =>
            controller.isLoading.value
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Creating post...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Please wait',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
                : SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 15),
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(
                              AvatarUtils.getAvatarUrl(
                                isCurrentUser: true,
                                accountDataProvider: accountDataProvider,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.createController.username.value,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: GoogleFonts.dongle().fontFamily,
                                  fontSize: 35,
                                  height: 0.9, // Reduce line height
                                ),
                              ),
                              Obx(() {
                                final isPublic =
                                    controller.createController.isPublic.value;
                                return GestureDetector(
                                  onTap: () {
                                    controller.createController
                                        .toggleIsPublic();
                                  },
                                  child: Container(
                                    width: 80,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color:
                                          isPublic
                                              ? Colors.blue.withOpacity(0.3)
                                              : Color(0xff1F1F1F),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isPublic
                                                ? Icons.public
                                                : Icons.lock,
                                            color: Colors.white,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isPublic ? "Public" : "Private",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          const Spacer(),
                          // Post button
                          Obx(
                            () => Container(
                              height: 40,
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.blue,
                              ),
                              child: TextButton(
                                onPressed:
                                    controller.isLoading.value
                                        ? null
                                        : () => controller.createPost(),
                                child: const Text(
                                  'Post',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Video preview
                      Obx(() {
                        if (controller.selectedImages.isNotEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Container(
                              height: 400,
                              width: double.infinity,
                              decoration: BoxDecoration(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  controller.selectedImages.first,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        } else if (controller.videoPath.isNotEmpty &&
                            controller.videoController != null) {
                          return Container(
                            height: MediaQuery.of(context).size.width * 16 / 9,
                            width: MediaQuery.of(context).size.width,
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio:
                                    controller
                                        .videoController!
                                        .value
                                        .aspectRatio,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 15, // Increased vertical padding
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller:
                                controller.createController.postTextController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Add a caption...',
                              hintStyle: TextStyle(color: Color(0xffC1C1C1)),
                              border: InputBorder.none,
                              counterStyle: TextStyle(color: Colors.white70),
                              contentPadding: EdgeInsets.zero,
                            ),
                            maxLines: null, // Allow unlimited lines
                            minLines: 3, // Start with 3 lines
                            maxLength: 200, // Limit caption to 200 characters
                            textInputAction:
                                TextInputAction.newline, // Allow multiple lines
                          ),
                        ),
                      ),

                      // Global switch

                      // Add padding at the bottom for keyboard
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom + 50,
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

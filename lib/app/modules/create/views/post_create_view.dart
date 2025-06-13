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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: controller.progress.value,
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              minHeight: 8,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              controller.processingMessage.value,
                              style: TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
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
                                      controller
                                          .createController
                                          .username
                                          .value,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily:
                                            GoogleFonts.dongle().fontFamily,
                                        fontSize: 35,
                                        height: 0.9, // Reduce line height
                                      ),
                                    ),
                                    Obx(() {
                                      final isPublic =
                                          controller
                                              .createController
                                              .isPublic
                                              .value;
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
                                                    ? Colors.blue
                                                    : Color(0xff1F1F1F),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                                  isPublic
                                                      ? "Public"
                                                      : "Private",
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
                            // Video preview
                            Obx(() {
                              if (controller.selectedImages.isNotEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 15,
                                  ),
                                  child: Container(
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
                                  controller.videoController != null &&
                                  controller.videoInitialized.value) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 20, // space above video
                                    left: 15,
                                    right: 15,
                                    bottom: 15,
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      // Ensure video takes at most 60% of height so UI doesn't stretch on error
                                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                                    ),
                                    width: double.infinity,
                                    decoration: const BoxDecoration(),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: AspectRatio(
                                        aspectRatio: controller
                                            .videoController!.value.aspectRatio,
                                        child: VideoPlayer(
                                          controller.videoController!,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } else if (controller.videoPath.isNotEmpty && !controller.videoInitialized.value) {
                                // Video controller still initializing
                                return const Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              } else if (controller.videoPath.isNotEmpty) {
                                // Failed / not initialized
                                return const SizedBox();
                              } else if (controller.isLoading.value) {
                                // When posting fails and isLoading false, don't expand
                                return const SizedBox();
                              } else {
                                return const SizedBox();
                              }
                            }),

                            // Caption input
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
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
                                      controller
                                          .createController
                                          .postTextController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Add a caption...',
                                    hintStyle: TextStyle(
                                      color: Color(0xffC1C1C1),
                                    ),
                                    border: InputBorder.none,
                                    counterStyle: TextStyle(
                                      color: Colors.white70,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  maxLines: null, // Allow unlimited lines
                                  minLines: 3, // Start with 3 lines
                                  maxLength:
                                      200, // Limit caption to 200 characters
                                  textInputAction:
                                      TextInputAction
                                          .newline, // Allow multiple lines
                                ),
                              ),
                            ),

                            // Global switch

                            // Add padding at the bottom for keyboard
                            SizedBox(
                              height:
                                  MediaQuery.of(context).viewInsets.bottom + 50,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

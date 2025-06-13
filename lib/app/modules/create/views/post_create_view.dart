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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: _handleBackPress,
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
                              Obx(
                                () => LinearProgressIndicator(
                                  value: controller.progress.value,
                                  backgroundColor: Colors.grey[800],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.blue,
                                      ),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Obx(
                                () => Text(
                                  controller.processingMessage.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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
                                        accountDataProvider:
                                            accountDataProvider,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          height: 0.9,
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
                                                      : const Color(0xff1F1F1F),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                : _handleCreatePost,
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
                              // Media preview
                              Obx(() {
                                if (controller.selectedImages.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 15,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: const BoxDecoration(),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(
                                          controller.selectedImages.first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              height: 200,
                                              color: Colors.grey[800],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.error_outline,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (controller.videoPath.isNotEmpty &&
                                    controller.videoController != null &&
                                    controller.videoInitialized.value) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 20,
                                      left: 15,
                                      right: 15,
                                      bottom: 15,
                                    ),
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                            0.6,
                                      ),
                                      width: double.infinity,
                                      decoration: const BoxDecoration(),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: _buildVideoPlayer(),
                                      ),
                                    ),
                                  );
                                } else if (controller.videoPath.isNotEmpty &&
                                    !controller.videoInitialized.value) {
                                  return _buildVideoLoadingIndicator();
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Focus(
                                    onFocusChange: _handleFocusChange,
                                    child: TextField(
                                      controller:
                                          controller
                                              .createController
                                              .postTextController,
                                      focusNode: controller.textFocusNode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
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
                                      maxLines: null,
                                      minLines: 3,
                                      maxLength: 200,
                                      textInputAction: TextInputAction.newline,
                                      keyboardType: TextInputType.multiline,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                    ),
                                  ),
                                ),
                              ),
                              // Bottom padding for keyboard
                              SizedBox(
                                height:
                                    MediaQuery.of(context).viewInsets.bottom +
                                    50,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  // Helper methods for better organization and error handling
  Future<void> _handleBackPress() async {
    try {
      // Show loading indicator briefly to prevent multiple taps
      if (controller.isLoading.value) {
        Get.snackbar(
          'Please wait',
          'Post is being created...',
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 1),
        );
        return;
      }

      // Clean up video resources safely
      if (controller.videoController != null) {
        try {
          await controller.videoController!.pause();
        } catch (e) {
          debugPrint('Error pausing video on back: $e');
        }
      }

      Get.back();
    } catch (e) {
      debugPrint('Error handling back press: $e');
      Get.back(); // Fallback navigation
    }
  }

  Future<void> _handleCreatePost() async {
    try {
      await controller.createPost();
    } catch (e) {
      debugPrint('Error in create post handler: $e');
      Get.snackbar(
        'Error',
        'Failed to create post. Please try again.',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _handleFocusChange(bool hasFocus) {
    try {
      controller.isTextFieldFocused.value = hasFocus;
      // Video pause/resume is handled by the controller's focus listener
    } catch (e) {
      debugPrint('Error handling focus change: $e');
    }
  }

  Widget _buildVideoPlayer() {
    return Obx(() {
      final videoController = controller.videoController;

      if (videoController == null || !videoController.value.isInitialized) {
        return Container(
          height: 300,
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator()),
        );
      }

      return AspectRatio(
        aspectRatio: videoController.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(videoController),
            // Show pause overlay when typing
            if (controller.isTextFieldFocused.value)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Icon(
                    Icons.pause_circle_outline,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            // Show error overlay if video has error
            if (videoController.value.hasError)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Video Error',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildVideoLoadingIndicator() {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(top: 40),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

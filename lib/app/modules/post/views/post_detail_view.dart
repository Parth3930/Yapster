import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/post/controllers/post_detail_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_widget_factory.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/enhanced_comment_widget.dart';

class PostDetailView extends GetView<PostDetailController> {
  const PostDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return _PostDetailViewState();
  }
}

class _PostDetailViewState extends StatefulWidget {
  @override
  State<_PostDetailViewState> createState() => __PostDetailViewStateState();
}

class __PostDetailViewStateState extends State<_PostDetailViewState> {
  final PostDetailController controller = Get.find<PostDetailController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        if (controller.post.value == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  'Post not found',
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'This post may have been deleted or is no longer available.',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // Main post
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PostWidgetFactory.createPostWidget(
                  post: controller.post.value!,
                  controller: controller.feedController,
                ),
              ),

              // Comments section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comments header
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Comments list
                    Obx(() {
                      if (controller.commentController.isLoading.value) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                        );
                      }

                      if (controller.commentController.comments.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: const Center(
                            child: Text(
                              'No comments yet. Be the first to comment!',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.commentController.comments.length,
                        itemBuilder: (context, index) {
                          final comment =
                              controller.commentController.comments[index];
                          return EnhancedCommentWidget(
                            comment: comment,
                            controller: controller.commentController,
                          );
                        },
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

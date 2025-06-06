import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/story_viewer_controller.dart';

class StoryViewerView extends GetView<StoryViewerController> {
  const StoryViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (controller.stories.isEmpty) {
          return const Center(
            child: Text(
              'No stories available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        final currentStory = controller.currentStory;
        if (currentStory == null) {
          return const Center(
            child: Text(
              'Story not found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return Stack(
          children: [
            // Background image
            if (currentStory.imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  currentStory.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(color: Colors.grey[900]),

            // Text elements
            ...currentStory.textItems.asMap().entries.map((entry) {
              return Positioned(
                left: entry.value.position.dx,
                top: entry.value.position.dy,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: entry.value.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value.text,
                    style: TextStyle(
                      color: entry.value.color,
                      fontSize: entry.value.fontSize,
                      fontWeight: entry.value.fontWeight,
                    ),
                    textAlign: entry.value.textAlign,
                  ),
                ),
              );
            }),

            // Progress indicators
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  controller.stories.length,
                  (index) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color:
                            index <= controller.currentStoryIndex.value
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // User info header
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        controller.userAvatar.value != null
                            ? NetworkImage(controller.userAvatar.value)
                            : null,
                    child:
                        controller.userAvatar.value == null
                            ? const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.white,
                            )
                            : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.username.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          controller.getTimeAgo(currentStory.createdAt),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),

            // Tap areas for navigation
            Row(
              children: [
                // Previous story
                Expanded(
                  child: GestureDetector(
                    onTap: controller.previousStory,
                    child: Container(
                      color: Colors.transparent,
                      height: double.infinity,
                    ),
                  ),
                ),
                // Next story
                Expanded(
                  child: GestureDetector(
                    onTap: controller.nextStory,
                    child: Container(
                      color: Colors.transparent,
                      height: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

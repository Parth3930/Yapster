import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/stories_controller.dart';
import 'package:yapster/app/modules/stories/controllers/doodle_controller.dart';
import 'package:yapster/app/modules/stories/controllers/text_controller.dart';
import 'package:yapster/app/modules/stories/widgets/doodle_widget.dart';
import 'package:yapster/app/modules/stories/widgets/text_widget.dart';
import 'package:yapster/app/modules/stories/widgets/text_editing_controls.dart';

enum DrawingMode { none, text, doodle }

class CreateStoryView extends GetView<StoriesController> {
  CreateStoryView({super.key});

  final TextController _textController = Get.find<TextController>();
  final StoriesController _storiesController = Get.find<StoriesController>();

  @override
  Widget build(BuildContext context) {
    // Initialize controllers if not already registered
    if (!Get.isRegistered<DoodleController>()) {
      Get.put(DoodleController());
    }
    if (!Get.isRegistered<TextController>()) {
      Get.put(TextController());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Create Story',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Finish editing if currently editing
              if (_textController.isEditing.value) {
                _textController.finishEditing();
              }
              // Post the story
              controller.postStory();
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
        ],
      ),

      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return GestureDetector(
          onTap: () {
            // Deselect any selected text when tapping on empty area
            if (_textController.selectedTextIndex.value != -1) {
              _textController.finishEditing();
              _textController.selectedTextIndex.value = -1;
              controller.drawingMode.value = DrawingMode.none;
              controller.isEditingText.value = false;
            }
          },
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(color: Colors.black),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (controller.selectedImage.value != null)
                  Positioned.fill(
                    child: Image.file(
                      controller.selectedImage.value!,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_textController.textItems.isEmpty &&
                    Get.find<DoodleController>().drawingPoints.isEmpty)
                  const Center(
                    child: Text(
                      "Select an image",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),

                // Doodle widget when in doodle mode
                if (_storiesController.drawingMode.value == DrawingMode.doodle)
                  DoodleWidget(),

                // Text widgets
                ..._textController.textItems.asMap().entries.map((entry) {
                  return TextWidget(
                    textItem: entry.value,
                    index: entry.key,
                    onDragEnd: (newPosition) {
                      _textController.updateTextPosition(
                        entry.key,
                        newPosition,
                      );
                    },
                    onTap: () {
                      _textController.selectedTextIndex.value = entry.key;
                    },
                  );
                }),

                // Text input field (hidden, used for keyboard input)
                Positioned(
                  left: -1000,
                  child: SizedBox(
                    width: 200, // Provide a finite width
                    child: TextField(
                      controller: _textController.textEditingController,
                      focusNode: _textController.focusNode,
                      maxLines: null, // Allow multiple lines
                      keyboardType: TextInputType.multiline,
                      textInputAction:
                          TextInputAction.newline, // Allow new line with enter
                      style: const TextStyle(
                        color: Colors.transparent,
                        height: 0.1,
                        fontSize: 1,
                      ),
                      onChanged: (value) {
                        _textController.updateText(value);
                      },
                      onSubmitted: (_) {
                        // Don't stop editing on submit for multiline
                        // User can tap outside or use controls to finish editing
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                // Recent gallery images preview
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount:
                          _storiesController.recentMedia.length +
                          2, // +2 for camera and gallery icons
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Camera icon
                          return GestureDetector(
                            onTap: () async {
                              final file = await controller.takePhoto();
                              if (file != null) controller.selectImage(file);
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          );
                        } else if (index == 1) {
                          // Gallery icon
                          return GestureDetector(
                            onTap: () async {
                              final file = await controller.pickImage();
                              if (file != null) controller.selectImage(file);
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          );
                        } else {
                          final file = controller.recentMedia[index - 2];
                          return GestureDetector(
                            onTap: () => controller.selectImage(file),
                            child: Container(
                              decoration: BoxDecoration(
                                border:
                                    controller.selectedImage.value?.path ==
                                            file.path
                                        ? Border.all(
                                          color: Colors.blue,
                                          width: 3,
                                        )
                                        : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  file,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        if (controller.isLoading.value) return const SizedBox.shrink();

        return Container(
          height: 60,
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomAction(
                icon: Icons.text_fields,
                label: 'Text',
                isActive: controller.drawingMode.value == DrawingMode.text,
                onTap: () {
                  // Create text in the center of the screen, above keyboard area
                  final screenSize = MediaQuery.of(context).size;
                  final centerPosition = Offset(
                    screenSize.width / 2 -
                        50, // Offset to center the text widget
                    screenSize.height *
                        0.3, // Position in upper third of screen
                  );

                  _textController.addText(centerPosition);
                  controller.drawingMode.value = DrawingMode.text;
                  controller.isEditingText.value = true;
                },
              ),
              _buildBottomAction(
                icon: Icons.brush,
                label: 'Doodle',
                isActive: controller.drawingMode.value == DrawingMode.doodle,
                onTap: () {
                  if (controller.drawingMode.value != DrawingMode.doodle) {
                    controller.drawingMode.value = DrawingMode.doodle;
                  } else {
                    controller.drawingMode.value = DrawingMode.none;
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.blue : Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.blue : Colors.white,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

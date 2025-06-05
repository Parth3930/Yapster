import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/stories_controller.dart';
import 'package:yapster/app/modules/stories/controllers/doodle_controller.dart';
import 'package:yapster/app/modules/stories/controllers/text_editor_controller.dart';
import 'package:yapster/app/modules/stories/models/text_element.dart';
import 'package:yapster/app/modules/stories/widgets/doodle_widget.dart';
import 'package:yapster/app/modules/stories/widgets/text_editor_toolbar.dart';

enum DrawingMode { none, text, doodle }

class CreateStoryView extends GetView<StoriesController> {
  const CreateStoryView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize the controllers if not already registered
    if (!Get.isRegistered<DoodleController>()) {
      Get.put(DoodleController());
    }
    if (!Get.isRegistered<TextEditorController>()) {
      Get.put(TextEditorController());
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
              Get.snackbar('Success', 'Story posted successfully!');
            },
            child: const Text(
              'Post',
              style: TextStyle(
                color: Colors.white,
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

        return Container(
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
              else
                const Center(
                  child: Text(
                    "Select an image",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),

              // Doodle widget when in doodle mode
              if (controller.drawingMode.value == DrawingMode.doodle)
                const DoodleWidget(),

              // Text elements with drag and drop support
              Obx(
                () => Stack(
                  children:
                      controller.textElements.map((element) {
                        return Positioned(
                          left: element.position.dx,
                          top: element.position.dy,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              if (controller.drawingMode.value ==
                                  DrawingMode.none) {
                                // Move to top of stack
                                final updatedElement = element.copyWith(
                                  isDragging: true,
                                );
                                updatedElement.dragStartPosition =
                                    element.position;
                                updatedElement.dragStartOffset =
                                    details.localPosition;

                                controller.textElements.remove(element);
                                controller.textElements.add(updatedElement);
                              }
                            },
                            onPanUpdate: (details) {
                              if (controller.drawingMode.value ==
                                      DrawingMode.none &&
                                  element.isDragging) {
                                final index = controller.textElements
                                    .indexWhere((e) => e == element);
                                if (index != -1) {
                                  final updatedElement = element.copyWith(
                                    position: Offset(
                                      element.position.dx + details.delta.dx,
                                      element.position.dy + details.delta.dy,
                                    ),
                                  );
                                  controller.textElements[index] =
                                      updatedElement;
                                }
                              }
                            },
                            onPanEnd: (_) {
                              if (element.isDragging) {
                                final index = controller.textElements
                                    .indexWhere((e) => e == element);
                                if (index != -1) {
                                  controller.textElements[index] = element
                                      .copyWith(isDragging: false);
                                }
                              }
                            },
                            onTap: () {
                              if (controller.drawingMode.value ==
                                  DrawingMode.none) {
                                controller.editTextElement(element);
                              }
                            },
                            onLongPress: () {
                              controller.textElements.remove(element);
                              if (controller.editingTextElement.value ==
                                  element) {
                                controller.editingTextElement.value = null;
                                controller.isEditingText.value = false;
                                controller.drawingMode.value = DrawingMode.none;
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    element.backgroundColor !=
                                            Colors.transparent
                                        ? element.backgroundColor
                                        : null,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    element.isEditing
                                        ? Border.all(
                                          color: Colors.blue,
                                          width: 2,
                                        )
                                        : null,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                element.text,
                                style: TextStyle(
                                  color: element.color,
                                  fontSize: element.size,
                                  fontWeight: element.fontWeight,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                        controller.recentMedia.length +
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
                                      ? Border.all(color: Colors.blue, width: 3)
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

              // Text editor toolbar when in text mode and editing
              if (controller.drawingMode.value == DrawingMode.text &&
                  controller.isEditingText.value)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              // Preview of the text
                              if (controller.editingTextElement.value != null)
                                Positioned(
                                  left:
                                      controller
                                          .editingTextElement
                                          .value!
                                          .position
                                          .dx,
                                  top:
                                      controller
                                          .editingTextElement
                                          .value!
                                          .position
                                          .dy,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            controller
                                                .editingTextElement
                                                .value!
                                                .backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        controller.textEditingController.text,
                                        style: TextStyle(
                                          color:
                                              controller
                                                  .editingTextElement
                                                  .value!
                                                  .color,
                                          fontSize:
                                              controller
                                                  .editingTextElement
                                                  .value!
                                                  .size,
                                          fontWeight:
                                              controller
                                                      .textEditorController
                                                      .isBold
                                                      .value
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Invisible text field for input
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Opacity(
                                  opacity: 0,
                                  child: TextField(
                                    controller:
                                        controller.textEditingController,
                                    style: TextStyle(
                                      color:
                                          controller
                                              .textEditorController
                                              .textColor
                                              .value,
                                      fontSize:
                                          controller
                                              .textEditorController
                                              .textSize
                                              .value,
                                      fontWeight:
                                          controller
                                                  .textEditorController
                                                  .isBold
                                                  .value
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                    maxLines: null,
                                    onEditingComplete: () {
                                      if (controller.textEditingController.text
                                              .trim()
                                              .isEmpty &&
                                          controller.editingTextElement.value !=
                                              null) {
                                        // Remove if empty when done editing
                                        controller.textElements.remove(
                                          controller.editingTextElement.value!,
                                        );
                                        controller.editingTextElement.value =
                                            null;
                                        controller.drawingMode.value =
                                            DrawingMode.none;
                                      } else if (controller
                                              .editingTextElement
                                              .value !=
                                          null) {
                                        // Update the text element with the final text and mark as not editing
                                        controller.updateTextElement(
                                          controller.editingTextElement.value!,
                                          text:
                                              controller
                                                  .textEditingController
                                                  .text,
                                          isEditing: false,
                                        );

                                        // Clear editing state
                                        controller.editingTextElement.value =
                                            null;
                                        controller.drawingMode.value =
                                            DrawingMode.none;
                                      } else if (controller
                                          .isEditingText
                                          .value) {
                                        // Add new text element
                                        controller.addTextElement(
                                          TextElement(
                                            text:
                                                controller
                                                    .textEditingController
                                                    .text,
                                            position: Offset(
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width /
                                                  2,
                                              MediaQuery.of(
                                                    context,
                                                  ).size.height /
                                                  2,
                                            ),
                                            color:
                                                controller
                                                    .textEditorController
                                                    .textColor
                                                    .value,
                                            size:
                                                controller
                                                    .textEditorController
                                                    .textSize
                                                    .value,
                                            fontWeight:
                                                controller
                                                        .textEditorController
                                                        .isBold
                                                        .value
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            backgroundColor: Colors.transparent,
                                          ),
                                        );
                                        controller.drawingMode.value =
                                            DrawingMode.none;
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Text editor toolbar
                        TextEditorToolbar(
                          onDone: () {
                            if (controller.textEditingController.text
                                    .trim()
                                    .isEmpty &&
                                controller.editingTextElement.value != null) {
                              // Remove if empty when done editing
                              controller.textElements.remove(
                                controller.editingTextElement.value!,
                              );
                              controller.editingTextElement.value = null;
                              controller.drawingMode.value = DrawingMode.none;
                            } else if (controller.editingTextElement.value !=
                                null) {
                              // Update the text element with the final text and mark as not editing
                              controller.updateTextElement(
                                controller.editingTextElement.value!,
                                text: controller.textEditingController.text,
                                isEditing: false,
                              );

                              // Clear editing state
                              controller.editingTextElement.value = null;
                              controller.drawingMode.value = DrawingMode.none;
                            } else if (controller.isEditingText.value) {
                              // Add new text element
                              controller.addTextElement(
                                TextElement(
                                  text: controller.textEditingController.text,
                                  position: Offset.zero,
                                  color: Colors.white,
                                  size: 20,
                                  backgroundColor: Colors.transparent,
                                  fontWeight: FontWeight.normal,
                                  isDragging: false,
                                  isEditing: false,
                                ),
                              );
                              controller.drawingMode.value = DrawingMode.none;
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
                  if (controller.drawingMode.value != DrawingMode.text) {
                    controller.drawingMode.value = DrawingMode.text;
                    controller.isEditingText.value = true;
                    controller.textEditingController.clear();
                    // Focus the invisible text field
                    FocusScope.of(context).requestFocus(FocusNode());
                  } else {
                    controller.drawingMode.value = DrawingMode.none;
                    controller.isEditingText.value = false;
                  }
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

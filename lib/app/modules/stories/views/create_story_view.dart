import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/stories_controller.dart';
import 'package:yapster/app/modules/stories/models/text_element.dart';
import 'package:yapster/app/modules/stories/widgets/doodle_widget.dart';

enum DrawingMode { none, text, doodle }

class CreateStoryView extends StatefulWidget {
  const CreateStoryView({super.key});

  @override
  State<CreateStoryView> createState() => _CreateStoryViewState();
}

class _CreateStoryViewState extends State<CreateStoryView> {
  final StoriesController controller = Get.put(StoriesController());
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.blue : Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.blue : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Handle doodle clear
  void _clearDoodle() {
    controller.drawingPoints.clear();
  }

  // Handle undo last doodle stroke
  void _undoLastDoodle() {
    if (controller.drawingPoints.isNotEmpty) {
      controller.drawingPoints.removeLast();
    }
  }

  // Text elements on canvas
  final RxList<TextElement> _textElements = <TextElement>[].obs;

  // Current text element being edited
  final Rxn<TextElement> _editingTextElement = Rxn<TextElement>();

  void _addNewTextElement() {
    final newElement = TextElement(
      text: 'Tap to edit',
      position: const Offset(100, 100), // Center position
      color: controller.textColor.value,
      backgroundColor: controller.textBackgroundColor.value,
      size: controller.textSize.value,
      fontWeight: controller.textFontWeight.value,
      isEditing: true,
    );

    _editingTextElement.value = newElement;
    _textElements.add(newElement);
    _textController.text = newElement.text;
    _textFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _updateTextElement() {
    if (_editingTextElement.value != null) {
      final updatedElement = _editingTextElement.value!.copyWith(
        text: _textController.text,
        color: controller.textColor.value,
        backgroundColor: controller.textBackgroundColor.value,
        size: controller.textSize.value,
        fontWeight: controller.textFontWeight.value,
      );

      final index = _textElements.indexWhere(
        (element) => element == _editingTextElement.value,
      );
      if (index != -1) {
        _textElements[index] = updatedElement;
        _editingTextElement.value = updatedElement;
      }
    }
  }

  void _handleTextEditingComplete() {
    if (_textController.text.trim().isEmpty &&
        _editingTextElement.value != null) {
      // Remove if empty when done editing
      _removeTextElement(_editingTextElement.value!);
    } else if (_editingTextElement.value != null) {
      final updatedElement = _editingTextElement.value!.copyWith(
        isEditing: false,
      );

      final index = _textElements.indexWhere(
        (element) => element == _editingTextElement.value,
      );
      if (index != -1) {
        _textElements[index] = updatedElement;
      }

      _editingTextElement.value = null;
      controller.drawingMode.value = DrawingMode.none;
    }

    _textFocusNode.unfocus();
  }

  // Handle tap on a text element
  void _handleTextElementTap(TextElement element) {
    // If already editing this element, just focus the text field
    if (_editingTextElement.value == element) {
      _textFocusNode.requestFocus();
      return;
    }

    // Clear previous editing state
    if (_editingTextElement.value != null) {
      final prevIndex = _textElements.indexWhere(
        (e) => e == _editingTextElement.value,
      );
      if (prevIndex != -1) {
        _textElements[prevIndex] = _editingTextElement.value!.copyWith(
          isEditing: false,
        );
      }
    }

    // Set up editing state
    _editingTextElement.value = element;
    _textController.text = element.text;
    controller.textPosition.value = element.position;
    controller.textColor.value = element.color;
    controller.textSize.value = element.size;
    controller.textFontWeight.value = element.fontWeight;
    controller.textBackgroundColor.value = element.backgroundColor;

    // Move to top of stack when selected
    _textElements.remove(element);
    _textElements.add(element.copyWith(isEditing: true));

    // Switch to text mode and focus the text field
    controller.drawingMode.value = DrawingMode.text;
    _textFocusNode.requestFocus();
  }

  void _removeTextElement(TextElement element) {
    _textElements.remove(element);
    if (_editingTextElement.value == element) {
      _editingTextElement.value = null;
      _textController.clear();
      controller.drawingMode.value = DrawingMode.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Use the controller to manage state
      final controller = Get.find<StoriesController>();
      if (controller.isLoading.value) {
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: SizedBox.shrink()),
        );
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
        body: Container(
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

              // Doodle layer when in doodle mode
              if (controller.drawingMode.value == DrawingMode.doodle)
                Positioned.fill(
                  child: DoodleWidget(
                    drawingPoints: controller.drawingPoints,
                    onColorChanged:
                        (color) => controller.doodleColor.value = color,
                    onWidthChanged:
                        (width) => controller.doodleStrokeWidth.value = width,
                    onClear: _clearDoodle,
                    onUndo: _undoLastDoodle,
                    currentColor: controller.doodleColor.value,
                    currentWidth: controller.doodleStrokeWidth.value,
                  ),
                ),

              // Text elements with drag and drop support
              ...(_textElements.map((element) {
                return Positioned(
                  left: element.position.dx,
                  top: element.position.dy,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      if (controller.drawingMode.value == DrawingMode.none) {
                        // Move to top of stack
                        final updatedElement = element.copyWith(
                          isDragging: true,
                        );
                        updatedElement.dragStartPosition = element.position;
                        updatedElement.dragStartOffset = details.localPosition;

                        _textElements.remove(element);
                        _textElements.add(updatedElement);
                      }
                    },
                    onPanUpdate: (details) {
                      if (controller.drawingMode.value == DrawingMode.none &&
                          element.isDragging) {
                        final index = _textElements.indexWhere(
                          (e) => e == element,
                        );
                        if (index != -1) {
                          final updatedElement = element.copyWith(
                            position: Offset(
                              element.position.dx + details.delta.dx,
                              element.position.dy + details.delta.dy,
                            ),
                          );
                          _textElements[index] = updatedElement;
                        }
                      }
                    },
                    onPanEnd: (_) {
                      if (element.isDragging) {
                        final index = _textElements.indexWhere(
                          (e) => e == element,
                        );
                        if (index != -1) {
                          _textElements[index] = element.copyWith(
                            isDragging: false,
                          );
                        }
                      }
                    },
                    onTap: () {
                      if (controller.drawingMode.value == DrawingMode.none) {
                        _handleTextElementTap(element);
                      }
                    },
                    onLongPress: () => _removeTextElement(element),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            element.backgroundColor != Colors.transparent
                                ? element.backgroundColor
                                : null,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            element.isEditing
                                ? Border.all(color: Colors.blue, width: 2)
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
                          color: Colors.white,
                          fontSize: element.size,
                          fontWeight: element.fontWeight,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList()),

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

              // Text editor toolbar
              if (controller.drawingMode.value == DrawingMode.text)
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
                              if (_editingTextElement.value != null)
                                Positioned(
                                  left: _editingTextElement.value!.position.dx,
                                  top: _editingTextElement.value!.position.dy,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _editingTextElement
                                                        .value!
                                                        .backgroundColor !=
                                                    Colors.transparent
                                                ? _editingTextElement
                                                    .value!
                                                    .backgroundColor
                                                : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _textController.text,
                                        style: TextStyle(
                                          color:
                                              _editingTextElement.value!.color,
                                          fontSize:
                                              _editingTextElement.value!.size,
                                          fontWeight:
                                              _editingTextElement
                                                  .value!
                                                  .fontWeight,
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
                                    controller: _textController,
                                    focusNode: _textFocusNode,
                                    style: TextStyle(
                                      color: controller.textColor.value,
                                      fontSize: controller.textSize.value,
                                      fontWeight:
                                          controller.textFontWeight.value,
                                    ),
                                    maxLines: null,
                                    onChanged: (_) => _updateTextElement(),
                                    onEditingComplete:
                                        _handleTextEditingComplete,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 8.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Color selection
                              SizedBox(
                                height: 50,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (var color in const [
                                      Colors.white,
                                      Colors.black,
                                      Colors.red,
                                      Colors.green,
                                      Colors.blue,
                                      Colors.yellow,
                                      Colors.purple,
                                    ])
                                      GestureDetector(
                                        onTap: () {
                                          controller.textColor.value = color;
                                          _updateTextElement();
                                        },
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width:
                                                  controller.textColor.value ==
                                                          color
                                                      ? 2
                                                      : 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Font size slider
                              Row(
                                children: [
                                  const Text(
                                    'A',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: controller.textSize.value,
                                      min: 12,
                                      max: 72,
                                      onChanged: (value) {
                                        controller.textSize.value = value;
                                        _updateTextElement();
                                      },
                                      activeColor: Colors.white,
                                      inactiveColor: Colors.grey,
                                    ),
                                  ),
                                  const Text(
                                    'A',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(
                icon: Icons.text_fields,
                label: 'Text',
                isActive: controller.drawingMode.value == DrawingMode.text,
                onTap: () {
                  if (controller.drawingMode.value == DrawingMode.text) {
                    controller.drawingMode.value = DrawingMode.none;
                  } else {
                    controller.drawingMode.value = DrawingMode.text;
                    _addNewTextElement();
                  }
                },
              ),
              _buildBottomAction(
                icon: Icons.brush,
                label: 'Doodle',
                isActive: controller.drawingMode.value == DrawingMode.doodle,
                onTap: () {
                  controller.drawingMode.value =
                      controller.drawingMode.value == DrawingMode.doodle
                          ? DrawingMode.none
                          : DrawingMode.doodle;
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/stories_controller.dart';
import 'package:yapster/app/modules/stories/models/drawing_point.dart';
import 'package:yapster/app/modules/stories/models/text_element.dart';
import 'package:yapster/app/modules/stories/widgets/doodle_canvas.dart';
import 'package:yapster/app/modules/stories/widgets/doodle_toolbar.dart';
import 'package:yapster/app/modules/stories/widgets/story_text_field.dart';
import 'package:yapster/app/modules/stories/widgets/text_editor_toolbar.dart';

enum DrawingMode { none, text, doodle }

class CreateStoryView extends StatefulWidget {
  const CreateStoryView({Key? key}) : super(key: key);

  @override
  State<CreateStoryView> createState() => _CreateStoryViewState();
}

class _CreateStoryViewState extends State<CreateStoryView> {
  final StoriesController controller = Get.put(StoriesController());
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final Rx<DrawingMode> _drawingMode = DrawingMode.none.obs;
  final Rx<Offset> _textPosition = const Offset(100, 100).obs;
  
  // Text styling
  final Rx<Color> _textColor = Colors.white.obs;
  final Rx<Color> _textBackgroundColor = Colors.transparent.obs;
  final RxDouble _textSize = 24.0.obs;
  final Rx<FontWeight> _textFontWeight = FontWeight.normal.obs;
  
  // Doodle properties
  final List<DrawingPoint> _drawingPoints = [];
  final Rx<Color> _doodleColor = Colors.white.obs;
  final RxDouble _doodleStrokeWidth = 5.0.obs;
  
  // Text elements on canvas
  final List<TextElement> _textElements = [];
  
  // Current text element being edited
  TextElement? _editingTextElement;
  
  // Available colors for quick selection
  final List<Color> _quickColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.transparent,
  ];

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _addTextElement() {
    if (_textController.text.trim().isNotEmpty) {
      final element = TextElement(
        text: _textController.text,
        position: _textPosition.value,
        color: _textColor.value,
        backgroundColor: _textBackgroundColor.value,
        size: _textSize.value,
        fontWeight: _textFontWeight.value,
      );
      
      setState(() {
        if (_editingTextElement != null) {
          final index = _textElements.indexOf(_editingTextElement!);
          if (index != -1) {
            _textElements[index] = element;
          }
        } else {
          _textElements.add(element);
        }
        _editingTextElement = null;
        _textController.clear();
        _drawingMode.value = DrawingMode.none;
      });
    } else {
      setState(() {
        _editingTextElement = null;
        _drawingMode.value = DrawingMode.none;
      });
    }
    _textFocusNode.unfocus();
  }

  void _editTextElement(TextElement element) {
    setState(() {
      _editingTextElement = element;
      _textController.text = element.text;
      _textPosition.value = element.position;
      _textColor.value = element.color;
      _textBackgroundColor.value = element.backgroundColor;
      _textSize.value = element.size;
      _textFontWeight.value = element.fontWeight;
      _drawingMode.value = DrawingMode.text;
      _textFocusNode.requestFocus();
    });
  }

  void _removeTextElement(TextElement element) {
    setState(() {
      _textElements.remove(element);
      if (_editingTextElement == element) {
        _editingTextElement = null;
        _textController.clear();
        _drawingMode.value = DrawingMode.none;
      }
    });
  }

  void _startDoodle(DragStartDetails details) {
    if (_drawingMode.value == DrawingMode.doodle) {
      setState(() {
        _drawingPoints.add(
          DrawingPoint(
            points: [details.localPosition],
            color: _doodleColor.value,
            width: _doodleStrokeWidth.value,
          ),
        );
      });
    }
  }

  void _updateDoodle(DragUpdateDetails details) {
    if (_drawingMode.value == DrawingMode.doodle && _drawingPoints.isNotEmpty) {
      setState(() {
        _drawingPoints.last.points.add(details.localPosition);
      });
    }
  }

  void _endDoodle() {
    if (_drawingMode.value == DrawingMode.doodle) {
      setState(() {
        if (_drawingPoints.isNotEmpty && _drawingPoints.last.points.length == 1) {
          // If it's just a single point, add a small line segment
          final point = _drawingPoints.last.points[0];
          _drawingPoints.last.points.add(Offset(point.dx + 0.1, point.dy + 0.1));
        }
      });
    }
  }

  void _clearDoodle() {
    setState(() {
      _drawingPoints.clear();
    });
  }

  void _undoLastDoodle() {
    if (_drawingPoints.isNotEmpty) {
      setState(() {
        _drawingPoints.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
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
              child: CircularProgressIndicator(),
            ),

          // Text elements
          ..._textElements.map((element) {
            return Positioned(
              left: element.position.dx,
              top: element.position.dy,
              child: GestureDetector(
                onTap: () => _editTextElement(element),
                onLongPress: () => _removeTextElement(element),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: element.backgroundColor != Colors.transparent
                        ? element.backgroundColor
                        : null,
                    borderRadius: BorderRadius.circular(8),
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
          }),

          // Text editor
          if (_drawingMode.value == DrawingMode.text)
            StoryTextField(
              controller: _textController,
              focusNode: _textFocusNode,
              position: _textPosition.value,
              textColor: _textColor.value,
              backgroundColor: _textBackgroundColor.value,
              textSize: _textSize.value,
              fontWeight: _textFontWeight.value,
              onTextUpdated: (element) {
                setState(() {
                  _textPosition.value = element.position;
                  _textColor.value = element.color;
                  _textBackgroundColor.value = element.backgroundColor;
                  _textSize.value = element.size;
                  _textFontWeight.value = element.fontWeight;
                });
              },
              onTap: () {
                _drawingMode.value = DrawingMode.text;
              },
              isEditing: true,
            ),

          // Doodle canvas
          if (_drawingMode.value == DrawingMode.doodle)
            Positioned.fill(
              child: DoodleCanvas(
                drawingPoints: _drawingPoints,
                color: _doodleColor.value,
                strokeWidth: _doodleStrokeWidth.value,
                onPanStart: _startDoodle,
                onPanUpdate: _updateDoodle,
                onPanEnd: _endDoodle,
              ),
            ),

          // Text editor toolbar
          if (_drawingMode.value == DrawingMode.text)
            TextEditorToolbar(
              textController: _textController,
              textColor: _textColor,
              textBackgroundColor: _textBackgroundColor,
              textSize: _textSize,
              textFontWeight: _textFontWeight,
              onAddText: _addTextElement,
              quickColors: _quickColors,
            ),

          // Doodle toolbar
          if (_drawingMode.value == DrawingMode.doodle)
            DoodleToolbar(
              doodleColor: _doodleColor,
              doodleStrokeWidth: _doodleStrokeWidth,
              onClear: _clearDoodle,
              onUndo: _undoLastDoodle,
              quickColors: _quickColors,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(
              Icons.text_fields,
              'Text',
              onTap: () {
                setState(() {
                  if (_drawingMode.value == DrawingMode.text) {
                    _drawingMode.value = DrawingMode.none;
                    _textController.clear();
                    _editingTextElement = null;
                  } else {
                    _drawingMode.value = DrawingMode.text;
                    _textFocusNode.requestFocus();
                  }
                });
              },
            ),
            _buildNavButton(
              Icons.brush,
              'Draw',
              onTap: () {
                setState(() {
                  _drawingMode.value = _drawingMode.value == DrawingMode.doodle
                      ? DrawingMode.none
                      : DrawingMode.doodle;
                });
              },
            ),
            _buildNavButton(
              Icons.image,
              'Gallery',
              onTap: () {
                controller.pickImage();
              },
            ),
            _buildNavButton(
              Icons.camera_alt,
              'Camera',
              onTap: () {
                controller.pickImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

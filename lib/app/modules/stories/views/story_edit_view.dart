import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/text_controller.dart';
import '../controllers/doodle_controller.dart';
import '../models/drawing_point.dart';
import 'dart:io';

class StoryEditView extends StatelessWidget {
  final File imageFile;

  StoryEditView({Key? key, required this.imageFile}) : super(key: key);

  final TextController textController = Get.put(TextController());
  final DoodleController doodleController = Get.put(DoodleController());
  final RxBool isTextMode = false.obs;
  final RxBool isDoodleMode = false.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit Story', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Save story with text and doodles
              // This would typically save to a repository
              Get.back(
                result: {
                  'image': imageFile,
                  'textItems': textController.textItems,
                  'doodlePoints': doodleController.drawingPoints,
                },
              );
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
      body: Stack(
        children: [
          // Background image
          Positioned.fill(child: Image.file(imageFile, fit: BoxFit.contain)),

          // Text elements
          Positioned.fill(
            child: Obx(
              () => Stack(
                children: [
                  for (int i = 0; i < textController.textItems.length; i++)
                    Positioned(
                      left: textController.textItems[i].position.dx,
                      top: textController.textItems[i].position.dy,
                      child: GestureDetector(
                        onTap: () => textController.selectedTextIndex(i),
                        onPanUpdate: (details) {
                          textController.updateTextPosition(
                            i,
                            details.localPosition,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: textController.textItems[i].backgroundColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            textController.textItems[i].text,
                            style: TextStyle(
                              color: textController.textItems[i].color,
                              fontSize: textController.textItems[i].fontSize,
                              fontWeight:
                                  textController.textItems[i].fontWeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Doodle canvas
          Positioned.fill(
            child: Obx(
              () => CustomPaint(
                painter: DoodlePainter(doodleController.drawingPoints),
                child: GestureDetector(
                  onPanStart:
                      isDoodleMode.value
                          ? doodleController.handleDoodleStart
                          : null,
                  onPanUpdate:
                      isDoodleMode.value
                          ? doodleController.handleDoodleUpdate
                          : null,
                  onPanEnd:
                      isDoodleMode.value
                          ? doodleController.handleDoodleEnd
                          : null,
                ),
              ),
            ),
          ),

          // Right side toolbar
          Positioned(
            top: 100,
            right: 16,
            child: Column(
              children: [
                // Text tool
                _buildToolButton(
                  icon: FontAwesomeIcons.font,
                  isActive: isTextMode.value,
                  onTap: () {
                    isTextMode.value = !isTextMode.value;
                    if (isTextMode.value) {
                      isDoodleMode.value = false;
                      // Add text in the center of the screen
                      textController.addText(
                        Offset(
                          MediaQuery.of(context).size.width / 2 - 50,
                          MediaQuery.of(context).size.height / 2 - 25,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Doodle tool
                _buildToolButton(
                  icon: FontAwesomeIcons.pencil,
                  isActive: isDoodleMode.value,
                  onTap: () {
                    isDoodleMode.value = !isDoodleMode.value;
                    if (isDoodleMode.value) {
                      isTextMode.value = false;
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Color picker (only shown when in doodle mode)
                if (isDoodleMode.value)
                  _buildToolButton(
                    icon: FontAwesomeIcons.palette,
                    isActive: false,
                    onTap: () {
                      // Show color picker
                      _showColorPicker(context);
                    },
                  ),

                // Undo button (only shown when in doodle mode)
                if (isDoodleMode.value) ...[
                  const SizedBox(height: 16),
                  _buildToolButton(
                    icon: FontAwesomeIcons.arrowRotateLeft,
                    isActive: false,
                    onTap: doodleController.undo,
                  ),
                ],

                // Clear button (only shown when in doodle mode)
                if (isDoodleMode.value) ...[
                  const SizedBox(height: 16),
                  _buildToolButton(
                    icon: FontAwesomeIcons.trash,
                    isActive: false,
                    onTap: doodleController.clear,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Center(child: FaIcon(icon, color: Colors.white, size: 20)),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Select Color',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _colorCircle(Colors.red),
                    _colorCircle(Colors.orange),
                    _colorCircle(Colors.yellow),
                    _colorCircle(Colors.green),
                    _colorCircle(Colors.blue),
                    _colorCircle(Colors.indigo),
                    _colorCircle(Colors.purple),
                    _colorCircle(Colors.pink),
                    _colorCircle(Colors.white),
                    _colorCircle(Colors.black),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _colorCircle(Color color) {
    return GestureDetector(
      onTap: () {
        doodleController.currentColor.value = color;
        Get.back();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class DoodlePainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DoodlePainter(this.drawingPoints);

  @override
  void paint(Canvas canvas, Size size) {
    for (var drawingPoint in drawingPoints) {
      final paint =
          Paint()
            ..color = drawingPoint.color
            ..isAntiAlias = true
            ..strokeWidth = drawingPoint.width
            ..strokeCap = StrokeCap.round;

      for (int i = 0; i < drawingPoint.points.length - 1; i++) {
        final p1 = drawingPoint.points[i];
        final p2 = drawingPoint.points[i + 1];
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

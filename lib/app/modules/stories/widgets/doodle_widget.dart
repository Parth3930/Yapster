import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/drawing_point.dart';
import '../controllers/doodle_controller.dart';

class DoodlePainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DoodlePainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (var drawingPoint in drawingPoints) {
      if (drawingPoint.points.isEmpty) continue;

      final paint =
          Paint()
            ..color = drawingPoint.color
            ..isAntiAlias = true
            ..strokeWidth = drawingPoint.width
            ..strokeCap = StrokeCap.round;

      for (var i = 0; i < drawingPoint.points.length - 1; i++) {
        if (i + 1 < drawingPoint.points.length) {
          final current = drawingPoint.points[i];
          final next = drawingPoint.points[i + 1];
          canvas.drawLine(current, next, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) {
    return oldDelegate.drawingPoints != drawingPoints;
  }
}

class DoodleWidget extends GetView<DoodleController> {
  const DoodleWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Color> _colors = const [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.black,
      Colors.white,
    ];

    return Stack(
      children: [
        // Main drawing area
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: controller.handleDoodleStart,
          onPanUpdate: controller.handleDoodleUpdate,
          onPanEnd: controller.handleDoodleEnd,
          child: Obx(
            () => CustomPaint(
              painter: DoodlePainter(
                drawingPoints: controller.drawingPoints.toList(),
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // Color picker slider on the right
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gradient slider
                Container(
                  width: 20,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow,
                        Colors.green,
                        Colors.blue,
                        Colors.indigo,
                        Colors.purple,
                        Colors.black,
                        Colors.white,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                // Gesture detector for the entire area
                GestureDetector(
                  onVerticalDragStart: (details) {
                    _updateColorFromPosition(
                      context,
                      details.globalPosition,
                      _colors,
                    );
                  },
                  onVerticalDragUpdate: (details) {
                    _updateColorFromPosition(
                      context,
                      details.globalPosition,
                      _colors,
                    );
                  },
                  child: Container(
                    width: 40, // Wider touch area
                    height: 300,
                    color: Colors.transparent,
                  ),
                ),

                // Circle thumb indicator
                Obx(() {
                  // Calculate position based on current color
                  final int colorIndex = _colors.indexOf(
                    controller.currentColor.value,
                  );
                  final double position =
                      colorIndex != -1
                          ? (colorIndex / (_colors.length - 1) * 300).clamp(
                            0.0,
                            300.0,
                          )
                          : 0.0;

                  return Positioned(
                    top: position - 10, // Center the circle on the color
                    left:
                        10, // Position the circle to be centered on the slider (20px slider width / 2 = 10)
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Use Color directly without casting to MaterialColor
                        color: Color(controller.currentColor.value.value),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(Icons.undo, controller.undo),
              const SizedBox(width: 24),
              _buildControlButton(Icons.clear, controller.clear),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  void _updateColorFromPosition(
    BuildContext context,
    Offset globalPosition,
    List<Color> colors,
  ) {
    // Convert global position to local position relative to the slider
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(globalPosition);

    // Calculate position ratio (0.0 to 1.0) within the slider height
    final double yRatio = (localPosition.dy / 300).clamp(0.0, 1.0);

    // Map to color index and update controller
    final int colorIndex = (yRatio * (colors.length - 1)).round();
    // Create a new Color object using the RGBA values from the selected color
    final Color selectedColor = colors[colorIndex];
    controller.currentColor.value = Color.fromRGBO(
      selectedColor.red,
      selectedColor.green,
      selectedColor.blue,
      selectedColor.opacity,
    );
  }
}

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
  DoodleWidget({super.key});

  final GlobalKey _sliderKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Define key colors for a rainbow gradient
    const List<Color> rainbowColors = [
      Color(0xFFF44336), // Red
      Color(0xFFFFEB3B), // Yellow
      Color(0xFF4CAF50), // Green
      Color(0xFF00BCD4), // Cyan
      Color(0xFF2196F3), // Blue
      Color(0xFF9C27B0), // Purple
      Color(0xFFF44336), // Red (loop)
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

        // Color picker slider and controls on the right
        Positioned(
          right: 16,
          top: 16, // Position at the top
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color slider
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Gradient slider
                    Container(
                      key: _sliderKey,
                      width: 20,
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: rainbowColors,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
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
                        );
                      },
                      onVerticalDragUpdate: (details) {
                        _updateColorFromPosition(
                          context,
                          details.globalPosition,
                        );
                      },
                      child: Container(
                        width:
                            40, // Touch area width, can be wider than the visual slider for easier interaction
                        height: 250, // Match the slider height
                        // No margin needed if we want the gesture detector to perfectly overlay the slider
                        decoration: BoxDecoration(
                          // borderRadius: BorderRadius.circular(20), // Optional: if you want rounded touch area
                          color: Colors.transparent, // Make it invisible
                        ),
                      ),
                    ),

                    // Circle thumb indicator
                    Obx(() {
                      // Use the stored slider position instead of calculating from color
                      double positionRatio =
                          controller.lastSliderPosition.value;

                      // Slider visual height is 250, thumb height is 20
                      const double sliderPixelHeight = 250.0;
                      const double thumbPixelHeight = 20.0;
                      final double draggableRange =
                          sliderPixelHeight - thumbPixelHeight;

                      // Calculate position and ensure it stays within bounds
                      double position = (positionRatio * draggableRange);
                      position = position.clamp(0.0, draggableRange);

                      return Positioned(
                        left: 0, // Center the thumb on the slider
                        right:
                            0, // By setting both left and right to 0, we center it
                        top: position,
                        child: GestureDetector(
                          // Add gesture detection to the thumb itself
                          onVerticalDragStart: (details) {
                            _updateColorFromPosition(
                              context,
                              details.globalPosition,
                            );
                          },
                          onVerticalDragUpdate: (details) {
                            _updateColorFromPosition(
                              context,
                              details.globalPosition,
                            );
                          },
                          child: Center(
                            child: Container(
                              width: 20, // Match the slider width
                              height: 20, // Smaller circle
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: controller.currentColor.value,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Control buttons in column format below the slider
              const SizedBox(height: 16),
              SizedBox(
                child: Column(
                  children: [
                    _buildControlButton(Icons.undo, controller.undo),
                    _buildControlButton(Icons.redo, controller.redo),
                    _buildControlButton(Icons.clear, controller.clear),
                    _buildControlButton(
                      Icons.cleaning_services,
                      controller.erase,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }

  void _updateColorFromPosition(BuildContext context, Offset globalPosition) {
    // Convert global position to local position relative to the slider
    final RenderBox? sliderBox =
        _sliderKey.currentContext?.findRenderObject() as RenderBox?;
    if (sliderBox == null) return;
    final Offset localPosition = sliderBox.globalToLocal(globalPosition);

    // Calculate position ratio (0.0 to 1.0) within the slider height
    // Use sliderBox.size.height for accuracy if the height might change
    double yRatio = (localPosition.dy / sliderBox.size.height);

    // Strictly clamp the yRatio to prevent wrapping
    yRatio = yRatio.clamp(0.0, 1.0);

    // Store the last position to prevent jumping back to top
    controller.lastSliderPosition.value = yRatio;

    // Calculate color based on yRatio using HSL/HSV
    // yRatio 0.0 (top) = hue 0 (red), yRatio 1.0 (bottom) = hue 359.999 (purple)
    // We use 359.999 as the max to avoid wrapping back to red (0/360)
    final double hue = yRatio * 359.999;

    // Create the color and update the controller
    final Color newColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    controller.currentColor.value = newColor;
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/models/drawing_point.dart';

class DoodlePainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  const DoodlePainter(this.drawingPoints);

  @override
  void paint(Canvas canvas, Size size) {
    for (var point in drawingPoints) {
      if (point.points.isEmpty) continue;

      final paint =
          Paint()
            ..color = point.color
            ..strokeWidth = point.width
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = true;

      for (var i = 0; i < point.points.length - 1; i++) {
        if (i + 1 < point.points.length) {
          canvas.drawLine(point.points[i], point.points[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DoodlePainter oldDelegate) => true;
}

class DoodleWidget extends StatefulWidget {
  final RxList<DrawingPoint> drawingPoints;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final Color currentColor;
  final double currentWidth;

  const DoodleWidget({
    super.key,
    required this.drawingPoints,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onClear,
    required this.onUndo,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  State<DoodleWidget> createState() => _DoodleWidgetState();
}

class _DoodleWidgetState extends State<DoodleWidget> {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main drawing area
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _handleDoodleStart,
          onPanUpdate: _handleDoodleUpdate,
          onPanEnd: _handleDoodleEnd,
          child: Obx(
            () => CustomPaint(
              painter: DoodlePainter(widget.drawingPoints),
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
            child: Container(
              width: 40,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: RotatedBox(
                quarterTurns: 1,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 40,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: _colors.length - 1.0,
                    divisions: _colors.length - 1,
                    value: _colors.indexOf(widget.currentColor).toDouble(),
                    onChanged: (value) {
                      widget.onColorChanged(_colors[value.round()]);
                    },
                    activeColor: widget.currentColor,
                    inactiveColor: Colors.grey[300],
                  ),
                ),
              ),
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
              _buildControlButton(Icons.undo, widget.onUndo),
              const SizedBox(width: 24),
              _buildControlButton(Icons.clear, widget.onClear),
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

  void _handleDoodleStart(DragStartDetails details) {
    widget.drawingPoints.add(
      DrawingPoint(
        points: [details.localPosition],
        color: widget.currentColor,
        width: widget.currentWidth,
      ),
    );
  }

  void _handleDoodleUpdate(DragUpdateDetails details) {
    if (widget.drawingPoints.isNotEmpty) {
      final lastPoint = widget.drawingPoints.last;
      final updatedPoints = List<Offset>.from(lastPoint.points)
        ..add(details.localPosition);

      final updatedDrawingPoint = DrawingPoint(
        points: updatedPoints,
        color: lastPoint.color,
        width: lastPoint.width,
      );

      widget.drawingPoints[widget.drawingPoints.length - 1] =
          updatedDrawingPoint;
    }
  }

  void _handleDoodleEnd(DragEndDetails _) {
    // Add an empty point to separate strokes
    widget.drawingPoints.add(
      DrawingPoint(
        points: [],
        color: widget.currentColor,
        width: widget.currentWidth,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:yapster/app/modules/stories/models/drawing_point.dart';

class DoodleCanvas extends StatelessWidget {
  final List<DrawingPoint> drawingPoints;
  final Color color;
  final double strokeWidth;
  final Function(DragStartDetails) onPanStart;
  final Function(DragUpdateDetails) onPanUpdate;
  final Function() onPanEnd;

  const DoodleCanvas({
    super.key,
    required this.drawingPoints,
    required this.color,
    required this.strokeWidth,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      child: CustomPaint(
        size: Size.infinite,
        painter: DoodlePainter(
          points: drawingPoints,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class DoodlePainter extends CustomPainter {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;

  const DoodlePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      final paint =
          Paint()
            ..color = point.color
            ..strokeWidth = point.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;

      for (var i = 0; i < point.points.length - 1; i++) {
        canvas.drawLine(point.points[i], point.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DoodlePainter oldDelegate) => true;
}

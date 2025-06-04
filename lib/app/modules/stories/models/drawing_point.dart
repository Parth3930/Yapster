import 'package:flutter/material.dart';

class DrawingPoint {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingPoint({
    required this.points,
    required this.color,
    required this.width,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawingPoint &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          width == other.width;

  @override
  int get hashCode => color.hashCode ^ width.hashCode;
}

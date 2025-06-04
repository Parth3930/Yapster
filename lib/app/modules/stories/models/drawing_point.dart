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
}

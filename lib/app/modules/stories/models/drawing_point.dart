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
          width == other.width &&
          _listEquals(points, other.points);

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(points), color, width);
}

import 'package:flutter/material.dart';

class TextElement {
  final String text;
  final Offset position;
  final Color color;
  final Color backgroundColor;
  final double size;
  final FontWeight fontWeight;

  TextElement({
    required this.text,
    required this.position,
    required this.color,
    required this.backgroundColor,
    required this.size,
    required this.fontWeight,
  });

  TextElement copyWith({
    String? text,
    Offset? position,
    Color? color,
    Color? backgroundColor,
    double? size,
    FontWeight? fontWeight,
  }) {
    return TextElement(
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      size: size ?? this.size,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }
}

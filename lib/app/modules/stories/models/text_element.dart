import 'dart:ui';
import 'package:flutter/material.dart';

class TextElement {
  final String text;
  final Offset position;
  final Color color;
  final Color backgroundColor;
  final double size;
  final FontWeight fontWeight;
  final bool isEditing;
  final bool isDragging;
  Offset? dragStartPosition;
  Offset? dragStartOffset;
  final Size layoutSize;

  TextElement({
    required this.text,
    required this.position,
    required this.color,
    required this.backgroundColor,
    required this.size,
    required this.fontWeight,
    this.isEditing = false,
    this.isDragging = false,
    this.dragStartPosition,
    this.dragStartOffset,
    this.layoutSize = Size.zero,
  });

  TextElement copyWith({
    String? text,
    Offset? position,
    Color? color,
    Color? backgroundColor,
    double? size,
    FontWeight? fontWeight,
    bool? isEditing,
    bool? isDragging,
    Offset? dragStartPosition,
    Offset? dragStartOffset,
    Size? layoutSize,
  }) {
    return TextElement(
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      size: size ?? this.size,
      fontWeight: fontWeight ?? this.fontWeight,
      isEditing: isEditing ?? this.isEditing,
      isDragging: isDragging ?? this.isDragging,
      dragStartPosition: dragStartPosition ?? this.dragStartPosition,
      dragStartOffset: dragStartOffset ?? this.dragStartOffset,
      layoutSize: layoutSize ?? this.layoutSize,
    );
  }

  // Helper method to check if a point is within the text bounds
  bool contains(Offset point) {
    final textRect = Rect.fromCenter(
      center: position,
      width: layoutSize.width,
      height: layoutSize.height,
    );
    return textRect.contains(point);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextElement &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          position == other.position &&
          color == other.color &&
          backgroundColor == other.backgroundColor &&
          size == other.size &&
          fontWeight == other.fontWeight &&
          isEditing == other.isEditing &&
          isDragging == other.isDragging;

  @override
  int get hashCode =>
      text.hashCode ^
      position.hashCode ^
      color.hashCode ^
      backgroundColor.hashCode ^
      size.hashCode ^
      fontWeight.hashCode ^
      isEditing.hashCode ^
      isDragging.hashCode;
}

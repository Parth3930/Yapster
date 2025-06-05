import 'package:flutter/material.dart';
import 'package:yapster/app/modules/stories/controllers/text_controller.dart';

class StoryModel {
  final String id;
  final String userId;
  final String? imageUrl;
  final List<TextItem> textItems;
  final List<Map<String, dynamic>> doodlePoints;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? updatedAt;
  final int viewCount;
  final List<String> viewers;
  final bool isActive;

  StoryModel({
    required this.id,
    required this.userId,
    this.imageUrl,
    required this.textItems,
    required this.doodlePoints,
    required this.createdAt,
    required this.expiresAt,
    this.updatedAt,
    this.viewCount = 0,
    this.viewers = const [],
    this.isActive = true,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      imageUrl: map['image_url'],
      textItems:
          (map['text_items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    TextItemExtension.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      doodlePoints:
          (map['doodle_points'] as List<dynamic>?)
              ?.map((point) => Map<String, dynamic>.from(point))
              .toList() ??
          [],
      createdAt: DateTime.parse(map['created_at']),
      expiresAt: DateTime.parse(map['expires_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      viewCount: map['view_count'] ?? 0,
      viewers:
          (map['viewers'] as List<dynamic>?)
              ?.map((viewer) => viewer.toString())
              .toList() ??
          [],
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'image_url': imageUrl,
      'text_items': textItems.map((item) => item.toMap()).toList(),
      'doodle_points': doodlePoints,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'view_count': viewCount,
      'viewers': viewers,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toMapWithId() {
    return {
      'id': id,
      'user_id': userId,
      'image_url': imageUrl,
      'text_items': textItems.map((item) => item.toMap()).toList(),
      'doodle_points': doodlePoints,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'view_count': viewCount,
      'viewers': viewers,
      'is_active': isActive,
    };
  }
}

// Extension to add toMap and fromMap to TextItem
extension TextItemExtension on TextItem {
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'position_x': position.dx,
      'position_y': position.dy,
      'color': color.value,
      'background_color': backgroundColor.value,
      'font_size': fontSize,
      'font_weight': fontWeight.index,
      'text_align': textAlign.index,
    };
  }

  static TextItem fromMap(Map<String, dynamic> map) {
    return TextItem(
      text: map['text'] ?? '',
      position: Offset(
        (map['position_x'] ?? 0.0).toDouble(),
        (map['position_y'] ?? 0.0).toDouble(),
      ),
      color: Color(map['color'] ?? 0xFF000000),
      backgroundColor: Color(map['background_color'] ?? 0xFFFFFFFF),
      fontSize: (map['font_size'] ?? 24.0).toDouble(),
      fontWeight: FontWeight.values[map['font_weight'] ?? 3],
      textAlign: TextAlign.values[map['text_align'] ?? 1],
    );
  }
}

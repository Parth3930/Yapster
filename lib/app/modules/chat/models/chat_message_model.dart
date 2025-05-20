import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Model class representing a chat message
class ChatMessage {
  final String id;
  final String senderId;
  final String? recipientId;
  final String? groupId;
  final String message;
  final String? imageUrl;
  final String? audioUrl;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToId;
  final Map<String, dynamic>? metadata;
  final bool isDeleted;
  final bool isEncrypted;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.recipientId,
    this.groupId,
    required this.message,
    this.imageUrl,
    this.audioUrl,
    required this.timestamp,
    this.isRead = false,
    this.replyToId,
    this.metadata,
    this.isDeleted = false,
    this.isEncrypted = false,
  });

  /// Create message from JSON data
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      recipientId: json['recipient_id'],
      groupId: json['group_id'],
      message: json['message'] ?? '',
      imageUrl: json['image_url'],
      audioUrl: json['audio_url'],
      timestamp:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      isRead: json['is_read'] ?? false,
      replyToId: json['reply_to_id'],
      metadata: json['metadata'],
      isDeleted: json['is_deleted'] ?? false,
      isEncrypted: json['is_encrypted'] ?? false,
    );
  }

  /// Convert message to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'group_id': groupId,
      'message': message,
      'image_url': imageUrl,
      'audio_url': audioUrl,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'reply_to_id': replyToId,
      'metadata': metadata,
      'is_deleted': isDeleted,
      'is_encrypted': isEncrypted,
    };
  }

  /// Create a copy of this message with some fields replaced
  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? groupId,
    String? message,
    String? imageUrl,
    String? audioUrl,
    DateTime? timestamp,
    bool? isRead,
    String? replyToId,
    Map<String, dynamic>? metadata,
    bool? isDeleted,
    bool? isEncrypted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      groupId: groupId ?? this.groupId,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId ?? this.replyToId,
      metadata: metadata ?? this.metadata,
      isDeleted: isDeleted ?? this.isDeleted,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (messageDate == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      return '${DateFormat('EEEE').format(timestamp)}, ${DateFormat('h:mm a').format(timestamp)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  /// Return true if the message contains media
  bool get hasMedia => imageUrl != null || audioUrl != null;

  /// Return a preview text of the message
  String get previewText {
    if (isDeleted) return 'This message was deleted';
    if (imageUrl != null) return 'Photo';
    if (audioUrl != null) return 'Audio message';
    return message;
  }
}

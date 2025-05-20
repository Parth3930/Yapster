import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_message_model.dart';

/// Model class representing a chat conversation
class ChatConversation {
  final String id;
  final String name;
  final String? imageUrl;
  final bool isGroup;
  final List<String> participantIds;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final ChatMessage? lastMessage;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final bool isEncrypted;
  final Map<String, dynamic>? metadata;

  ChatConversation({
    required this.id,
    required this.name,
    this.imageUrl,
    this.isGroup = false,
    required this.participantIds,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.lastMessage,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isEncrypted = false,
    this.metadata,
  });

  /// Create conversation from JSON data
  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      isGroup: json['is_group'] ?? false,
      participantIds:
          json['participant_ids'] != null
              ? List<String>.from(json['participant_ids'])
              : [],
      lastMessageTime:
          json['last_message_time'] != null
              ? DateTime.parse(json['last_message_time'])
              : null,
      unreadCount: json['unread_count'] ?? 0,
      lastMessage:
          json['last_message'] != null
              ? ChatMessage.fromJson(json['last_message'])
              : null,
      isMuted: json['is_muted'] ?? false,
      isPinned: json['is_pinned'] ?? false,
      isArchived: json['is_archived'] ?? false,
      isEncrypted: json['is_encrypted'] ?? false,
      metadata: json['metadata'],
    );
  }

  /// Convert conversation to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'is_group': isGroup,
      'participant_ids': participantIds,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
      'last_message': lastMessage?.toJson(),
      'is_muted': isMuted,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'is_encrypted': isEncrypted,
      'metadata': metadata,
    };
  }

  /// Create a copy of this conversation with some fields replaced
  ChatConversation copyWith({
    String? id,
    String? name,
    String? imageUrl,
    bool? isGroup,
    List<String>? participantIds,
    DateTime? lastMessageTime,
    int? unreadCount,
    ChatMessage? lastMessage,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    bool? isEncrypted,
    Map<String, dynamic>? metadata,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      isGroup: isGroup ?? this.isGroup,
      participantIds: participantIds ?? this.participantIds,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Format last message time for display
  String get formattedLastMessageTime {
    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      lastMessageTime!.year,
      lastMessageTime!.month,
      lastMessageTime!.day,
    );

    if (messageDate == today) {
      return DateFormat('h:mm a').format(lastMessageTime!);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE').format(lastMessageTime!);
    } else {
      return DateFormat('MMM d').format(lastMessageTime!);
    }
  }

  /// Get other user's ID in a one-to-one chat
  String getRecipientId(String currentUserId) {
    if (isGroup) return '';
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}

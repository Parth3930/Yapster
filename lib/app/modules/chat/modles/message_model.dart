/// Message model for chat messages with encryption support
class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String content;
  final String messageType;
  final String recipientId;
  final DateTime expiresAt;
  final bool isRead;
  final DateTime createdAt;
  final Duration? duration;
  final bool isEncrypted; // Track encryption status
  final bool isUploading; // Track upload status

  const MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.recipientId,
    required this.expiresAt,
    required this.isRead,
    required this.createdAt,
    this.duration,
    this.isEncrypted = false, // Default to not encrypted
    this.isUploading = false, // Default to not uploading
  });

  /// Create a message model with updated fields
  MessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? content,
    String? messageType,
    String? recipientId,
    DateTime? expiresAt,
    bool? isRead,
    DateTime? createdAt,
    Duration? duration,
    bool? isEncrypted,
    bool? isUploading,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      recipientId: recipientId ?? this.recipientId,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  /// Create a message with decrypted content
  MessageModel withDecryptedContent(String decryptedContent) {
    return copyWith(
      content: decryptedContent,
      isEncrypted: false,
    );
  }

  /// Create a message with encrypted content
  MessageModel withEncryptedContent(String encryptedContent) {
    return copyWith(
      content: encryptedContent,
      isEncrypted: true,
    );
  }

  /// Create from JSON with validation
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    try {
      return MessageModel(
        messageId: json['message_id'] ?? '',
        chatId: json['chat_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        content: json['content'] ?? '',
        messageType: json['message_type'] ?? 'text',
        recipientId: json['recipient_id'] ?? '',
        expiresAt: json['expires_at'] != null 
            ? DateTime.parse(json['expires_at']) 
            : DateTime.now().add(const Duration(hours: 24)),
        isRead: json['is_read'] ?? false,
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at']) 
            : DateTime.now(),
        duration: json['duration_seconds'] != null
            ? Duration(seconds: json['duration_seconds'] as int)
            : null,
        isEncrypted: json['is_encrypted'] ?? false,
        isUploading: json['is_uploading'] ?? false,
      );
    } catch (e) {
      // Fallback to prevent crashes on malformed data
      return MessageModel(
        messageId: json['message_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: json['chat_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        content: 'Error parsing message: ${e.toString().substring(0, 50)}...',
        messageType: 'text',
        recipientId: json['recipient_id'] ?? '',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        isRead: false,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'recipient_id': recipientId,
      'expires_at': expiresAt.toIso8601String(),
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      if (duration != null) 'duration_seconds': duration!.inSeconds,
      'is_encrypted': isEncrypted,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModel &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;
}

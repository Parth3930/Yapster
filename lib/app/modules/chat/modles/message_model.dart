class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String content;
  final String messageType;
  final String recipientId;
  final DateTime expiresAt;
  final bool isRead;
  final DateTime createdAt; // ✅ Add this
  final Duration? duration; // Add this

  MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.recipientId,
    required this.expiresAt,
    required this.isRead,
    required this.createdAt, // ✅ Add this
    this.duration, // Add this
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    messageId: json['message_id'],
    chatId: json['chat_id'],
    senderId: json['sender_id'],
    content: json['content'],
    messageType: json['message_type'],
    recipientId: json['recipient_id'],
    expiresAt: DateTime.parse(json['expires_at']),
    isRead: json['is_read'] ?? false,
    createdAt: DateTime.parse(json['created_at']), // ✅ Add this
    duration: json['duration_seconds'] != null
        ? Duration(seconds: json['duration_seconds'] as int)
        : null, // Add this logic
  );
}

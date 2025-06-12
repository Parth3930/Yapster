// Notification model for Yapster
class NotificationModel {
  final String id;
  final String userId; // User who receives the notification
  final String actorId; // User who performed the action
  final String actorUsername;
  final String actorNickname;
  final String actorAvatar;
  final String type; // 'follow', 'like', 'comment'
  final String? postId; // Reference to post (for like/comment)
  final String? commentId; // Reference to comment
  final String? message; // Additional message content
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.actorUsername,
    required this.actorNickname,
    required this.actorAvatar,
    required this.type,
    this.postId,
    this.commentId,
    this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      actorId: map['actor_id'] ?? '',
      actorUsername: map['actor_username'] ?? '',
      actorNickname: map['actor_nickname'] ?? '',
      actorAvatar: map['actor_avatar'] ?? '',
      type: map['type'] ?? '',
      postId: map['post_id'],
      commentId: map['comment_id'],
      message: map['message'],
      isRead: map['is_read'] ?? false,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'actor_id': actorId,
      'actor_username': actorUsername,
      'actor_nickname': actorNickname,
      'actor_avatar': actorAvatar,
      'type': type,
      'post_id': postId,
      'comment_id': commentId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String getNotificationText() {
    try {
      switch (type) {
        case 'follow':
          return 'started following you';
        case 'follow_request':
          return 'requested to follow you';
        case 'like':
          return 'liked your post';
        case 'comment':
          return 'commented on your post';

        default:
          return 'interacted with you';
      }
    } catch (e) {
      return 'sent a notification';
    }
  }
}

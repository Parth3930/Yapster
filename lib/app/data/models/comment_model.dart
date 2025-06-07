class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String? parentId; // For replies
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Profile data (when fetched with joins)
  final String? username;
  final String? avatar;
  final String? googleAvatar;

  // Metadata for UI state
  final Map<String, dynamic> metadata;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.parentId,
    this.likesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.avatar,
    this.googleAvatar,
    this.metadata = const {},
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    // Handle profile data from join with safe type casting
    Map<String, dynamic>? profiles;
    if (map['profiles'] is Map<String, dynamic>) {
      profiles = map['profiles'] as Map<String, dynamic>;
    } else if (map['profiles'] is Map) {
      profiles = <String, dynamic>{};
      (map['profiles'] as Map).forEach((key, value) {
        profiles![key.toString()] = value;
      });
    }

    return CommentModel(
      id: map['id'] ?? '',
      postId: map['post_id'] ?? '',
      userId: map['user_id'] ?? '',
      content: map['content'] ?? '',
      parentId: map['parent_id'],
      likesCount: map['likes'] ?? 0,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      username: profiles?['username'] ?? map['username'],
      avatar: profiles?['avatar'] ?? map['avatar'],
      googleAvatar: profiles?['google_avatar'] ?? map['google_avatar'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'parent_id': parentId,
      'likes': likesCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? content,
    String? parentId,
    int? likesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? avatar,
    String? googleAvatar,
    Map<String, dynamic>? metadata,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      parentId: parentId ?? this.parentId,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      googleAvatar: googleAvatar ?? this.googleAvatar,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if this comment is a reply to another comment
  bool get isReply => parentId != null;

  /// Check if this comment is liked by current user
  bool get isLiked => metadata['isLiked'] == true;

  @override
  String toString() {
    return 'CommentModel(id: $id, postId: $postId, userId: $userId, content: $content, likesCount: $likesCount, isReply: $isReply)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

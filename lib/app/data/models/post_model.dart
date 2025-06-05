// Post model for Yapster
class PostModel {
  final String id;
  final String userId;
  final String content;
  final String postType;
  final String? imageUrl;
  final String? gifUrl;
  final String? stickerUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int sharesCount;
  final Map<String, dynamic> engagementData;

  // Profile data (when fetched with joins)
  final String? username;
  final String? nickname;
  final String? avatar;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.postType,
    this.imageUrl,
    this.gifUrl,
    this.stickerUrl,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.engagementData = const {},
    this.username,
    this.nickname,
    this.avatar,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      content: map['content'] ?? '',
      postType: map['post_type'] ?? 'text',
      imageUrl: map['image_url'],
      gifUrl: map['gif_url'],
      stickerUrl: map['sticker_url'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      viewsCount: map['views_count'] ?? 0,
      sharesCount: map['shares_count'] ?? 0,
      engagementData: Map<String, dynamic>.from(map['engagement_data'] ?? {}),
      username: map['username'] ?? map['profiles']?['username'],
      nickname: map['nickname'] ?? map['profiles']?['nickname'],
      avatar: map['avatar'] ?? map['profiles']?['avatar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'post_type': postType,
      'image_url': imageUrl,
      'gif_url': gifUrl,
      'sticker_url': stickerUrl,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'views_count': viewsCount,
      'shares_count': sharesCount,
      'engagement_data': engagementData,
    };
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? content,
    String? postType,
    String? imageUrl,
    String? gifUrl,
    String? stickerUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    int? sharesCount,
    Map<String, dynamic>? engagementData,
    String? username,
    String? nickname,
    String? avatar,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      postType: postType ?? this.postType,
      imageUrl: imageUrl ?? this.imageUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      stickerUrl: stickerUrl ?? this.stickerUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      engagementData: engagementData ?? this.engagementData,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
    );
  }
}

// Post model for Yapster
class PostModel {
  final String id;
  final String userId;
  final String content;
  final String postType;
  final String? imageUrl;
  final String? videoUrl;
  final String? gifUrl;
  final String? stickerUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int sharesCount;
  final int starCount;
  final Map<String, dynamic> engagementData;

  // Profile data (when fetched with joins)
  final String? username;
  final String? nickname;
  final String? avatar;
  final String? googleAvatar;
  final bool global;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.postType,
    this.imageUrl,
    this.videoUrl,
    this.gifUrl,
    this.stickerUrl,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.starCount = 0,
    this.engagementData = const {},
    this.username,
    this.nickname,
    this.avatar,
    this.googleAvatar,
    this.global = false,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    // Safe type casting for metadata - ensure it's a mutable map
    Map<String, dynamic> safeMetadata = <String, dynamic>{};
    final metadataValue = map['metadata'];
    if (metadataValue is Map<String, dynamic>) {
      safeMetadata = Map<String, dynamic>.from(metadataValue);
    } else if (metadataValue is Map) {
      metadataValue.forEach((key, value) {
        safeMetadata[key.toString()] = value;
      });
    }

    // Safe type casting for engagement_data - ensure it's a mutable map
    Map<String, dynamic> safeEngagementData = <String, dynamic>{};
    final engagementValue = map['engagement_data'];
    if (engagementValue is Map<String, dynamic>) {
      safeEngagementData = Map<String, dynamic>.from(engagementValue);
    } else if (engagementValue is Map) {
      engagementValue.forEach((key, value) {
        safeEngagementData[key.toString()] = value;
      });
    }

    // Safe access to profiles data
    String? profileUsername;
    String? profileNickname;
    String? profileAvatar;
    String? profileGoogleAvatar;

    final profilesValue = map['profiles'];
    if (profilesValue is Map<String, dynamic>) {
      profileUsername = profilesValue['username'];
      profileNickname = profilesValue['nickname'];
      profileAvatar = profilesValue['avatar'];
      profileGoogleAvatar = profilesValue['google_avatar'];
    } else if (profilesValue is Map) {
      profileUsername = profilesValue['username']?.toString();
      profileNickname = profilesValue['nickname']?.toString();
      profileAvatar = profilesValue['avatar']?.toString();
      profileGoogleAvatar = profilesValue['google_avatar']?.toString();
    }

    return PostModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      content: map['content'] ?? '',
      postType: map['post_type'] ?? 'text',
      imageUrl: map['image_url'],
      videoUrl: map['video_url'],
      gifUrl: map['gif_url'],
      stickerUrl: map['sticker_url'],
      metadata: safeMetadata,
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
      starCount: map['star_count'] ?? 0,
      engagementData: safeEngagementData,
      username: map['username'] ?? profileUsername,
      nickname: map['nickname'] ?? profileNickname,
      avatar: map['avatar'] ?? profileAvatar,
      googleAvatar: map['google_avatar'] ?? profileGoogleAvatar,
      global: map['global'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'post_type': postType,
      'image_url': imageUrl,
      'video_url': videoUrl,
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
      'global': global,
      // Include profile data for proper caching
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'google_avatar': googleAvatar,
    };
  }

  /// Returns only the database fields for insertion (excludes profile data)
  Map<String, dynamic> toDatabaseMap() {
    return {
      'user_id': userId,
      'content': content,
      'post_type': postType,
      'image_url': imageUrl,
      'video_url': videoUrl,
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
      'global': global,
      'is_active': true, // Ensure posts are active by default
      'is_deleted': false, // Ensure posts are not deleted by default
    };
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? content,
    String? postType,
    String? imageUrl,
    String? videoUrl,
    String? gifUrl,
    String? stickerUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    int? sharesCount,
    int? starCount,
    Map<String, dynamic>? engagementData,
    String? username,
    String? nickname,
    String? avatar,
    String? googleAvatar,
    bool? global,
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
      starCount: starCount ?? this.starCount,
      engagementData: engagementData ?? this.engagementData,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      googleAvatar: googleAvatar ?? this.googleAvatar,
      global: global ?? this.global,
    );
  }
}

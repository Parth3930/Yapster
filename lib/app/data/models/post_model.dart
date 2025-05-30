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
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      content: map['content'] ?? '',
      postType: map['post_type'] ?? '',
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
    );
  }
}

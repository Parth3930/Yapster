// Follower model for Yapster
class FollowerModel {
  final String followerId;
  final String createdAt;

  FollowerModel({required this.followerId, required this.createdAt});

  factory FollowerModel.fromMap(Map<String, dynamic> map) {
    return FollowerModel(
      followerId: map['follower_id'] ?? '',
      createdAt: map['created_at'] ?? '',
    );
  }
}

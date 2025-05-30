// User model for Yapster
class UserModel {
  final String id;
  final String username;
  final String nickname;
  final String avatar;
  final String bio;
  final String email;
  final String googleAvatar;

  UserModel({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.bio,
    required this.email,
    required this.googleAvatar,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['user_id'] ?? '',
      username: map['username'] ?? '',
      nickname: map['nickname'] ?? '',
      avatar: map['avatar'] ?? '',
      bio: map['bio'] ?? '',
      email: map['email'] ?? '',
      googleAvatar: map['google_avatar'] ?? '',
    );
  }
}

class FollowRequestModel {
  final String id;
  final String requesterId;
  final String receiverId;
  final String requesterUsername;
  final String requesterNickname;
  final String requesterAvatar;
  final DateTime createdAt;

  FollowRequestModel({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.requesterUsername,
    required this.requesterNickname,
    required this.requesterAvatar,
    required this.createdAt,
  });

  factory FollowRequestModel.fromMap(Map<String, dynamic> map) {
    return FollowRequestModel(
      id: map['id'] ?? '',
      requesterId: map['requester_id'] ?? '',
      receiverId: map['receiver_id'] ?? '',
      requesterUsername: map['requester_username'] ?? '',
      requesterNickname: map['requester_nickname'] ?? '',
      requesterAvatar: map['requester_avatar'] ?? '',
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requester_id': requesterId,
      'receiver_id': receiverId,
      'requester_username': requesterUsername,
      'requester_nickname': requesterNickname,
      'requester_avatar': requesterAvatar,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

import 'dart:convert';

/// Model for group chat with members and settings
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int maxMembers;
  final List<GroupMember> members;
  final GroupSettings settings;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.maxMembers = 100,
    required this.members,
    required this.settings,
  });

  /// Create GroupModel from JSON
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      iconUrl: json['icon_url'],
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      isActive: json['is_active'] ?? true,
      maxMembers: json['max_members'] ?? 100,
      members: _parseMembers(json['members']),
      settings: GroupSettings.fromJson(json['settings'] ?? {}),
    );
  }

  /// Parse members from JSON array
  static List<GroupMember> _parseMembers(dynamic membersJson) {
    if (membersJson == null) return [];
    
    try {
      List<dynamic> membersList;
      if (membersJson is String) {
        membersList = jsonDecode(membersJson);
      } else if (membersJson is List) {
        membersList = membersJson;
      } else {
        return [];
      }
      
      return membersList
          .map((member) => GroupMember.fromJson(member))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
      'max_members': maxMembers,
      'members': jsonEncode(members.map((m) => m.toJson()).toList()),
      'settings': settings.toJson(),
    };
  }

  /// Create a copy with updated fields
  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? maxMembers,
    List<GroupMember>? members,
    GroupSettings? settings,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      maxMembers: maxMembers ?? this.maxMembers,
      members: members ?? this.members,
      settings: settings ?? this.settings,
    );
  }

  /// Get member by user ID
  GroupMember? getMember(String userId) {
    try {
      return members.firstWhere((member) => member.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is admin
  bool isAdmin(String userId) {
    final member = getMember(userId);
    return member?.role == GroupRole.admin;
  }

  /// Check if user is member
  bool isMember(String userId) {
    return getMember(userId) != null;
  }

  /// Get admin members
  List<GroupMember> get admins {
    return members.where((member) => member.role == GroupRole.admin).toList();
  }

  /// Get regular members
  List<GroupMember> get regularMembers {
    return members.where((member) => member.role == GroupRole.member).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Group member model
class GroupMember {
  final String userId;
  final GroupRole role;
  final DateTime joinedAt;
  final String? nickname;

  const GroupMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.nickname,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? '',
      role: GroupRole.fromString(json['role'] ?? 'member'),
      joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
      nickname: json['nickname'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role.value,
      'joined_at': joinedAt.toIso8601String(),
      'nickname': nickname,
    };
  }

  GroupMember copyWith({
    String? userId,
    GroupRole? role,
    DateTime? joinedAt,
    String? nickname,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      nickname: nickname ?? this.nickname,
    );
  }
}

/// Group role enum
enum GroupRole {
  admin('admin'),
  member('member');

  const GroupRole(this.value);
  final String value;

  static GroupRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return GroupRole.admin;
      case 'member':
      default:
        return GroupRole.member;
    }
  }
}

/// Group settings model
class GroupSettings {
  final bool allowMemberInvite;
  final int messageExpiryHours;
  final bool encryptionEnabled;

  const GroupSettings({
    this.allowMemberInvite = true,
    this.messageExpiryHours = 24,
    this.encryptionEnabled = true,
  });

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    return GroupSettings(
      allowMemberInvite: json['allow_member_invite'] ?? true,
      messageExpiryHours: json['message_expiry_hours'] ?? 24,
      encryptionEnabled: json['encryption_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow_member_invite': allowMemberInvite,
      'message_expiry_hours': messageExpiryHours,
      'encryption_enabled': encryptionEnabled,
    };
  }

  GroupSettings copyWith({
    bool? allowMemberInvite,
    int? messageExpiryHours,
    bool? encryptionEnabled,
  }) {
    return GroupSettings(
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
      messageExpiryHours: messageExpiryHours ?? this.messageExpiryHours,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
    );
  }
}

/// Group message model
class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isEncrypted;
  final bool isEdited;
  final DateTime? editedAt;
  final Map<String, DateTime> readBy;

  const GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.createdAt,
    required this.expiresAt,
    this.isEncrypted = true,
    this.isEdited = false,
    this.editedAt,
    required this.readBy,
  });

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupMessageModel(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
      isEncrypted: json['is_encrypted'] ?? true,
      isEdited: json['is_edited'] ?? false,
      editedAt: json['edited_at'] != null 
          ? DateTime.tryParse(json['edited_at']) 
          : null,
      readBy: _parseReadBy(json['read_by']),
    );
  }

  static Map<String, DateTime> _parseReadBy(dynamic readByJson) {
    if (readByJson == null) return {};
    
    try {
      Map<String, dynamic> readByMap;
      if (readByJson is String) {
        readByMap = jsonDecode(readByJson);
      } else if (readByJson is Map<String, dynamic>) {
        readByMap = readByJson;
      } else {
        return {};
      }
      
      return readByMap.map((key, value) => MapEntry(
        key,
        DateTime.tryParse(value.toString()) ?? DateTime.now(),
      ));
    } catch (e) {
      return {};
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_encrypted': isEncrypted,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'read_by': jsonEncode(readBy.map((key, value) => MapEntry(key, value.toIso8601String()))),
    };
  }
}

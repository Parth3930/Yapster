import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/data/models/group_model.dart';
import 'package:yapster/app/startup/preloader/cache_manager.dart';
import 'dart:convert';

class GroupController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  late final EncryptionService _encryptionService;

  // Observable lists
  final RxList<GroupModel> groups = <GroupModel>[].obs;
  final RxList<GroupMessageModel> currentGroupMessages =
      <GroupMessageModel>[].obs;
  final RxString selectedGroupId = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSendingMessage = false.obs;
  final RxString deletingMessageId = ''.obs;
  final RxSet<String> messagesToAnimate = <String>{}.obs;

  // Caching variables
  static final Map<String, Map<String, dynamic>> _groupCache = {};
  static final Map<String, List<GroupMessageModel>> _messagesCache = {};
  static DateTime? _lastGroupFetchTime;
  static DateTime? _lastMessageFetchTime;
  static const Duration _groupCacheDuration = Duration(minutes: 5);
  static const Duration _messageCacheDuration = Duration(minutes: 2);

  @override
  void onInit() {
    super.onInit();
    _initializeEncryption();
    loadUserGroups();
  }

  // Method to call when message bubble animation completes
  void onMessageAnimationComplete(String messageId) {
    messagesToAnimate.remove(messageId);
  }

  Future<void> _initializeEncryption() async {
    try {
      _encryptionService = Get.find<EncryptionService>();
      if (!_encryptionService.isInitialized.value) {
        await _encryptionService.initialize();
      }
    } catch (e) {
      debugPrint('Error initializing encryption service: $e');
    }
  }

  /// Create a new group
  Future<String?> createGroup({
    required String name,
    String? description,
    required List<String> memberIds,
    String? iconUrl,
  }) async {
    try {
      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Add current user as admin to members list
      final members = <Map<String, dynamic>>[];
      members.add({
        'user_id': currentUserId,
        'role': 'admin',
        'joined_at': DateTime.now().toIso8601String(),
        'nickname': '',
      });

      // Add other members
      for (final memberId in memberIds) {
        if (memberId != currentUserId) {
          members.add({
            'user_id': memberId,
            'role': 'member',
            'joined_at': DateTime.now().toIso8601String(),
            'nickname': '',
          });
        }
      }

      // Create group in database
      final response =
          await _supabaseService.client
              .from('groups')
              .insert({
                'name': name,
                'description': description,
                'icon_url': iconUrl,
                'created_by': currentUserId,
                'members': members, // Pass as array directly, not JSON string
                'settings': {
                  'allow_member_invite': true,
                  'message_expiry_hours': 24,
                  'encryption_enabled': true,
                }, // Pass as object directly, not JSON string
              })
              .select()
              .single();

      final groupId = response['id'] as String;

      // Reload user groups to include the new group
      await loadUserGroups();

      return groupId;
    } catch (e) {
      debugPrint('Error creating group: $e');
      return null;
    }
  }

  /// Load user's groups with enhanced persistent caching
  Future<void> loadUserGroups({bool forceRefresh = false}) async {
    try {
      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final cacheManager = Get.find<CacheManager>();

      // First try to get from persistent cache
      if (!forceRefresh) {
        final cachedGroups = await cacheManager.getCachedGroupsData(
          currentUserId,
        );
        if (cachedGroups != null) {
          final groupModels =
              cachedGroups.map((g) => GroupModel.fromJson(g)).toList();
          groups.assignAll(groupModels);
          groups.refresh();
          debugPrint('Loaded ${groups.length} groups from persistent cache');
          return;
        }
      }

      // Check in-memory cache first if not forcing refresh
      if (!forceRefresh && _shouldUseCachedGroups(currentUserId)) {
        debugPrint('Using in-memory cached groups data');
        _loadGroupsFromCache(currentUserId);
        return;
      }

      isLoading.value = true;
      debugPrint('Fetching groups from database');

      final response = await _supabaseService.client.rpc(
        'get_user_groups',
        params: {'input_user_uuid': currentUserId},
      );

      groups.clear();
      final List<GroupModel> loadedGroups = [];

      if (response != null && response is List) {
        for (final groupData in response) {
          try {
            // Fetch full group details
            final groupResponse =
                await _supabaseService.client
                    .from('groups')
                    .select()
                    .eq('id', groupData['group_id'])
                    .single();

            final group = GroupModel.fromJson(groupResponse);
            loadedGroups.add(group);
          } catch (e) {
            debugPrint('Error parsing group: $e');
          }
        }
      }

      // Update in-memory cache
      _updateGroupsCache(currentUserId, loadedGroups);

      // Update persistent cache
      final groupsJson = loadedGroups.map((g) => g.toJson()).toList();
      await cacheManager.cacheGroupsData(currentUserId, groupsJson);

      // Update UI
      groups.assignAll(loadedGroups);
      groups.refresh();

      debugPrint('Loaded ${loadedGroups.length} groups');
    } catch (e) {
      debugPrint('Error loading user groups: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if we should use cached groups
  bool _shouldUseCachedGroups(String userId) {
    if (!_groupCache.containsKey(userId)) return false;

    final cacheData = _groupCache[userId]!;
    final cacheTime = DateTime.tryParse(cacheData['timestamp'] ?? '');

    if (cacheTime == null) return false;

    final isExpired =
        DateTime.now().difference(cacheTime) > _groupCacheDuration;
    return !isExpired && groups.isNotEmpty;
  }

  /// Load groups from cache
  void _loadGroupsFromCache(String userId) {
    final cacheData = _groupCache[userId];
    if (cacheData != null && cacheData['groups'] != null) {
      final cachedGroups =
          (cacheData['groups'] as List)
              .map((g) => GroupModel.fromJson(g))
              .toList();
      groups.assignAll(cachedGroups);
      groups.refresh();
    }
  }

  /// Update groups cache
  void _updateGroupsCache(String userId, List<GroupModel> groupsList) {
    _groupCache[userId] = {
      'groups': groupsList.map((g) => g.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    _lastGroupFetchTime = DateTime.now();
  }

  /// Load messages for a specific group with caching
  Future<void> loadGroupMessages(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    try {
      selectedGroupId.value = groupId;

      // Check cache first if not forcing refresh
      if (!forceRefresh && _shouldUseCachedMessages(groupId)) {
        debugPrint('Using cached messages for group $groupId');
        _loadMessagesFromCache(groupId);
        return;
      }

      debugPrint('Fetching messages from database for group $groupId');
      currentGroupMessages.clear();

      final response = await _supabaseService.client
          .from('group_messages')
          .select()
          .eq('group_id', groupId)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: true);

      final List<GroupMessageModel> loadedMessages = [];

      for (final messageData in response) {
        try {
          final message = GroupMessageModel.fromJson(messageData);

          // Decrypt message if encrypted
          if (message.isEncrypted && _encryptionService.isInitialized.value) {
            final decryptedContent = await _encryptionService
                .decryptMessageForChat(message.content, groupId);

            final decryptedMessage = GroupMessageModel(
              id: message.id,
              groupId: message.groupId,
              senderId: message.senderId,
              content: decryptedContent,
              messageType: message.messageType,
              createdAt: message.createdAt,
              expiresAt: message.expiresAt,
              isEncrypted: message.isEncrypted,
              isEdited: message.isEdited,
              editedAt: message.editedAt,
              readBy: message.readBy,
            );

            loadedMessages.add(decryptedMessage);
          } else {
            loadedMessages.add(message);
          }
        } catch (e) {
          debugPrint('Error processing group message: $e');
        }
      }

      // Update cache
      _updateMessagesCache(groupId, loadedMessages);

      // Update UI
      currentGroupMessages.assignAll(loadedMessages);
      currentGroupMessages.refresh();

      debugPrint('Loaded ${loadedMessages.length} messages for group $groupId');
    } catch (e) {
      debugPrint('Error loading group messages: $e');
    }
  }

  /// Check if we should use cached messages
  bool _shouldUseCachedMessages(String groupId) {
    if (!_messagesCache.containsKey(groupId)) return false;

    // For messages, we use a shorter cache duration for real-time feel
    final cacheTime = _lastMessageFetchTime;
    if (cacheTime == null) return false;

    final isExpired =
        DateTime.now().difference(cacheTime) > _messageCacheDuration;
    return !isExpired;
  }

  /// Load messages from cache
  void _loadMessagesFromCache(String groupId) {
    final cachedMessages = _messagesCache[groupId];
    if (cachedMessages != null) {
      currentGroupMessages.assignAll(cachedMessages);
      currentGroupMessages.refresh();
    }
  }

  /// Update messages cache
  void _updateMessagesCache(
    String groupId,
    List<GroupMessageModel> messagesList,
  ) {
    _messagesCache[groupId] = List.from(messagesList);
    _lastMessageFetchTime = DateTime.now();
  }

  /// Send a message to a group
  Future<void> sendGroupMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      isSendingMessage.value = true;

      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Encrypt message content
      String encryptedContent = content;
      if (_encryptionService.isInitialized.value) {
        encryptedContent = await _encryptionService.encryptMessageForChat(
          content,
          groupId,
        );
      }

      // Calculate expiry time (24 hours from now)
      final expiresAt = DateTime.now().add(Duration(hours: 24));

      // Insert message into database
      final response =
          await _supabaseService.client
              .from('group_messages')
              .insert({
                'group_id': groupId,
                'sender_id': currentUserId,
                'content': encryptedContent,
                'message_type': messageType,
                'expires_at': expiresAt.toIso8601String(),
                'is_encrypted': _encryptionService.isInitialized.value,
              })
              .select()
              .single();

      // Add message to local list
      final message = GroupMessageModel.fromJson(response);

      // Use original content for local display (already decrypted)
      final localMessage = GroupMessageModel(
        id: message.id,
        groupId: message.groupId,
        senderId: message.senderId,
        content: content, // Use original unencrypted content
        messageType: message.messageType,
        createdAt: message.createdAt,
        expiresAt: message.expiresAt,
        isEncrypted: message.isEncrypted,
        isEdited: message.isEdited,
        editedAt: message.editedAt,
        readBy: message.readBy,
      );

      currentGroupMessages.add(localMessage);
      messagesToAnimate.add(localMessage.id);
      currentGroupMessages.refresh();
    } catch (e) {
      debugPrint('Error sending group message: $e');
      Get.snackbar('Error', 'Failed to send message');
    } finally {
      isSendingMessage.value = false;
    }
  }

  /// Update a group message
  Future<void> updateGroupMessage(
    String groupId,
    String messageId,
    String newContent,
  ) async {
    try {
      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Encrypt new content
      String encryptedContent = newContent;
      if (_encryptionService.isInitialized.value) {
        encryptedContent = await _encryptionService.encryptMessageForChat(
          newContent,
          groupId,
        );
      }

      await _supabaseService.client
          .from('group_messages')
          .update({
            'content': encryptedContent,
            'is_edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', currentUserId);

      // Reload messages to reflect changes
      await loadGroupMessages(groupId);
    } catch (e) {
      debugPrint('Error updating group message: $e');
      rethrow;
    }
  }

  /// Delete a group message
  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    try {
      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _supabaseService.client
          .from('group_messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', currentUserId);

      // Remove from local list
      currentGroupMessages.removeWhere((msg) => msg.id == messageId);

      // Clear deleting state
      deletingMessageId.value = '';
    } catch (e) {
      debugPrint('Error deleting group message: $e');
      deletingMessageId.value = '';
      rethrow;
    }
  }

  /// Add member to group
  Future<bool> addMemberToGroup(String groupId, String userId) async {
    try {
      final result = await _supabaseService.client.rpc(
        'add_group_member',
        params: {
          'group_uuid': groupId,
          'user_uuid': userId,
          'user_role': 'member',
        },
      );

      if (result == true) {
        // Reload groups to update member list
        await loadUserGroups();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding member to group: $e');
      return false;
    }
  }

  /// Remove member from group
  Future<bool> removeMemberFromGroup(String groupId, String userId) async {
    try {
      final result = await _supabaseService.client.rpc(
        'remove_group_member',
        params: {'group_uuid': groupId, 'user_uuid': userId},
      );

      if (result == true) {
        // Reload groups to update member list
        await loadUserGroups();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error removing member from group: $e');
      return false;
    }
  }

  /// Update group settings
  Future<bool> updateGroupSettings(
    String groupId,
    GroupSettings settings,
  ) async {
    try {
      await _supabaseService.client
          .from('groups')
          .update({
            'settings': jsonEncode(settings.toJson()),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', groupId);

      // Reload groups to update settings
      await loadUserGroups();
      return true;
    } catch (e) {
      debugPrint('Error updating group settings: $e');
      return false;
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId, String groupId) async {
    try {
      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Update read status in database
      await _supabaseService.client
          .from('group_messages')
          .update({
            'read_by': {currentUserId: DateTime.now().toIso8601String()},
          })
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Get group by ID
  GroupModel? getGroupById(String groupId) {
    try {
      return groups.firstWhere((group) => group.id == groupId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is admin of group
  bool isUserAdmin(String groupId, String userId) {
    final group = getGroupById(groupId);
    return group?.isAdmin(userId) ?? false;
  }
}

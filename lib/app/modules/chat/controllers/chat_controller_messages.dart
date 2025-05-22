import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../services/chat_message_service.dart';

mixin ChatControllerMessages {
  // Initializes the chat controller
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  // Chat controller service initialize it
  ChatController get _chatControler => Get.find<ChatController>();
  RealtimeChannel? _messageSubscription;

  Future<void> syncMessagesWithDatabase(String chatId) async {
    final supabase = Get.find<SupabaseService>().client;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      // Fetch current messages from database
      final response = await supabase
          .from('messages')
          .select('message_id')
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso);

      final dbMessageIds = response.map((msg) => msg['message_id']).toSet();

      // Remove messages that no longer exist in database
      _chatControler.messages.removeWhere(
        (message) => !dbMessageIds.contains(message.messageId),
      );

      debugPrint('Synced messages with database');
    } catch (e) {
      debugPrint('Error syncing messages: $e');
    }
  }

  // Loads messages for a conversation
  Future<void> loadMessages(String chatId) async {
    final supabase = Get.find<SupabaseService>().client;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    debugPrint('Loading messages... $chatId');
    try {
      // Cancel any previous real-time message subscription
      await _messageSubscription?.unsubscribe();
      _messageSubscription = null;

      // 1. Fetch existing (non-expired) messages
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      _chatControler.messages.clear();
      if (response.isNotEmpty) {
        final loadedMessages =
            response
                .map<MessageModel>((msg) => MessageModel.fromJson(msg))
                .toList();

        _chatControler.messages.assignAll(loadedMessages);
      }

      // 2. Set up real-time subscription for INSERT, UPDATE, DELETE
      _messageSubscription =
          supabase
              .channel('public:messages')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'messages',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'chat_id',
                  value: chatId,
                ),
                callback: (payload) {
                  final msgMap = payload.newRecord;
                  final message = MessageModel.fromJson(msgMap);
                  final now = DateTime.now().toUtc();

                  if (message.expiresAt.isAfter(now)) {
                    if (!_chatControler.messages.any(
                      (m) => m.messageId == message.messageId,
                    )) {
                      _chatControler.messages.add(message);
                      _chatControler.messagesToAnimate.add(message.messageId);
                    }
                  }
                  _cleanupExpiredMessages();
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'messages',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'chat_id',
                  value: chatId,
                ),
                callback: (payload) {
                  final msgMap = payload.newRecord;
                  final message = MessageModel.fromJson(msgMap);
                  final index = _chatControler.messages.indexWhere(
                    (m) => m.messageId == message.messageId,
                  );
                  if (index != -1) {
                    _chatControler.messages[index] = message;
                  }
                  _cleanupExpiredMessages();
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'messages',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'chat_id',
                  value: chatId,
                ),
                callback: (payload) {
                  debugPrint('DELETE event received: ${payload.oldRecord}');
                  final oldMap = payload.oldRecord;
                  final messageId = oldMap['message_id'];
                  debugPrint('Removing message with ID: $messageId');

                  final initialLength = _chatControler.messages.length;
                  _chatControler.messages.removeWhere(
                    (m) => m.messageId == messageId,
                  );
                  final finalLength = _chatControler.messages.length;

                  debugPrint('Messages count: $initialLength -> $finalLength');
                  _chatControler.messagesToAnimate.remove(messageId);
                  _cleanupExpiredMessages();
                },
              )
              .subscribe();

      debugPrint(
        'Messages loaded successfully ${_chatControler.messages.length}',
      );
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  void _cleanupExpiredMessages() {
    final now = DateTime.now().toUtc();
    _chatControler.messages.removeWhere((m) => m.expiresAt.isBefore(now));
    _chatControler.messagesToAnimate.removeWhere(
      (id) => !_chatControler.messages.any((m) => m.messageId == id),
    );
    _chatControler.messages.refresh(); // ✅ Correct usage
  }

  Future<void> fetchUsersRecentChats() async {
    final userId = _supabaseService.client.auth.currentUser?.id;
    _chatControler.isLoadingChats.value = true;

    if (userId == null) {
      debugPrint('User not logged in');
      _chatControler.isLoadingChats.value = false;
      return;
    }

    try {
      final List<dynamic> chats = await _supabaseService.client.rpc(
        'fetch_users_recent_chats',
        params: {'user_uuid': userId},
      );

      if (chats.isEmpty) {
        debugPrint('No recent chats found.');
        _chatControler.recentChats.clear();
        return;
      }

      // Log and process each chat
      for (final chat in chats) {
        debugPrint('Chat: $chat');
      }

      _chatControler.recentChats.assignAll(chats.cast<Map<String, dynamic>>());

      debugPrint(
        'Recent chats fetched successfully: ${_chatControler.recentChats}',
      );
    } catch (e) {
      debugPrint('Error fetching chats: $e');
    } finally {
      _chatControler.isLoadingChats.value = false;
    }
  }

  // Sends a chat message
  Future<void> sendChatMessage(String chatId, String content) async {
    await Get.find<ChatMessageService>().sendMessage(
      chatId,
      content,
      _chatControler.messageController,
    );
  }

  // Picks and sends an image
  Future<void> pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      await uploadAndSendImage(_chatControler.selectedChatId.value, image);
    }
  }

  // Records and sends audio (stub)
  Future<void> recordAndSendAudio() async {
    throw UnimplementedError('Audio recording not implemented');
  }

  // Handles deleting a message
  Future<void> handleDeleteMessage(String messageId) async {
    final chatId = _chatControler.selectedChatId.value;
    await _chatControler.deleteMessage(chatId, messageId);
  }

  // Forces decryption of all messages (stub)
  Future<void> forceDecryptMessages() async {
    throw UnimplementedError('Force decrypt not implemented');
  }

  // Gets decrypted message content
  Future<String> getDecryptedMessageContent(
    Map<String, dynamic> message,
  ) async {
    return message['content']?.toString() ?? '';
  }

  // opens chat window
  Future<void> openChat(String userTwoId, String username) async {
    final supabaseService = Get.find<SupabaseService>();
    final currentUserId = supabaseService.client.auth.currentUser?.id;

    if (currentUserId == null) {
      debugPrint('User not logged in');
      return;
    }

    try {
      // Call the RPC to get or create a chat_id connecting both users
      final chatId = await supabaseService.client.rpc(
        'user_chat_connect',
        params: {'user_one': currentUserId, 'user_two': userTwoId},
      );

      // chatId is expected to be a String UUID or null
      if (chatId != null && (chatId is String) && chatId.isNotEmpty) {
        // Navigate to the chat detail screen with chatId and username
        Get.toNamed(
          Routes.CHAT_WINDOW,
          arguments: {
            'chatId': chatId,
            'username': username,
            'otherUserId': userTwoId,
          },
        );
      } else {
        debugPrint('Chat ID not found in response');
      }
    } catch (e) {
      debugPrint('Failed to connect/open chat: $e');
    }
  }

  // Updates a message (stub)
  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    // Example: Call a service to update the message content in the backend.
    throw UnimplementedError('Update message not implemented');
  }

  // Uploads and sends an image
  Future<void> uploadAndSendImage(String chatId, XFile image) async {
    await Get.find<ChatMessageService>().uploadAndSendImage(chatId, image);
  }

  // Sends a voice message (stub)
  Future<void> sendVoiceMessage(String chatId) async {
    // Implement voice message sending logic here
    throw UnimplementedError('Voice message sending not implemented');
  }

  // Marks all messages as read in a chat
  Future<void> markMessagesAsRead(String chatId) async {
    await Get.find<ChatMessageService>().markMessagesAsRead(chatId);
  }

  // Example: Edit a message (stub)
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    // Example: Call a service to edit the message content in the backend.
    throw UnimplementedError('Edit message not implemented');
  }
}

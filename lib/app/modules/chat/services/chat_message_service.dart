import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';

/// Service for handling message operations in chats
class ChatMessageService extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  // Track processed message IDs to prevent duplication
  final RxSet<String> _processedMessageIds = <String>{}.obs;
  // Observable message list
  late RxList<MessageModel> messages = <MessageModel>[].obs;
  // Observable chats list
  late RxList<Map<String, dynamic>> recentChats;
  // Media upload progress
  late RxMap<String, double> localUploadProgress;
  ChatController get controller => Get.find<ChatController>();

  /// Initialize the service with observable lists
  void initialize({
    required RxList<MessageModel> messagesList,
    required RxList<Map<String, dynamic>> chatsList,
    required RxMap<String, double> uploadProgress,
  }) {
    messages = messagesList;
    recentChats = chatsList;
    localUploadProgress = uploadProgress;
    _processedMessageIds.clear();
  }

  Future<void> loadMessages(String chatId) async {
    final supabase = Get.find<SupabaseService>().client;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    debugPrint('loading messages... $chatId');
    try {
      // 1. Fetch old (non-expired) messages
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      if (response.isNotEmpty) {
        final loadedMessages =
            response
                .map<MessageModel>((msg) => MessageModel.fromJson(msg))
                .toList();

        // Directly assign List<MessageModel> to observable list
        messages.assignAll(loadedMessages);
        // Do NOT add loaded messages to messagesToAnimate
      }

      // 2. Listen for new messages in realtime where expires_at > now
      supabase
          .from('messages')
          .stream(primaryKey: ['message_id'])
          .eq('chat_id', chatId)
          .listen((List<Map<String, dynamic>> data) {
            final now = DateTime.now().toUtc();

            for (var msgMap in data) {
              // Convert the incoming map data to MessageModel
              final message = MessageModel.fromJson(msgMap);

              // Check if message is not expired
              if (message.expiresAt.isAfter(now)) {
                // If message not already in list, add it
                if (!messages.any((m) => m.messageId == message.messageId)) {
                  messages.add(message);
                  // Add new message ID to the set to trigger animation
                  controller.messagesToAnimate.add(message.messageId);
                } else {
                  // If message exists, update it (e.g., is_read status)
                  final index = messages.indexWhere(
                    (m) => m.messageId == message.messageId,
                  );
                  if (index != -1) {
                    messages[index] = message;
                  }
                }
              } else {
                // If message expired and still in list, remove it
                messages.removeWhere((m) => m.messageId == message.messageId);
                // Also remove from animation set if it was there
                controller.messagesToAnimate.remove(message.messageId);
              }
            }

            // Also clean up any expired messages in the list on each update
            messages.removeWhere(
              (m) => m.expiresAt.isBefore(DateTime.now().toUtc()),
            );
            // Clean up expired messages from animation set as well
            controller.messagesToAnimate.removeWhere(
              (id) => !messages.any((m) => m.messageId == id),
            );
          });

      debugPrint('Messages loaded successfully ${messages.length}');
      controller.messages = messages;
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> sendMessage(
    String chatId,
    String content,
    TextEditingController messageController,
  ) async {
    final user = _supabaseService.client.auth.currentUser;

    if (user == null) {
      debugPrint('User not authenticated');
      return;
    }

    if (content.trim().isEmpty) {
      debugPrint('Cannot send empty message');
      return;
    }

    try {
      final senderId = user.id;
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(hours: 24));

      // Optional: Define a default message type (e.g., "text")
      const messageType = 'text';

      // You might already know the recipientId; otherwise, you'll need to fetch it based on the chatId
      final chat =
          await _supabaseService.client
              .from('chats')
              .select('user_one_id, user_two_id')
              .eq('chat_id', chatId)
              .maybeSingle();

      if (chat == null) {
        debugPrint('Chat not found');
        return;
      }

      // Determine recipient ID based on who the sender is
      final recipientId =
          chat['user_one_id'] == senderId
              ? chat['user_two_id']
              : chat['user_one_id'];

      // Insert the message
      final response =
          await _supabaseService.client.from('messages').insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'recipient_id': recipientId,
            'content': content.trim(),
            'message_type': messageType,
            'expires_at': expiresAt.toIso8601String(),
            'is_read': false,
          }).select();

      if (response.isEmpty) {
        debugPrint('Message insert failed');
        return;
      }

      debugPrint('Message sent: $response');

      // Assuming the response contains the inserted message with message_id
      final sentMessage = MessageModel.fromJson(response.first);
      // Add the sent message ID to the set to trigger animation
      controller.messagesToAnimate.add(sentMessage.messageId);

      // Clear the text input
      messageController.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Upload and send image
  Future<void> uploadAndSendImage(String chatId, XFile image) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
    } catch (e) {}
  }

  /// Send sticker message
  Future<void> sendSticker(String chatId, String stickerId) async {
    try {} catch (e) {
      debugPrint('Error sending sticker: $e');
      Get.snackbar('Error', 'Could not send sticker');
    }
  }

  /// Mark all messages in a chat as read - Optimized implementation
  Future<void> markMessagesAsRead(String chatId) async {
    try {} catch (e) {
      debugPrint('Error in markMessagesAsRead: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import 'dart:async';

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
  StreamSubscription? _messageSubscription;

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
      // Cancel any previous real-time message subscription
      await _messageSubscription?.cancel();
      _messageSubscription = null;

      // 1. Fetch old (non-expired) messages
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      // Clear the local message list before assigning new messages
      messages.clear();
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
      _messageSubscription = supabase
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

            // Force UI update after any change
            controller.messages = messages;
            messages.refresh();
          });

      debugPrint('Messages loaded successfully ${messages.length}');
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
      // Optionally, force a UI update if needed
      messages.refresh();

      // Clear the text input
      messageController.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Upload and send image
  Future<void> uploadAndSendImage(String chatId, XFile image) async {
    final user = _supabaseService.client.auth.currentUser;

    if (user == null) {
      debugPrint('User not authenticated');
      return;
    }

    try {
      final senderId = user.id;
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(hours: 24));
      const messageType = 'image';

      // Fetch recipient ID based on the chat
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

      final recipientId =
          chat['user_one_id'] == senderId
              ? chat['user_two_id']
              : chat['user_one_id'];

      // Upload image to storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final storagePath = '$chatId/$fileName';

      final fileBytes = await image.readAsBytes();

      final uploadResponse = await _supabaseService.client.storage
          .from('chat-media')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/${image.name.split('.').last}',
              metadata: {'chat_id': chatId},
            ),
          );

      if (uploadResponse.isEmpty) {
        debugPrint('Image upload failed');
        return;
      }

      // Get public URL or use the path as content
      final imageUrl = _supabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(storagePath);

      // Insert image message
      final response =
          await _supabaseService.client.from('messages').insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'recipient_id': recipientId,
            'content': imageUrl,
            'message_type': messageType,
            'expires_at': expiresAt.toIso8601String(),
            'is_read': false,
          }).select();

      if (response.isEmpty) {
        debugPrint('Image message insert failed');
        return;
      }

      final sentMessage = MessageModel.fromJson(response.first);

      controller.messagesToAnimate.add(sentMessage.messageId);
      messages.refresh();

      debugPrint('Image sent as message: $imageUrl');
    } catch (e) {
      debugPrint('Error uploading/sending image: $e');
    }
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

  /// Unified send message function for text, image, and audio
  Future<void> sendMessageUnified({
    required String chatId,
    String? text,
    XFile? image,
    String? audioPath,
    Duration? audioDuration, // Kept for API compatibility, but not used
    TextEditingController? messageController,
  }) async {
    final user = _supabaseService.client.auth.currentUser;
    if (user == null) {
      debugPrint('User not authenticated');
      return;
    }
    final senderId = user.id;
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(hours: 24));

    // Fetch recipient ID based on the chat
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
    final recipientId =
        chat['user_one_id'] == senderId
            ? chat['user_two_id']
            : chat['user_one_id'];

    String? content;
    String messageType = 'text';
    // No extraFields needed since duration is not stored

    if (image != null) {
      // Handle image upload
      messageType = 'image';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final storagePath = '$chatId/$fileName';
      final fileBytes = await image.readAsBytes();
      final uploadResponse = await _supabaseService.client.storage
          .from('chat-media')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/${image.name.split('.').last}',
              metadata: {'chat_id': chatId},
            ),
          );
      if (uploadResponse.isEmpty) {
        debugPrint('Image upload failed');
        return;
      }
      content = _supabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(storagePath);
    } else if (audioPath != null) {
      // Handle audio upload
      messageType = 'audio';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storagePath = '$chatId/$fileName';
      final file = await XFile(audioPath).readAsBytes();
      final uploadResponse = await _supabaseService.client.storage
          .from('chat-media')
          .uploadBinary(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: 'audio/m4a',
              metadata: {'chat_id': chatId},
            ),
          );
      if (uploadResponse.isEmpty) {
        debugPrint('Audio upload failed');
        return;
      }
      content = _supabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(storagePath);
      // No duration field added
    } else if (text != null && text.trim().isNotEmpty) {
      content = text.trim();
      messageType = 'text';
    } else {
      debugPrint('No valid message content to send');
      return;
    }

    // Insert the message
    final response =
        await _supabaseService.client.from('messages').insert({
          'chat_id': chatId,
          'sender_id': senderId,
          'recipient_id': recipientId,
          'content': content,
          'message_type': messageType,
          'expires_at': expiresAt.toIso8601String(),
          'is_read': false,
        }).select();

    if (response.isEmpty) {
      debugPrint('Message insert failed');
      return;
    }
    final sentMessage = MessageModel.fromJson(response.first);
    controller.messagesToAnimate.add(sentMessage.messageId);
    messages.refresh();
    if (messageController != null) messageController.clear();
    debugPrint('Unified message sent: $messageType');
  }
}

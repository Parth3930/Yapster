import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../services/chat_message_service.dart';

mixin ChatControllerMessages {
  // Initializes the chat controller
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  // Chat controller service initialize it
  ChatController get _chatControler => Get.find<ChatController>();
  // Loads messages for a conversation
  Future<void> loadMessages(
    String conversationId, {
    bool refreshing = false,
  }) async {
    await Get.find<ChatMessageService>().loadMessages(conversationId);
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
        debugPrint('Chat ID: ${chat['chat_id']}');
        debugPrint('User One ID: ${chat['user_one_id']}');
        debugPrint('User Two ID: ${chat['user_two_id']}');
        debugPrint('Created At: ${chat['created_at']}');
        debugPrint('User Two Username: ${chat['other_username']}');
        debugPrint('User Two Avatar: ${chat['other_avatar']}');
        debugPrint('User Two Google Avatar: ${chat['other_google_avatar']}');
        debugPrint('---');
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

  // --- Additional message-related functions for completeness ---

  // Example: Edit a message (stub)
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    // Example: Call a service to edit the message content in the backend.
    throw UnimplementedError('Edit message not implemented');
  }

  // Example: Reply to a message (stub)
  Future<void> replyToMessage(
    String chatId,
    String messageId,
    String replyContent,
  ) async {
    // Example: Call a service to send a reply message.
    throw UnimplementedError('Reply to message not implemented');
  }

  // Example: Forward a message (stub)
  Future<void> forwardMessage(
    String chatId,
    String messageId,
    String targetChatId,
  ) async {
    // Example: Call a service to forward the message to another chat.
    throw UnimplementedError('Forward message not implemented');
  }

  // Example: Star a message (stub)
  Future<void> starMessage(String chatId, String messageId) async {
    // Example: Call a service to star the message.
    throw UnimplementedError('Star message not implemented');
  }

  // Example: Unstar a message (stub)
  Future<void> unstarMessage(String chatId, String messageId) async {
    // Example: Call a service to unstar the message.
    throw UnimplementedError('Unstar message not implemented');
  }

  // Example: Delete all messages in a chat (stub)
  Future<void> deleteAllMessages(String chatId) async {
    // Example: Call a service to delete all messages in a chat.
    throw UnimplementedError('Delete all messages not implemented');
  }
}

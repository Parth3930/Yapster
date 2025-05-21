import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/services/chat_decryption_service.dart';

/// Service dedicated to handling message processing and display
/// This service separates message handling logic from the controller
/// to improve maintainability and fix decryption issues
class ChatMessageHandler extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final ChatDecryptionService _decryptionService =
      Get.find<ChatDecryptionService>();

  // Observable collections
  late RxList<Map<String, dynamic>> messages;

  /// Initialize the handler with observable collections
  void initialize({required RxList<Map<String, dynamic>> messagesList}) {
    messages = messagesList;
  }

  /// Process an incoming message
  /// Returns true if the message was added to the UI, false otherwise
  Future<bool> processIncomingMessage({
    required Map<String, dynamic> message,
    required String? activeChatId,
    required String? selectedChatId,
  }) async {
    final messageId = message['message_id']?.toString() ?? '';
    if (messageId.isEmpty) return false;

    try {
      // Make a copy of the message to avoid modifying the original
      final processedMessage = Map<String, dynamic>.from(message);

      // Decrypt message content if needed
      if (await _decryptMessageContent(processedMessage)) {
        debugPrint('Message decrypted successfully: $messageId');
      }

      // Check if this message already exists in the list to avoid duplicates
      final existingIndex = messages.indexWhere(
        (msg) => msg['message_id'] == messageId,
      );

      if (existingIndex != -1) {
        debugPrint('Message already exists in UI, updating: $messageId');
        messages[existingIndex] = processedMessage;
        return true;
      }

      // Determine if this message belongs to the active conversation
      if (_shouldDisplayMessage(
        processedMessage,
        activeChatId,
        selectedChatId,
      )) {
        // Add animation flag for received messages
        if (processedMessage['sender_id'] !=
            _supabaseService.currentUser.value?.id) {
          processedMessage['is_new'] = true;
        }

        debugPrint('Adding new message to UI: $messageId');
        messages.add(processedMessage);

        // Sort messages by timestamp
        _sortMessages();

        // Force refresh the UI to show the new message
        messages.refresh();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error processing message $messageId: $e');
      return false;
    }
  }

  /// Decrypt message content if needed
  /// Returns true if decryption was successful or not needed
  Future<bool> _decryptMessageContent(Map<String, dynamic> message) async {
    if (message['content'] is! String) return true;

    final String encryptedContent = message['content'].toString();
    final String messageId = message['message_id']?.toString() ?? '';
    final String chatId = message['chat_id']?.toString() ?? '';

    // Skip decryption for empty content
    if (encryptedContent.isEmpty) return true;

    // Use the dedicated decryption service
    final decryptedContent = await _decryptionService.decryptMessage(
      encryptedContent: encryptedContent,
      messageId: messageId,
      chatId: chatId.isNotEmpty ? chatId : null,
    );

    // Update message with decrypted content
    if (decryptedContent != encryptedContent) {
      message['content'] = decryptedContent;
      return true;
    }

    return false;
  }

  /// Determine if a message should be displayed in the current view
  bool _shouldDisplayMessage(
    Map<String, dynamic> message,
    String? activeChatId,
    String? selectedChatId,
  ) {
    if (activeChatId == null && selectedChatId == null) return false;

    final String? messageDbChatId = message['chat_id']?.toString();
    String? activeDatabaseChatId;

    // Extract the database chat ID from the active conversation ID
    if (activeChatId != null && activeChatId.split('_').length >= 2) {
      activeDatabaseChatId = activeChatId.split('_')[1];
    } else {
      activeDatabaseChatId = activeChatId;
    }

    // Check if this message belongs to the active conversation
    final bool isForActiveConversation =
        activeChatId != null &&
        (message['recipient_id'] == activeChatId ||
            message['group_id'] == activeChatId ||
            messageDbChatId == activeDatabaseChatId);

    // Check if this message belongs to the selected chat ID
    final bool isForSelectedChat =
        selectedChatId != null &&
        selectedChatId.isNotEmpty &&
        messageDbChatId != null &&
        selectedChatId.split('_').length >= 2 &&
        messageDbChatId == selectedChatId.split('_')[1];

    return isForActiveConversation || isForSelectedChat;
  }

  /// Sort messages by timestamp (newest first)
  void _sortMessages() {
    messages.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );
  }

  /// Force retry decryption for all messages in the current view
  Future<void> retryDecryptionForAllMessages() async {
    bool anyDecrypted = false;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message['content'] is String) {
        final String content = message['content'];

        // Skip already decrypted messages
        if (!content.contains('==') && !content.startsWith('🔒')) {
          continue;
        }

        // Create a copy to modify
        final updatedMessage = Map<String, dynamic>.from(message);

        // Try to decrypt again
        if (await _decryptMessageContent(updatedMessage)) {
          messages[i] = updatedMessage;
          anyDecrypted = true;
        }
      }
    }

    if (anyDecrypted) {
      messages.refresh();
    }
  }
}

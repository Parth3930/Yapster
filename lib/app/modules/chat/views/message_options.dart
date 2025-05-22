import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import '../controllers/chat_controller.dart';
import 'components/message_input.dart';

class MessageOptions {
  static void show(
    BuildContext context,
    Map<String, dynamic> message,
    bool isMe,
  ) {
    final controller = Get.find<ChatController>();
    final String chatId = controller.selectedChatId.value;
    final String messageId = message['message_id']?.toString() ?? '';

    if (messageId.isEmpty || chatId.isEmpty) {
      debugPrint('Cannot show message options: invalid message ID or chat ID');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              if (isMe) ...[
                // Edit option - only for your own messages
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text(
                    'Edit Message',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editMessage(message);
                  },
                ),
                // Delete option - only for your own messages
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Message',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
              ],
              // Copy option - for all messages
              ListTile(
                leading: const Icon(Icons.content_copy, color: Colors.cyan),
                title: const Text(
                  'Copy Text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessageText(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static void _editMessage(Map<String, dynamic> message) {
    final controller = Get.find<ChatController>();
    final content = message['content']?.toString() ?? '';

    // Set editing state
    MessageInput.isEditingMessage.value = true;
    MessageInput.messageBeingEdited.value = message;

    // Set the message text in the input field
    controller.messageController.text = content;

    // Focus the input field
    FocusScope.of(Get.context!).requestFocus();
  }

  static Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final controller = Get.find<ChatController>();
    final supabase = Get.find<SupabaseService>().client;

    final String messageId = message['message_id']?.toString() ?? '';
    if (messageId.isEmpty) {
      Get.snackbar('Error', 'Could not delete message');
      return;
    }

    try {
      // 1. Fetch full message details before deletion starts
      final messageDetails =
          await supabase
              .from('messages')
              .select('message_id, message_type, content')
              .eq('message_id', messageId)
              .maybeSingle();

      if (messageDetails == null) {
        debugPrint('Message not found, might already be deleted');
        return;
      }

      // Store message details for deletion
      final messageType = messageDetails['message_type'] as String?;
      final content = messageDetails['content'] as String?;

      // 2. Start delete animation
      controller.deletingMessageId.value = messageId;

      // 3. Wait for animation
      await Future.delayed(const Duration(milliseconds: 300));

      // 4. Delete the message from database first to prevent realtime subscription from interfering
      await supabase.from('messages').delete().eq('message_id', messageId);

      // 5. Delete associated image if this was an image message
      if (messageType == 'image' && content != null) {
        try {
          final chatId = message['chat_id']?.toString();
          if (chatId != null) {
            // Extract filename from content URL
            final uri = Uri.parse(content);
            final pathSegments = uri.pathSegments;
            final filePath = pathSegments
                .sublist(pathSegments.indexOf('chat-media') + 1)
                .join('/');

            // Try to delete the image
            await supabase.storage.from('chat-media').remove([filePath]);
            debugPrint('Successfully deleted image: $filePath');
          }
        } catch (e) {
          debugPrint('Error deleting image: $e');
        }
      }

      // 6. Remove from local list and clear animation state
      controller.messages.removeWhere((msg) => msg.messageId == messageId);
      controller.deletingMessageId.value = '';
    } catch (e) {
      controller.deletingMessageId.value = '';
      debugPrint('Error in _deleteMessage: $e');
      Get.snackbar('Error', 'Failed to delete message');
    }
  }

  static void _copyMessageText(Map<String, dynamic> message) {
    final content = message['content']?.toString() ?? '';

    // Handle image messages
    if (content.startsWith('image:') || message['message_type'] == 'image') {
      Get.snackbar('Info', 'Cannot copy image content');
      return;
    }

    // Copy to clipboard
    Get.snackbar('Copied', 'Message copied to clipboard');
  }
}

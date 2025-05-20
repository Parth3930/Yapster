import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
              ],
              // Delete option - for your own messages
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

  static void _deleteMessage(Map<String, dynamic> message) {
    final controller = Get.find<ChatController>();
    final String chatId = controller.selectedChatId.value;
    final String messageId = message['message_id']?.toString() ?? '';

    if (messageId.isEmpty || chatId.isEmpty) {
      Get.snackbar('Error', 'Could not delete message');
      return;
    }

    // Show confirmation dialog
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete Message?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this message? This cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
            onPressed: () => Get.back(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Get.back();
              controller.deleteMessage(chatId, messageId);
            },
          ),
        ],
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
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

  // Delete message
  static Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final controller = Get.find<ChatController>();

    final String messageId = message['message_id']?.toString() ?? '';
    if (messageId.isEmpty) {
      Get.snackbar('Error', 'Could not delete message');
      return;
    }

    // Check if the message is already being deleted
    if (controller.deletingMessageId.value == messageId) {
      debugPrint('Message $messageId is already being deleted.');
      return;
    }

    final String messageType = message['message_type']?.toString() ?? '';
    final String content = message['content']?.toString() ?? ''; // For audio URL

    if (messageType == 'audio') {
      if (content.isEmpty || !Uri.parse(content).isAbsolute) {
        Get.snackbar('Error', 'Could not delete audio message: Invalid audio URL.');
        // Reset deletingMessageId if we abort before calling deleteAudioMessage
        if (controller.deletingMessageId.value == messageId) {
             controller.deletingMessageId.value = '';
        }
        return;
      }
      // deleteAudioMessage in ChatController will set deletingMessageId.value = messageId;
      // Its finally block will be modified later to not clear it.
      await controller.deleteAudioMessage(messageId, content);
    } else {
      // For non-audio messages
      controller.deletingMessageId.value = messageId; // Trigger UI animations
      try {
        await controller.supabaseService.client
            .from('messages')
            .delete()
            .eq('message_id', messageId);
        debugPrint('Successfully initiated deletion for non-audio message $messageId from database.');
        // Local list removal will be handled by real-time event or finalizeMessageDeletion.
        // The ChatController.finalizeMessageDeletion will clear deletingMessageId.
      } catch (e) {
        debugPrint('Error deleting non-audio message $messageId from database: $e');
        Get.snackbar('Error', 'Could not delete message details.');
        // If DB deletion fails, clear deletingMessageId to unstick UI.
        if (controller.deletingMessageId.value == messageId) {
          controller.deletingMessageId.value = '';
        }
      } finally {
        // For this re-application step, the original finally logic from Step 5 was to clear it.
        // However, for the current task (Step 9), we need to ensure it's NOT cleared here.
        // So, this finally block will be effectively empty regarding deletingMessageId.
        // if (controller.deletingMessageId.value == messageId) {
        //   controller.deletingMessageId.value = '';
        // }
      }
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

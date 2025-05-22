import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';

mixin ChatControllerServices {
  // Core services
  ChatController get _controller => Get.find<ChatController>();
  SupabaseService get _supabaseService => Get.find<SupabaseService>();

  void initializeServices() {
    // Implementation moved from ChatController
    // ...existing code...
  }

  Future<void> initializeEncryptionService() async {
    // Implementation moved from ChatController
    // ...existing code...
  }

  Future<void> initializeDecryptionService() async {
    // Implementation moved from ChatController
    // ...existing code...
  }

  String _extractStoragePath(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    final storagePathIndex = pathSegments.indexOf('chat-media');
    if (storagePathIndex >= 0) {
      return pathSegments.sublist(storagePathIndex + 1).join('/');
    }
    return url;
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      _controller.isSendingMessage.value = true;
      _controller.deletingMessageId.value = messageId;

      // Step 1: Animate deletion
      await Future.delayed(const Duration(milliseconds: 600));

      // Step 2: Fetch message content before deletion
      final response =
          await _supabaseService.client
              .from('messages')
              .select('content, message_type')
              .eq('message_id', messageId)
              .maybeSingle();

      if (response == null) {
        debugPrint('Message not found or already deleted');
        _controller.deletingMessageId.value = '';
        return;
      }

      final content = response['content'] as String?;
      final messageType = response['message_type'] as String?;

      // Step 3: Delete from storage if audio
      if (messageType == 'audio' || messageType == 'image' && content != null) {
        final storagePath = _extractStoragePath(content!);
        debugPrint('Attempting to delete from storage: $storagePath');

        bool deleted = false;

        try {
          final result = await _supabaseService.client.storage
              .from('chat-media')
              .remove([storagePath]);
          deleted = result.isNotEmpty;
        } catch (e) {
          debugPrint('Error in direct deletion: $e');
        }

        if (!deleted) {
          try {
            final chatId = storagePath.split('/').first;
            final fileName = storagePath.split('/').last;
            final files = await _supabaseService.client.storage
                .from('chat-media')
                .list(path: chatId);
            final match = files.where((f) => f.name == fileName).firstOrNull;
            if (match != null) {
              final result = await _supabaseService.client.storage
                  .from('chat-media')
                  .remove(['$chatId/${match.name}']);
              deleted = result.isNotEmpty;
            }
          } catch (e) {
            debugPrint('Error in fallback delete: $e');
          }
        }

        if (!deleted) {
          debugPrint('Failed to delete file from storage');
        }
      }

      // Step 4: Delete from database
      final deleteResponse =
          await _supabaseService.client
              .from('messages')
              .delete()
              .eq('message_id', messageId)
              .select();

      if (deleteResponse.isEmpty) {
        debugPrint('Message might have already been deleted from DB');
      }

      // Step 5: Finally remove from local state
      _controller.messages.removeWhere((m) => m.messageId == messageId);
      _controller.messages.refresh();

      // Clear animation state
      _controller.deletingMessageId.value = '';
    } catch (e) {
      debugPrint('Error deleting message: $e');
      Get.snackbar('Error', 'Failed to delete message');
      _controller.deletingMessageId.value = '';
    } finally {
      _controller.isSendingMessage.value = false;
    }
  }
}

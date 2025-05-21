import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';

mixin ChatControllerServices {
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

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      // Remove from UI
      final chatController = Get.find<ChatController>();
      chatController.messages.removeWhere((m) => m.messageId == messageId);
      // Remove from DB
      final supabase = Get.find<SupabaseService>().client;
      await supabase.from('messages').delete().eq('message_id', messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      Get.snackbar('Error', 'Failed to delete message.');
    }
  }
}

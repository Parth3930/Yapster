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
  String extractStoragePath(String url) {
    try {
      final uri = Uri.parse(url);
      debugPrint('Parsed URL: $uri');
      debugPrint('Path segments: ${uri.pathSegments}');

      // Find where the actual file path starts
      final storageIndex = uri.pathSegments.indexOf('storage');
      final objectIndex = uri.pathSegments.indexOf('object');
      final publicIndex = uri.pathSegments.indexOf('public');
      final bucketIndex = uri.pathSegments.indexOf('chat-media');

      debugPrint(
        'Storage/Object/Public/Bucket indices: $storageIndex/$objectIndex/$publicIndex/$bucketIndex',
      );

      // Check if we have standard Supabase storage URL structure
      if (bucketIndex != -1 && uri.pathSegments.length > bucketIndex + 1) {
        // Get everything after bucket name
        final path = uri.pathSegments.sublist(bucketIndex + 1).join('/');
        debugPrint('Extracted path from bucket: $path');
        return path;
      }

      // Fallback to removing any storage/api prefix if present
      List<String> relevantPath = uri.pathSegments;
      if (storageIndex != -1 && objectIndex != -1 && publicIndex != -1) {
        relevantPath = uri.pathSegments.sublist(publicIndex + 1);
      }

      final path = relevantPath.join('/');
      debugPrint('Using fallback path resolution: $path');
      return path;
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      // If not a valid URL, assume it's already a relative path
      debugPrint('Using original URL as path: $url');
      return url;
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final supabase = Get.find<SupabaseService>().client;
      final chatController = Get.find<ChatController>();

      // 1. Fetch message details first (type and content)
      debugPrint('Fetching message details for ID: $messageId');
      final response =
          await supabase
              .from('messages')
              .select('message_type, content')
              .eq('message_id', messageId)
              .maybeSingle();

      if (response == null) {
        debugPrint('Message not found in database');
        return;
      }

      final messageType = response['message_type'] as String?;
      final content = response['content'] as String?;

      debugPrint('Message type: $messageType');
      debugPrint('Content: $content');

      // 2. If message is image, delete image from storage bucket
      if (messageType == 'image' && content != null) {
        final storagePath = extractStoragePath(content);
        debugPrint('Full content URL: $content');
        debugPrint('Attempting to delete from storage path: "$storagePath"');

        bool deleted = false;

        try {
          // First attempt: Try direct deletion
          debugPrint('Attempt 1: Direct deletion with extracted path');
          final deleteRes = await supabase.storage.from('chat-media').remove([
            storagePath,
          ]);

          if (deleteRes.isNotEmpty) {
            debugPrint('✅ Image deleted successfully with direct path');
            deleted = true;
          }
        } catch (e) {
          debugPrint('Direct deletion failed: $e');
        }

        if (!deleted) {
          try {
            // Second attempt: Try listing folder contents
            final chatFolder = storagePath.split('/').first;
            debugPrint('Attempt 2: Listing contents of folder: $chatFolder');

            final files = await supabase.storage
                .from('chat-media')
                .list(path: chatFolder);

            debugPrint('Files found in chat folder:');
            for (var file in files) {
              debugPrint('- ${file.name}');
            }

            final fileName = storagePath.split('/').last;
            final matchingFile =
                files.where((f) => f.name == fileName).firstOrNull;

            if (matchingFile != null) {
              final fullPath = '$chatFolder/${matchingFile.name}';
              debugPrint('Found matching file, attempting deletion: $fullPath');

              final deleteRes = await supabase.storage
                  .from('chat-media')
                  .remove([fullPath]);

              if (deleteRes.isNotEmpty) {
                debugPrint('✅ Image deleted successfully via folder lookup');
                deleted = true;
              }
            }
          } catch (e) {
            debugPrint('Folder listing/deletion failed: $e');
          }
        }

        if (!deleted) {
          debugPrint('❌ Failed to delete image after all attempts');
        }
      }

      // 3. Delete message from UI
      chatController.messages.removeWhere((m) => m.messageId == messageId);
      chatController.messages.refresh();

      // 4. Delete message from DB
      debugPrint('Deleting message from database...');
      final deleteResponse =
          await supabase
              .from('messages')
              .delete()
              .eq('message_id', messageId)
              .select();

      debugPrint('Database delete response: $deleteResponse');
      debugPrint('Message deleted successfully from database');
    } catch (e) {
      debugPrint('Error in deleteMessage: $e');
      Get.snackbar('Error', 'Failed to delete message.');
    }
  }
}

import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller_messages.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';

mixin ChatControllerServices {
  // Core services
  ChatController get _controller => Get.find<ChatController>();
  SupabaseService get _supabaseService => Get.find<SupabaseService>();


  String _extractStoragePath(String url) {
    try {
      // If it's already a simple path (no http), return as is
      if (!url.startsWith('http')) {
        return url;
      }
      
      // Parse the URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Find the 'object/public' part
      final objectIndex = pathSegments.indexOf('object');
      if (objectIndex != -1 && pathSegments.length > objectIndex + 2) {
        // Format: /storage/v1/object/public/chat-media/path/to/file
        return pathSegments.sublist(objectIndex + 2).join('/');
      }
      
      // If we can't parse it, try to extract the last part of the URL
      final lastSlash = url.lastIndexOf('/');
      if (lastSlash != -1) {
        return url.substring(lastSlash + 1);
      }
      
      return url;
    } catch (e) {
      debugPrint('Error parsing storage path: $e');
      return url;
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    // 1. Find the message index
    final messageIndex = _controller.messages.indexWhere((m) => m.messageId == messageId);
    if (messageIndex == -1) return; // Message already removed
    
    // 2. Store the message for background processing
    final messageToDelete = _controller.messages[messageIndex];
    
    // 3. Mark as deleting to trigger exit animation
    _controller.deletingMessageId.value = messageId;
    
    // 4. Wait for exit animation to complete (300ms)
    await Future.delayed(const Duration(milliseconds: 300));
    
    // 5. Remove from UI
    _controller.messages.removeAt(messageIndex);
    _controller.messages.refresh();
    
    // 6. Mark as deleted in tracking set to prevent reappearing
    ChatControllerMessages.markMessageDeleted(messageId);
    
    // 7. Process deletion in background
    _processDeletionInBackground(chatId, messageId, messageToDelete);
  }
  
  Future<void> _processDeletionInBackground(
    String chatId, 
    String messageId, 
    MessageModel messageToDelete
  ) async {
    try {
      _controller.isSendingMessage.value = true;
      _controller.deletingMessageId.value = messageId;
      
      // 1. Delete from storage if it's an audio/image message
      if (messageToDelete.messageType == 'audio' || 
          messageToDelete.messageType == 'image') {
        try {
          final content = messageToDelete.content;
          if (content.isNotEmpty) {
            final storagePath = _extractStoragePath(content);
            debugPrint('Attempting to delete from storage: $storagePath');
            
            // Try direct deletion first
            bool deleted = await _deleteFromStorage(storagePath);
            
            // If direct deletion fails, try fallback method
            if (!deleted) {
              deleted = await _tryFallbackStorageDeletion(storagePath);
            }
            
            if (!deleted) {
              debugPrint('Failed to delete file from storage');
            }
          }
        } catch (e) {
          debugPrint('Error deleting media: $e');
        }
      }
      
      // 2. Delete from database
      try {
        await _supabaseService.client
            .from('messages')
            .delete()
            .eq('message_id', messageId);
      } catch (e) {
        debugPrint('Error deleting from database: $e');
        // Don't show error to user as the message is already removed from UI
      }
      
    } catch (e) {
      debugPrint('Error in background deletion: $e');
      // Don't show error to user as the message is already removed from UI
    } finally {
      // Clear animation state after a minimum delay to ensure smooth animation
      await Future.delayed(const Duration(milliseconds: 300));
      _controller.deletingMessageId.value = '';
      _controller.isSendingMessage.value = false;
    }
  }
  
  Future<bool> _deleteFromStorage(String storagePath) async {
    try {
      // Clean up the path
      String cleanPath = storagePath;
      
      // Remove any leading slashes
      while (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      
      // Remove 'chat-media/' prefix if it exists
      if (cleanPath.startsWith('chat-media/')) {
        cleanPath = cleanPath.substring('chat-media/'.length);
      }
      
      debugPrint('Deleting from storage - Clean Path: $cleanPath');
      
      // Always use 'chat-media' as the bucket
      final result = await _supabaseService.client.storage
          .from('chat-media')
          .remove([cleanPath]);
          
      if (result.isNotEmpty) {
        debugPrint('Successfully deleted file: $cleanPath');
        return true;
      } else {
        debugPrint('Failed to delete file (empty response): $cleanPath');
        return false;
      }
    } catch (e) {
      debugPrint('Error in direct storage deletion: $e');
      return false;
    }
  }
  
  Future<bool> _tryFallbackStorageDeletion(String storagePath) async {
    try {
      final parts = storagePath.split('/');
      if (parts.length < 2) return false;
      
      final chatId = parts[0];
      final fileName = parts.last;
      
      final files = await _supabaseService.client.storage
          .from('chat-media')
          .list(path: chatId);
          
      final match = files.where((f) => f.name == fileName).firstOrNull;
      if (match != null) {
        final result = await _supabaseService.client.storage
            .from('chat-media')
            .remove(['$chatId/${match.name}']);
        return result.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('Error in fallback storage deletion: $e');
      return false;
    }
  }
}

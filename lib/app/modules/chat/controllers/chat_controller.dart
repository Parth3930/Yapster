import 'dart:io'; // Added
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart'; // Added
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import 'chat_controller_messages.dart';
import 'chat_controller_search.dart';
import 'chat_controller_services.dart';

/// Controller for chat functionality
class ChatController extends GetxController
    with ChatControllerMessages, ChatControllerSearch, ChatControllerServices {
  // Core services
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  // State variables
  final RxBool isLoading = false.obs;
  final RxBool isSendingMessage = false.obs;
  final RxBool isInitialized = false.obs;

  List<MessageModel> get sortedMessages =>
      List.from(messages)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Active conversation state
  late RxList<MessageModel> messages = <MessageModel>[].obs;
  // Message input control
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final RxBool showEmojiPicker = false.obs;
  final RxBool isRecording = false.obs;

  // Pagination
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreMessages = true.obs;
  final int messagesPerPage = 20;

  // Added properties needed by views
  final RxString selectedChatId = ''.obs;
  final RxBool hasUserDismissedExpiryBanner = false.obs;
  final RxMap<String, double> localUploadProgress = <String, double>{}.obs;
  final RxSet<String> messagesToAnimate =
      <String>{}.obs; // Track messages that need animation
  final RxString deletingMessageId = ''.obs;

  // Recent chats functionality
  final RxList<Map<String, dynamic>> recentChats = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingChats = false.obs;

  // Search functionality
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;

  // Expose supabase service for views
  SupabaseService get supabaseService => _supabaseService;

  @override
  void onInit() {
    super.onInit();
    initializeServices();
    searchController.addListener(handleSearchInputChanged);
  }

  @override
  void onClose() {
    messageController.dispose();
    messageFocusNode.dispose();
    searchController.dispose();
    super.onClose();
  }

  // Method to call when message bubble animation completes
  void onMessageAnimationComplete(String messageId) {
    messagesToAnimate.remove(messageId);
  }

  Future<void> uploadAndSendAudio(String chatId, String audioPath, {Duration? duration}) async {
    isSendingMessage.value = true;
    try {
      final messageId = Uuid().v4(); // Requires: import 'package:uuid/uuid.dart';
      final senderId = _supabaseService.client.auth.currentUser?.id;

      if (senderId == null) {
        Get.snackbar('Error', 'User not logged in.');
        print('Error: User not logged in.');
        isSendingMessage.value = false;
        return;
      }

      // Optimistic UI Update (Part 1)
      final tempMessage = MessageModel(
        messageId: messageId,
        chatId: chatId,
        senderId: senderId,
        content: audioPath, // Local path for now
        messageType: 'audio',
        recipientId: '', 
        expiresAt: DateTime.now().add(Duration(days: 7)), 
        createdAt: DateTime.now(),
        isRead: false,
        duration: duration,
      );

      messages.insert(0, tempMessage);
      messagesToAnimate.add(messageId);

      // Upload to Supabase Storage
      final filePathInStorage = '$senderId/$chatId/$messageId.m4a';
      String audioUrl;

      try {
        // Requires: import 'dart:io';
        await _supabaseService.client.storage
            .from('chat_media') 
            .upload(filePathInStorage, File(audioPath));

        audioUrl = _supabaseService.client.storage
            .from('chat_media')
            .getPublicUrl(filePathInStorage);
      } catch (e) {
        messages.removeWhere((m) => m.messageId == messageId);
        messagesToAnimate.remove(messageId);
        Get.snackbar('Error', 'Failed to upload audio: ${e.toString()}');
        print('Error uploading audio: $e');
        isSendingMessage.value = false;
        return;
      }

      // Save Message to Supabase Database
      final messageData = {
        'message_id': messageId,
        'chat_id': chatId,
        'sender_id': senderId,
        'content': audioUrl,
        'message_type': 'audio',
        'recipient_id': '', 
        'expires_at': DateTime.now().add(Duration(days: 7)).toIso8601String(), 
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'duration_seconds': duration?.inSeconds,
      };

      try {
        await _supabaseService.client.from('messages').insert(messageData);
        final index = messages.indexWhere((m) => m.messageId == messageId);
        if (index != -1) {
          messages[index] = MessageModel.fromJson(messageData);
        }
      } catch (e) {
        messages.removeWhere((m) => m.messageId == messageId);
        messagesToAnimate.remove(messageId);
        try {
          await _supabaseService.client.storage.from('chat_media').remove([filePathInStorage]);
        } catch (storageError) {
          print('Error deleting orphaned audio from storage: $storageError');
        }
        Get.snackbar('Error', 'Failed to send message: ${e.toString()}');
        print('Error saving message to database: $e');
      }
    } finally {
      isSendingMessage.value = false;
    }
  }

  String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length > 4 && pathSegments[3] == 'public' && pathSegments[4] == 'chat_media') {
        // Path starts after "public/chat_media/"
        // Example URL: https://<project-ref>.supabase.co/storage/v1/object/public/chat_media/user_id/chat_id/file.m4a
        // pathSegments: [storage, v1, object, public, chat_media, user_id, chat_id, file.m4a]
        // We need segments from index 5 onwards.
        if (pathSegments.length > 5) {
            return pathSegments.sublist(5).join('/');
        }
      }
      print('Error extracting path: URL structure not as expected or bucket name mismatch. URL: $url, Segments: $pathSegments');
      return null;
    } catch (e) {
      print('Error parsing URL in _extractPathFromUrl: $e');
      return null;
    }
  }

  Future<void> deleteAudioMessage(String messageId, String audioUrl) async {
    deletingMessageId.value = messageId;
    try {
      final String? filePathInStorage = _extractPathFromUrl(audioUrl);

      if (filePathInStorage == null || filePathInStorage.isEmpty) {
        Get.snackbar('Error', 'Could not determine file path for deletion. URL: $audioUrl');
        print('Error: Could not determine file path for deletion from URL: $audioUrl');
        // Resetting deletingMessageId here as the operation is aborted.
        if (deletingMessageId.value == messageId) {
          deletingMessageId.value = '';
        }
        return;
      }

      try {
        await _supabaseService.client.storage
            .from('chat_media')
            .remove([filePathInStorage]);
        print('Successfully deleted $filePathInStorage from storage.');
      } catch (e) {
        print('Error deleting audio from storage: $e. Path: $filePathInStorage');
        Get.snackbar('Error', 'Could not delete audio file from storage. Please try again.');
        // Resetting deletingMessageId here as the operation is aborted before DB delete.
        if (deletingMessageId.value == messageId) {
          deletingMessageId.value = '';
        }
        return;
      }

      await _supabaseService.client
          .from('messages')
          .delete()
          .eq('message_id', messageId);
      
      print('Successfully initiated deletion for message $messageId from database.');
      // Local list removal will be handled by real-time event or finalizeMessageDeletion

    } catch (e) {
      print('An unexpected error occurred in deleteAudioMessage: $e');
      Get.snackbar('Error', 'An unexpected error occurred while deleting the message.');
       if (deletingMessageId.value == messageId) {
          deletingMessageId.value = '';
        }
    }
    finally {
      // Defer clearing deletingMessageId until animation completes.
      // The actual clearing will be done by finalizeMessageDeletion.
      // if (deletingMessageId.value == messageId) {
      //      deletingMessageId.value = '';
      // }
    }
  }

  void finalizeMessageDeletion(String messageId) {
    // This method is called after the message bubble's delete animation completes.
    // The message should ideally have already been removed from the `messages` list
    // by the real-time event handler if the DB operation was faster than the animation.
    
    // Forcing removal here ensures cleanup if real-time event was missed or animation finished first.
    // This also handles cases where the message might not have been deleted from DB successfully
    // but UI animation completed.
    final initialLength = messages.length;
    messages.removeWhere((m) => m.messageId == messageId);
    final finalLength = messages.length;

    if (initialLength != finalLength) {
      debugPrint("finalizeMessageDeletion: Removed message $messageId from local list. Count: $initialLength -> $finalLength");
    } else {
      debugPrint("finalizeMessageDeletion: Message $messageId was already removed from local list (likely by real-time).");
    }

    if (deletingMessageId.value == messageId) {
      deletingMessageId.value = '';
      debugPrint("finalizeMessageDeletion: Cleared deletingMessageId for $messageId.");
    }
  }
}

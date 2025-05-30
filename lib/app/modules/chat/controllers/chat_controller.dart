import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
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
  final RxSet<String> messagesToAnimate = <String>{}.obs;
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

  Future<void> uploadAndSendAudio(
    String chatId,
    String audioPath, {
    Duration? duration,
  }) async {
    isSendingMessage.value = true;
    try {
      final messageId = Uuid().v4();
      final senderId = _supabaseService.client.auth.currentUser?.id;

      if (senderId == null) {
        Get.snackbar('Error', 'User not logged in.');
        print('Error: User not logged in.');
        return;
      }

      // Optimistic UI Update (Part 1)
      final tempMessage = MessageModel(
        messageId: messageId,
        chatId: chatId,
        senderId: senderId,
        content: audioPath, // Local path for now
        messageType: 'audio',
        recipientId: '', // Placeholder - adjust as needed
        expiresAt: DateTime.now().add(Duration(days: 7)), // Placeholder
        createdAt: DateTime.now(),
        isRead: false,
        duration: duration, // Pass duration to the temporary optimistic message
      );

      messages.insert(0, tempMessage);
      messagesToAnimate.add(messageId);

      // Upload to Supabase Storage
      final filePathInStorage = '$senderId/$chatId/$messageId.m4a';
      String audioUrl;

      try {
        await _supabaseService.client.storage
            .from('audio_messages') // Bucket name
            .upload(filePathInStorage, File(audioPath));

        audioUrl = _supabaseService.client.storage
            .from('audio_messages')
            .getPublicUrl(filePathInStorage);
      } catch (e) {
        // Handle upload error
        messages.removeWhere((m) => m.messageId == messageId);
        messagesToAnimate.remove(messageId);
        Get.snackbar('Error', 'Failed to upload audio: ${e.toString()}');
        print('Error uploading audio: $e');
        return; // Do not proceed if upload fails
      }

      // Save Message to Supabase Database
      final messageData = {
        'message_id': messageId,
        'chat_id': chatId,
        'sender_id': senderId,
        'content': audioUrl,
        'message_type': 'audio',
        'recipient_id': '', // Adjust as needed
        'expires_at':
            DateTime.now().add(Duration(days: 7)).toIso8601String(), // Adjust
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'duration_seconds':
            duration?.inSeconds, // Ensure this line is present and uncommented
      };

      try {
        await _supabaseService.client.from('messages').insert(messageData);

        // Optimistic UI Update (Part 2) - Update the existing temp message
        final index = messages.indexWhere((m) => m.messageId == messageId);
        if (index != -1) {
          // Create a new MessageModel from the data that was sent to the DB
          // This ensures the local model matches the remote one
          // MessageModel.fromJson expects date strings to be in ISO8601 format
          // and will parse them into DateTime objects.
          messages[index] = MessageModel.fromJson(messageData);
        }
      } catch (e) {
        // Handle database error
        messages.removeWhere((m) => m.messageId == messageId);
        messagesToAnimate.remove(messageId);
        // Attempt to delete the already uploaded audio from storage to prevent orphans
        try {
          await _supabaseService.client.storage.from('audio_messages').remove([
            filePathInStorage,
          ]);
        } catch (storageError) {
          print('Error deleting orphaned audio from storage: $storageError');
          // Optionally, inform the user about the orphaned file or log for manual cleanup
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
      // Example: /storage/v1/object/public/audio_messages/path/to/file.m4a
      // We need "path/to/file.m4a"
      final pathSegments = uri.pathSegments;
      // Ensure there are enough segments and the bucket name is correct
      if (pathSegments.length > 5 && pathSegments[4] == 'audio_messages') {
        return pathSegments.sublist(5).join('/');
      }
      print(
        'Error extracting path: URL structure not as expected. Segments: $pathSegments',
      );
      return null;
    } catch (e) {
      print('Error parsing URL: $e');
      return null;
    }
  }

  Future<void> deleteAudioMessage(String messageId, String audioUrl) async {
    deletingMessageId.value = messageId;
    try {
      // 1. Delete from Supabase Storage
      final String? filePathInStorage = _extractPathFromUrl(audioUrl);

      if (filePathInStorage == null || filePathInStorage.isEmpty) {
        Get.snackbar(
          'Error',
          'Could not determine file path for deletion. URL: $audioUrl',
        );
        debugPrint(
          'Error: Could not determine file path for deletion from URL: $audioUrl',
        );
        return;
      }

      try {
        await _supabaseService.client.storage
            .from('audio_messages') // Bucket name
            .remove([filePathInStorage]);
        debugPrint('Successfully deleted $filePathInStorage from storage.');
      } catch (e) {
        debugPrint(
          'Error deleting audio from storage: $e. Path: $filePathInStorage',
        );
        Get.snackbar(
          'Error',
          'Could not delete audio file from storage. Please try again.',
        );
        return;
      }

      // 2. Delete from Supabase Database
      try {
        await _supabaseService.client
            .from('messages')
            .delete()
            .eq('message_id', messageId);

        print('Successfully deleted message $messageId from database.');
        // Assuming real-time listener handles local list removal.
        // If not, uncomment: messages.removeWhere((m) => m.messageId == messageId);
      } catch (e) {
        print('Error deleting message $messageId from database: $e');
        Get.snackbar(
          'Error',
          'Could not delete message details. Please try again.',
        );
        // If DB deletion fails, the storage file is already deleted (orphaned file).
        // This is not ideal, but the function has attempted its best.
      }
    } catch (e) {
      // Catch any other unexpected errors from the try block
      print('An unexpected error occurred in deleteAudioMessage: $e');
      Get.snackbar(
        'Error',
        'An unexpected error occurred while deleting the message.',
      );
    } finally {
      deletingMessageId.value = '';
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import 'package:yapster/app/modules/chat/services/chat_message_service.dart';
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

  // Active conversation state - use static for persistence across navigations
  static final RxMap<String, List<MessageModel>> _messageCache =
      <String, List<MessageModel>>{}.obs;
  final RxList<MessageModel> messages =
      <MessageModel>[].obs; // Remove 'late' keyword

  // Message input control
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final RxBool showEmojiPicker = false.obs;
  final RxBool isRecording = false.obs;

  // Pagination
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreMessages = true.obs;
  final int messagesPerPage = 20;

  // Cache the messages to persist state across navigation
  void cacheMessages(String chatId, List<MessageModel> msgs) {
    if (chatId.isNotEmpty) {
      _messageCache[chatId] = List.from(msgs);
      debugPrint('Cached ${msgs.length} messages for chat $chatId');
    }
  }

  // Get cached messages if available
  List<MessageModel>? getCachedMessages(String chatId) {
    if (_messageCache.containsKey(chatId)) {
      final cachedMessages = _messageCache[chatId];
      debugPrint(
        'Retrieved ${cachedMessages?.length} cached messages for chat $chatId',
      );
      return cachedMessages;
    }
    return null;
  }

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

  // Static flag to track controller initialization state
  static bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();

    // Only preload chats once on first initialization
    if (!_isInitialized) {
      _isInitialized = true;
      // Preload recent chats on controller initialization
      preloadRecentChats();
    }

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
    final senderId = _supabaseService.client.auth.currentUser?.id;

    if (senderId == null) {
      Get.snackbar('Error', 'Not authenticated');
      return;
    }

    try {
      // Get recipient ID from the chat (using existing data or fetching from db)
      String recipientId = '';

      // Try to find it in the recent chats data first
      final chatIndex = recentChats.indexWhere(
        (chat) => chat['chat_id'] == chatId,
      );
      if (chatIndex != -1) {
        // Get recipient from the existing chat data
        final chat = recentChats[chatIndex];
        final String currentUserId =
            _supabaseService.currentUser.value?.id ?? '';
        if (chat['user_one_id'] == currentUserId) {
          recipientId = chat['user_two_id'];
        } else {
          recipientId = chat['user_one_id'];
        }
      } else {
        // If not found in recent chats, fetch from database
        final response =
            await _supabaseService.client
                .from('chats')
                .select('user_one_id, user_two_id')
                .eq('chat_id', chatId)
                .single();
        final String currentUserId =
            _supabaseService.currentUser.value?.id ?? '';
        recipientId =
            response['user_two_id'] == currentUserId
                ? response['user_one_id']
                : response['user_two_id'];
      }

      // Set default expiration time (7 days from now)
      final DateTime expiresAt = DateTime.now().toUtc().add(
        const Duration(days: 7),
      );

      // Call the service with all required parameters
      await Get.find<ChatMessageService>().uploadAndSendAudio(
        chatId: chatId,
        recipientId: recipientId,
        audioFile: File(audioPath),
        expiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('Error uploading and sending audio: $e');
      Get.snackbar('Error', 'Failed to send audio message');
    }
  }

  String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Example: /storage/v1/object/public/chat-media/userId/filename.m4a
      // We need "userId/filename.m4a"
      final pathSegments = uri.pathSegments;

      // Check if we have enough segments and the path follows the expected structure
      if (pathSegments.length > 5 &&
          (pathSegments[4] == 'audio_messages' ||
              pathSegments[4] == 'chat-media')) {
        // Return everything after the bucket name (chat-media or audio_messages)
        return pathSegments.sublist(5).join('/');
      }

      debugPrint(
        'Error extracting path: URL structure not as expected. Segments: $pathSegments',
      );
      return null;
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return null;
    }
  }

  Future<void> deleteAudioMessage(String messageId, String audioUrl) async {
    // First, remove from local state immediately for better UX
    if (messages.any((m) => m.messageId == messageId)) {
      messages.removeWhere((m) => m.messageId == messageId);
      messages.refresh();
    }

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
        // Use the correct bucket name 'chat-media' and ensure proper path formatting
        final storagePath =
            filePathInStorage.startsWith('chat-media/')
                ? filePathInStorage.substring('chat-media/'.length)
                : filePathInStorage;

        await _supabaseService.client.storage
            .from('chat-media') // Updated bucket name
            .remove([storagePath]);

        debugPrint('Successfully deleted $storagePath from chat-media bucket.');
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

        debugPrint('Successfully deleted message $messageId from database.');

        // Update the local messages list
        if (messages.any((m) => m.messageId == messageId)) {
          messages.removeWhere((m) => m.messageId == messageId);
          messages.refresh(); // Notify listeners of the change
        }
      } catch (e) {
        debugPrint('Error deleting message $messageId from database: $e');
        Get.snackbar(
          'Error',
          'Could not delete message details. Please try again.',
        );
        // If DB deletion fails, the storage file is already deleted (orphaned file).
        // This is not ideal, but the function has attempted its best.
      }
    } catch (e) {
      // Catch any other unexpected errors from the try block
      debugPrint('An unexpected error occurred in deleteAudioMessage: $e');
      Get.snackbar(
        'Error',
        'An unexpected error occurred while deleting the message.',
      );
    } finally {
      deletingMessageId.value = '';
    }
  }
}

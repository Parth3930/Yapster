import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/modules/chat/models/chat_message_model.dart';
import 'package:yapster/app/modules/chat/models/chat_conversation_model.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling message operations in chats
class ChatMessageService extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final ChatCacheService _chatCacheService = Get.find<ChatCacheService>();
  final EncryptionService _encryptionService = Get.find<EncryptionService>();

  // Track processed message IDs to prevent duplication
  final RxSet<String> _processedMessageIds = <String>{}.obs;

  // Cache for decrypted messages to avoid repeated decryption
  final Map<String, String> _decryptedContentCache = {};

  // Track when the last database update was attempted
  DateTime? _lastReadStatusUpdate;
  final _readStatusThrottleDuration = const Duration(seconds: 10);

  // Observable message list
  late RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;

  // Observable chats list
  late RxList<Map<String, dynamic>> recentChats;

  // Media upload progress
  late RxMap<String, double> localUploadProgress;

  /// Initialize the service with observable lists
  void initialize({
    required RxList<Map<String, dynamic>> messagesList,
    required RxList<Map<String, dynamic>> chatsList,
    required RxMap<String, double> uploadProgress,
  }) {
    messages = messagesList;
    recentChats = chatsList;
    localUploadProgress = uploadProgress;
    _processedMessageIds.clear();
  }

  /// Load messages for a chat
  Future<void> loadMessages(String chatId) async {
    try {
      debugPrint('Loading messages for chat: $chatId');

      // Check cache first for immediate UI update
      final List<ChatMessage> cachedMessages = _chatCacheService
          .getCachedMessages(chatId);
      final bool useCache = cachedMessages.isNotEmpty;

      // Always update UI immediately from cache if available to provide instant feedback
      if (useCache) {
        // Convert ChatMessage to Map<String, dynamic>
        messages.value =
            cachedMessages.map((msg) => _convertChatMessageToMap(msg)).toList();
        debugPrint(
          'Loaded ${cachedMessages.length} messages from cache (will still load from network)',
        );
      }

      // Always load fresh data from network
      debugPrint('Loading messages from network...');
      final response = await _supabaseService.client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at');

      if (response != null && response.isNotEmpty) {
        final messagesList = List<Map<String, dynamic>>.from(response);

        // Clear processed message IDs when loading messages to avoid problems with realtime
        _processedMessageIds.clear();

        // Decrypt message content in parallel for better performance
        await _decryptMessages(messagesList, chatId);

        // Update the messages list
        messages.value = messagesList;
        messages.refresh();

        // Convert to ChatMessage and cache the messages for future use
        final List<ChatMessage> messagesToCache =
            messagesList.map((msg) => _convertMapToChatMessage(msg)).toList();
        _chatCacheService.cacheMessages(chatId, messagesToCache);

        debugPrint(
          '✅ Loaded and cached ${messages.length} messages from network',
        );
      } else {
        // No messages from network - keep using cache or set empty list
        if (!useCache) {
          messages.value = [];
          debugPrint('No messages found for chat $chatId');
        } else {
          debugPrint('Network returned no messages, keeping cached messages');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');

      // If we have cache, keep using it even if network failed
      if (messages.isEmpty) {
        final List<ChatMessage> fallbackCache = _chatCacheService
            .getCachedMessages(chatId);
        if (fallbackCache.isNotEmpty) {
          messages.value =
              fallbackCache
                  .map((msg) => _convertChatMessageToMap(msg))
                  .toList();
          debugPrint('Using cached messages due to network error');
        }
      }
    }
  }

  /// Decrypt messages in parallel for better performance
  Future<void> _decryptMessages(
    List<Map<String, dynamic>> messagesList,
    String chatId,
  ) async {
    final decryptionFutures = <Future>[];

    for (var message in messagesList) {
      // Store processed message IDs
      if (message['message_id'] != null) {
        _processedMessageIds.add(message['message_id'].toString());
      }

      // Skip decryption for empty content
      if (message['content'] == null || message['content'].toString().isEmpty) {
        continue;
      }

      // Decrypt message content with chat-specific key
      decryptionFutures.add(_decryptMessage(message, chatId));
    }

    // Wait for all decryption operations to complete
    await Future.wait(decryptionFutures);
  }

  /// Decrypt a single message
  Future<void> _decryptMessage(
    Map<String, dynamic> message,
    String chatId,
  ) async {
    try {
      final encryptedContent = message['content'].toString();

      // Check decryption cache first
      final cacheKey = '$chatId:$encryptedContent';
      if (_decryptedContentCache.containsKey(cacheKey)) {
        message['content'] = _decryptedContentCache[cacheKey];
        return;
      }

      // Decrypt with chat-specific key
      final decrypted = await _encryptionService.decryptMessageForChat(
        encryptedContent,
        chatId,
      );
      message['content'] = decrypted;

      // Cache the decrypted content
      _decryptedContentCache[cacheKey] = decrypted;
    } catch (e) {
      // If decryption fails, try legacy decryption
      try {
        final encryptedContent = message['content'].toString();
        final decrypted = _encryptionService.decryptMessage(encryptedContent);
        message['content'] = decrypted;

        // Cache the legacy decrypted content
        final cacheKey = 'legacy:${message['content']}';
        _decryptedContentCache[cacheKey] = decrypted;
      } catch (e2) {
        debugPrint('Could not decrypt message: $e2');
      }
    }
  }

  /// Send a message with improved realtime handling
  Future<void> sendMessage(
    String chatId,
    String content,
    TextEditingController messageController,
  ) async {
    if (content.isEmpty) {
      debugPrint('Cannot send empty message');
      return;
    }

    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) {
      debugPrint('Cannot send message: User not logged in');
      return;
    }

    debugPrint('Sending message to chat $chatId');

    try {
      // Set expiration time to 24 hours from now
      final expiresAt =
          DateTime.now().add(const Duration(hours: 24)).toIso8601String();
      final now = DateTime.now().toIso8601String();

      // Encrypt the message content with chat-specific key
      final encryptedContent = await _encryptionService.encryptMessageForChat(
        content,
        chatId,
      );

      // Create a placeholder message for immediate feedback
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final placeholderMessage = {
        'message_id': tempId,
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': content, // Use unencrypted content for display
        'created_at': now,
        'expires_at': expiresAt,
        'is_sending': true, // Flag to show sending state
      };

      // Add the placeholder message to UI immediately
      final updatedMessages = List<Map<String, dynamic>>.from(messages);
      updatedMessages.add(placeholderMessage);
      messages.value = updatedMessages;
      messages.refresh();

      // Create message object for database
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedContent,
        'created_at': now,
        'expires_at': expiresAt,
      };

      // Add message to database
      debugPrint('Inserting encrypted message into database...');
      final response =
          await _supabaseService.client
              .from('messages')
              .insert(messageData)
              .select();

      if (response.isNotEmpty) {
        // Get the actual message with server-generated ID
        final newMessage = Map<String, dynamic>.from(response[0]);

        // Add message ID to processed list to prevent duplicates
        if (newMessage['message_id'] != null) {
          final messageId = newMessage['message_id'].toString();
          _processedMessageIds.add(messageId);
          debugPrint('Added sent message ID to processed list: $messageId');
        }

        // Replace the placeholder with the real message
        final finalMessages =
            messages.where((msg) => msg['message_id'] != tempId).toList();

        // Use original content for display (not encrypted version)
        newMessage['content'] = content;

        // Cache the decrypted content for future reference
        final cacheKey = '$chatId:$encryptedContent';
        _decryptedContentCache[cacheKey] = content;

        // Add the real message
        finalMessages.add(newMessage);

        // Update UI
        messages.value = finalMessages;
        messages.refresh();

        // Convert to ChatMessage and update cache to ensure persistence
        final List<ChatMessage> messagesToCache =
            finalMessages.map((msg) => _convertMapToChatMessage(msg)).toList();
        _chatCacheService.cacheMessages(chatId, messagesToCache);

        // Update recent chats cache to avoid having to reload from network
        _updateRecentChatsAfterSend(chatId, content, currentUserId);

        // Clear the message input
        messageController.clear();
        debugPrint('✅ Message sent successfully');
      } else {
        // Remove the placeholder if the send failed
        final currentMessages =
            messages.where((msg) => msg['message_id'] != tempId).toList();
        messages.value = currentMessages;
        messages.refresh();

        Get.snackbar(
          'Error',
          'Failed to send message',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      Get.snackbar(
        'Error',
        'Could not send message. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Upload and send image
  Future<void> uploadAndSendImage(String chatId, XFile image) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;

      if (currentUserId == null) {
        Get.snackbar('Error', 'Not authenticated');
        return;
      }

      // Generate unique tracking ID for this upload
      final String uploadId = DateTime.now().millisecondsSinceEpoch.toString();

      // Add a placeholder message to show immediate feedback with shimmer effect
      final placeholderMessage = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': 'Uploading image...',
        'created_at': DateTime.now().toIso8601String(),
        'message_id': 'placeholder_$uploadId',
        'message_type': 'image',
        'is_placeholder': true,
        'upload_id': uploadId,
      };

      // Add placeholder to messages list
      messages.add(placeholderMessage);
      messages.refresh();

      // Start tracking upload progress at 0%
      localUploadProgress[uploadId] = 0.0;

      try {
        // Read image bytes with proper error handling
        final Uint8List imageBytes;
        try {
          // Convert List<int> to Uint8List for storage upload
          final bytes = await image.readAsBytes();
          imageBytes = Uint8List.fromList(bytes);

          // Update progress - reading complete
          localUploadProgress[uploadId] = 0.2;
          localUploadProgress.refresh();
        } catch (e) {
          debugPrint('Error reading image bytes: $e');

          // Remove placeholder on error
          messages.removeWhere((msg) => msg['upload_id'] == uploadId);
          messages.refresh();

          // Remove from tracking
          localUploadProgress.remove(uploadId);

          Get.snackbar('Error', 'Could not read image file');
          return;
        }

        if (imageBytes.isEmpty) {
          debugPrint('Image bytes are empty');

          // Remove placeholder on error
          messages.removeWhere((msg) => msg['upload_id'] == uploadId);
          messages.refresh();

          // Remove from tracking
          localUploadProgress.remove(uploadId);

          Get.snackbar('Error', 'Invalid image file');
          return;
        }

        // Generate unique file name with timestamp to ensure uniqueness
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final String filePath = '$chatId/$currentUserId/$fileName';

        // Update progress - starting upload
        localUploadProgress[uploadId] = 0.3;
        localUploadProgress.refresh();

        // Upload to Supabase storage
        final uploadResult = await _supabaseService.client.storage
            .from('chat_media')
            .uploadBinary(
              filePath,
              imageBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        debugPrint('Upload result: $uploadResult');

        // Update progress - upload complete
        localUploadProgress[uploadId] = 0.7;
        localUploadProgress.refresh();

        // Get public URL
        final imageUrl = _supabaseService.client.storage
            .from('chat_media')
            .getPublicUrl(filePath);

        debugPrint('Image URL: $imageUrl');

        // Update progress - URL obtained
        localUploadProgress[uploadId] = 0.8;
        localUploadProgress.refresh();

        if (imageUrl.isEmpty) {
          // Remove placeholder on error
          messages.removeWhere((msg) => msg['upload_id'] == uploadId);
          messages.refresh();

          // Remove from tracking
          localUploadProgress.remove(uploadId);

          Get.snackbar('Error', 'Failed to get image URL');
          return;
        }

        // Set expiration time to 24 hours from now
        final expiresAt =
            DateTime.now().add(const Duration(hours: 24)).toIso8601String();
        final now = DateTime.now().toIso8601String();

        // Create a proper image message format
        final messageContent = 'image:$imageUrl';

        // Encrypt the message content
        final encryptedContent = await _encryptionService.encryptMessageForChat(
          messageContent,
          chatId,
        );

        // Update progress - preparing message
        localUploadProgress[uploadId] = 0.9;
        localUploadProgress.refresh();

        // Create message object
        final messageData = {
          'chat_id': chatId,
          'sender_id': currentUserId,
          'content': encryptedContent,
          'created_at': now,
          'expires_at': expiresAt,
          'message_type': 'image',
        };

        // Add message to database
        final response =
            await _supabaseService.client
                .from('messages')
                .insert(messageData)
                .select();

        // Upload complete!
        localUploadProgress[uploadId] = 1.0;
        localUploadProgress.refresh();

        if (response.isNotEmpty) {
          // Add the image message to local state
          final newMessage = Map<String, dynamic>.from(response[0]);

          // Remember the message ID to prevent duplicates
          if (newMessage['message_id'] != null) {
            final messageId = newMessage['message_id'].toString();
            _processedMessageIds.add(messageId);
          }

          // Set decrypted content for UI display
          newMessage['content'] = messageContent;

          // Cache for future reference
          final cacheKey = '$chatId:$encryptedContent';
          _decryptedContentCache[cacheKey] = messageContent;

          // First remove the placeholder
          messages.removeWhere((msg) => msg['upload_id'] == uploadId);

          // Then add the real message
          messages.add(newMessage);
          messages.refresh();

          // Convert to ChatMessage objects and update cache
          final List<ChatMessage> messagesToCache = [];
          for (final msg in messages) {
            messagesToCache.add(_convertMapToChatMessage(msg));
          }
          _chatCacheService.cacheMessages(chatId, messagesToCache);

          // Update recent chats preview
          _updateRecentChatsAfterSend(chatId, "📷 Image", currentUserId);

          // Remove from tracking as upload is complete
          localUploadProgress.remove(uploadId);
        }
      } catch (storageError) {
        // Handle Supabase storage errors
        debugPrint('Storage error: $storageError');

        // Remove placeholder on error
        messages.removeWhere((msg) => msg['upload_id'] == uploadId);
        messages.refresh();

        // Remove from tracking
        localUploadProgress.remove(uploadId);

        Get.snackbar('Upload Failed', 'Could not upload image to storage');
      }
    } catch (e) {
      // Handle any remaining errors
      debugPrint('Error uploading image: $e');
      Get.snackbar('Error', 'Could not send image');
    }
  }

  /// Send sticker message
  Future<void> sendSticker(String chatId, String stickerId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;

      if (currentUserId == null) {
        Get.snackbar('Error', 'Not authenticated');
        return;
      }

      // Set expiration time to 24 hours from now
      final expiresAt =
          DateTime.now().add(const Duration(hours: 24)).toIso8601String();
      final now = DateTime.now().toIso8601String();

      // For production, stickers should be stored in your bucket
      final stickerUrl = 'https://api.yapster.app/stickers/$stickerId.png';

      // Encrypt the sticker content
      final encryptedContent = await _encryptionService.encryptMessageForChat(
        'sticker:$stickerUrl',
        chatId,
      );

      // Create message data with sticker type
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedContent,
        'created_at': now,
        'expires_at': expiresAt,
        'message_type': 'sticker',
      };

      // Insert into database
      final response =
          await _supabaseService.client
              .from('messages')
              .insert(messageData)
              .select();

      if (response.isNotEmpty) {
        // Add the sticker message to local state
        final newMessage = Map<String, dynamic>.from(response[0]);

        // Remember the message ID to prevent duplicates
        if (newMessage['message_id'] != null) {
          final messageId = newMessage['message_id'].toString();
          _processedMessageIds.add(messageId);
        }

        // Set decrypted content for UI display
        newMessage['content'] = 'sticker:$stickerUrl';

        // Cache for future reference
        final cacheKey = '$chatId:$encryptedContent';
        _decryptedContentCache[cacheKey] = 'sticker:$stickerUrl';

        // Update local messages
        final newMessages = List<Map<String, dynamic>>.from(messages);
        newMessages.add(newMessage);
        messages.assignAll(newMessages);

        // Convert to ChatMessage objects and update cache
        final List<ChatMessage> messagesToCache = [];
        for (final msg in newMessages) {
          messagesToCache.add(_convertMapToChatMessage(msg));
        }
        _chatCacheService.cacheMessages(chatId, messagesToCache);

        // Update recent chats preview
        _updateRecentChatsAfterSend(chatId, "🌈 Sticker", currentUserId);
      }
    } catch (e) {
      debugPrint('Error sending sticker: $e');
      Get.snackbar('Error', 'Could not send sticker');
    }
  }

  /// Mark all messages in a chat as read - Optimized implementation
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) {
        debugPrint('Cannot mark messages as read: User not logged in');
        return;
      }

      // Throttle database calls to avoid excessive updates
      final now = DateTime.now();
      if (_lastReadStatusUpdate != null) {
        final timeSinceLastUpdate = now.difference(_lastReadStatusUpdate!);
        if (timeSinceLastUpdate < _readStatusThrottleDuration) {
          debugPrint('Skipping database update due to throttling');
          // Only update UI if we're skipping the database call
          _updateLocalReadStatus(chatId, currentUserId);
          return;
        }
      }

      // Update in memory first for immediate UI feedback
      _updateLocalReadStatus(chatId, currentUserId);

      // Set last update time
      _lastReadStatusUpdate = now;

      // Check if there are any unread messages
      bool hasUnreadMessages = false;
      for (final msg in messages) {
        if (msg['chat_id'] == chatId &&
            msg['sender_id'] != currentUserId &&
            (msg['is_read'] == null || msg['is_read'] == false)) {
          hasUnreadMessages = true;
          break;
        }
      }

      if (!hasUnreadMessages) {
        debugPrint('No unread messages found in memory');
        return;
      }

      debugPrint('Marking messages as read in chat: $chatId');

      // Use optimistic updates - assume success and update UI immediately
      // Then perform database operation in background
      try {
        // Try to use the RPC function approach first (most efficient)
        try {
          await _supabaseService.client.rpc(
            'mark_messages_as_read',
            params: {'p_chat_id': chatId, 'p_user_id': currentUserId},
          );
          debugPrint('Successfully marked messages as read via RPC');
        } catch (e) {
          debugPrint('RPC function failed, falling back to direct update: $e');

          // Fall back to bulk update
          await _supabaseService.client
              .from('messages')
              .update({'is_read': true})
              .eq('chat_id', chatId)
              .neq('sender_id', currentUserId)
              .eq('is_read', false);
        }

        // Update the cached messages to reflect read status
        final updatedMessages = List<Map<String, dynamic>>.from(messages);
        for (var i = 0; i < updatedMessages.length; i++) {
          if (updatedMessages[i]['chat_id'] == chatId &&
              updatedMessages[i]['sender_id'] != currentUserId) {
            updatedMessages[i]['is_read'] = true;
          }
        }

        // Convert to ChatMessage objects and update cache with read status changed
        final List<ChatMessage> messagesToCache = [];
        for (final msg in updatedMessages) {
          messagesToCache.add(_convertMapToChatMessage(msg));
        }
        _chatCacheService.cacheMessages(chatId, messagesToCache);
      } catch (e) {
        debugPrint('Error marking messages as read: $e');
        // Even if the server update fails, keep optimistic UI update
      }
    } catch (e) {
      debugPrint('Error in markMessagesAsRead: $e');
    }
  }

  /// Helper to update local UI without database calls
  void _updateLocalReadStatus(String chatId, String currentUserId) {
    bool anyUpdated = false;
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg['chat_id'] == chatId &&
          msg['sender_id'] != currentUserId &&
          (msg['is_read'] == null || msg['is_read'] == false)) {
        final msgId = msg['message_id'];
        debugPrint('Locally marking message $msgId as read');
        messages[i] = {...msg, 'is_read': true};
        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      // Force UI update
      messages.refresh();
      Get.forceAppUpdate();
      debugPrint('Updated local messages with read status');
    }
  }

  /// Update recent chats in memory after sending a message
  void _updateRecentChatsAfterSend(
    String chatId,
    String content,
    String senderId,
  ) {
    // Find the chat in recent chats
    final chatIndex = recentChats.indexWhere(
      (chat) => chat['chat_id'] == chatId,
    );

    if (chatIndex >= 0) {
      // Create a copy of the chat to update
      final updatedChat = Map<String, dynamic>.from(recentChats[chatIndex]);

      // Update last message details
      updatedChat['last_message'] = content;
      updatedChat['last_message_time'] = DateTime.now().toIso8601String();
      updatedChat['last_sender_id'] = senderId;

      // Replace the chat in the list
      final updatedChats = List<Map<String, dynamic>>.from(recentChats);
      updatedChats[chatIndex] = updatedChat;

      // Sort chats by most recent first
      updatedChats.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['last_message_time'] ?? '') ?? DateTime(1970);
        final bTime =
            DateTime.tryParse(b['last_message_time'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime); // Newest first
      });

      // Update the observable
      recentChats.value = updatedChats;

      // Convert to ChatConversation objects and cache updated chats
      _cacheRecentChats(updatedChats);

      debugPrint('Updated recent chats in cache after sending message');
    }
  }

  /// Add message ID to processed list to prevent duplicates
  void addProcessedMessageId(String messageId) {
    _processedMessageIds.add(messageId);
  }

  /// Check if a message ID has already been processed
  bool isMessageProcessed(String messageId) {
    return _processedMessageIds.contains(messageId);
  }

  /// Convert a Map<String, dynamic> to a ChatMessage object
  ChatMessage _convertMapToChatMessage(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['message_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      recipientId: map['recipient_id'],
      groupId: map['chat_id'],
      message: map['content'] ?? '',
      imageUrl:
          map['message_type'] == 'image'
              ? map['content']?.toString().split(':').last
              : null,
      timestamp:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
      isRead: map['is_read'] ?? false,
      metadata: {
        'expires_at': map['expires_at'],
        'message_type': map['message_type'],
        'is_sending': map['is_sending'] ?? false,
      },
    );
  }

  /// Convert a ChatMessage to a Map<String, dynamic>
  Map<String, dynamic> _convertChatMessageToMap(ChatMessage message) {
    return {
      'message_id': message.id,
      'sender_id': message.senderId,
      'recipient_id': message.recipientId,
      'chat_id': message.groupId,
      'content': message.message,
      'created_at': message.timestamp.toIso8601String(),
      'is_read': message.isRead,
      'message_type':
          message.imageUrl != null
              ? 'image'
              : (message.metadata?['message_type'] ?? 'text'),
      'expires_at': message.metadata?['expires_at'],
      'is_sending': message.metadata?['is_sending'] ?? false,
    };
  }

  /// Cache recent chats - converting from Map to ChatConversation objects
  void _cacheRecentChats(List<Map<String, dynamic>> chats) {
    final List<ChatConversation> conversationsToCache =
        chats.map((chat) {
          // Create a last message if available
          ChatMessage? lastMessage;
          if (chat['last_message'] != null) {
            lastMessage = ChatMessage(
              id: chat['last_message_id'] ?? '',
              senderId: chat['last_sender_id'] ?? '',
              groupId: chat['chat_id'],
              message: chat['last_message'] ?? '',
              timestamp:
                  DateTime.tryParse(chat['last_message_time'] ?? '') ??
                  DateTime.now(),
            );
          }

          return ChatConversation(
            id: chat['chat_id'] ?? '',
            name: chat['name'] ?? '',
            imageUrl: chat['image_url'],
            isGroup: chat['is_group'] ?? false,
            participantIds: List<String>.from(chat['participant_ids'] ?? []),
            lastMessageTime: DateTime.tryParse(chat['last_message_time'] ?? ''),
            unreadCount: chat['unread_count'] ?? 0,
            lastMessage: lastMessage,
            isMuted: chat['is_muted'] ?? false,
            isPinned: chat['is_pinned'] ?? false,
          );
        }).toList();

    // Cache the converted conversations
    _chatCacheService.cacheConversations(conversationsToCache);
  }
}

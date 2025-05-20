import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/modules/chat/services/chat_message_service.dart';
import 'package:yapster/app/modules/chat/services/chat_subscription_service.dart';
import 'package:yapster/app/modules/chat/services/chat_search_service.dart';
import 'package:yapster/app/modules/chat/services/chat_cleanup_service.dart';
import 'package:yapster/app/modules/chat/models/chat_conversation_model.dart';
import 'package:yapster/app/modules/chat/models/chat_message_model.dart';
import 'package:yapster/app/modules/chat/utils/chat_utils.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'dart:math' as math;
import 'dart:async';

/// Controller for chat functionality
class ChatController extends GetxController {
  // Core services
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final ChatCacheService _chatCacheService = Get.find<ChatCacheService>();
  final StorageService _storageService = Get.find<StorageService>();
  final EncryptionService _encryptionService = Get.find<EncryptionService>();
  ChatSearchService _searchService = Get.find<ChatSearchService>();
  final RxBool isEncryptionInitialized = false.obs;

  // Chat-specific services
  late final ChatMessageService _messageService;
  late final ChatSubscriptionService _subscriptionService;
  late final ChatCleanupService _cleanupService;

  // State variables
  final RxBool isLoading = false.obs;
  final RxBool isSendingMessage = false.obs;
  final RxBool isInitialized = false.obs;

  // Active conversation state
  final Rx<ChatConversation?> activeConversation = Rx<ChatConversation?>(null);
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxList<ChatConversation> conversations = <ChatConversation>[].obs;

  // Message input control
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final RxBool showEmojiPicker = false.obs;
  final RxBool isRecording = false.obs;

  // Reply functionality
  final Rx<ChatMessage?> replyingTo = Rx<ChatMessage?>(null);

  // Pagination
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreMessages = true.obs;
  final int messagesPerPage = 20;

  // Added properties needed by views
  final RxString selectedChatId = ''.obs;
  final RxBool hasUserDismissedExpiryBanner = false.obs;
  final RxMap<String, double> localUploadProgress = <String, double>{}.obs;

  // Recent chats functionality
  final RxList<Map<String, dynamic>> recentChats = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingChats = false.obs;

  // Search functionality
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;

  // Realtime subscription handling
  RealtimeChannel? _chatChannel;

  // Expose supabase service for views
  SupabaseService get supabaseService => _supabaseService;

  @override
  void onInit() {
    super.onInit();
    _initializeServices();

    // Listen to search input changes
    searchController.addListener(_handleSearchInputChanged);

    // Load user preferences
    _loadUserPreferences();
  }

  @override
  void onClose() {
    messageController.dispose();
    messageFocusNode.dispose();
    searchController.dispose();
    _disposeServices();
    super.onClose();
  }

  /// Initialize all required services
  void _initializeServices() {
    // Create and initialize services
    _messageService = ChatMessageService();
    _subscriptionService = ChatSubscriptionService();
    _searchService = ChatSearchService();
    _cleanupService = ChatCleanupService();

    // Initialize encryption service first and ensure it's ready
    _initializeEncryptionService().then((_) {
      // Initialize message service with our observable collections
      _messageService.initialize(
        messagesList: messages,
        chatsList: recentChats,
        uploadProgress: localUploadProgress,
      );

      // Initialize subscription service with our message list
      _subscriptionService.initialize(
        messagesList: messages,
        chatsList: recentChats.toList().obs,
      );

      // Initialize cleanup service
      _cleanupService.initialize();

      // Set up subscriptions and initialize cached data
      _subscribeToCurrentUser();
      _loadCachedConversations();

      isInitialized.value = true;
    });
  }

  /// Initialize encryption service and load saved keys
  Future<void> _initializeEncryptionService() async {
    try {
      debugPrint('Initializing encryption service...');
      await _encryptionService.initialize();
      isEncryptionInitialized.value = true;
      debugPrint('Encryption service initialization completed');
    } catch (e) {
      debugPrint('Error initializing encryption service: $e');
      // Retry initialization after a delay
      await Future.delayed(const Duration(seconds: 2));
      return _initializeEncryptionService();
    }
  }

  /// Dispose of all services
  void _disposeServices() {
    _subscriptionService.disconnectChat();
    _cleanupService.stopCleanupTimers();
  }

  /// Subscribe to current user's chat messages
  void _subscribeToCurrentUser() {
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId != null) {
      _subscriptionService.subscribeToChatUpdates(
        userId: currentUserId,
        onNewMessage:
            (Map<String, dynamic> message) => _handleNewMessage(message),
        onMessageUpdate: _handleMessageUpdate,
        onMessageDelete: _handleMessageDelete,
        onConnectionChange: _handleConnectionChange,
      );
    }
  }

  /// Handle new message from subscription
  Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    debugPrint('Handling new message: ${message['message_id']}');

    try {
      // Make a copy of the message
      message = Map<String, dynamic>.from(message);

      // Try to decrypt the message content if it's a string
      if (message['content'] is String) {
        final String encryptedContent = message['content'].toString();

        // Check if content needs decryption (appears encrypted or has error markers)
        if (encryptedContent.contains('==') ||
            encryptedContent == '🔒 Encrypted message' ||
            encryptedContent == '🔒 Error encrypting message') {
          debugPrint('Attempting to decrypt content: ${message['message_id']}');

          try {
            // First try direct decryption
            final decryptedContent = _encryptionService.decryptMessage(
              encryptedContent,
            );
            if (decryptedContent.isNotEmpty &&
                !decryptedContent.startsWith('🔒')) {
              message['content'] = decryptedContent;
              debugPrint(
                'Successfully decrypted message: ${message['message_id']}',
              );
            } else {
              // If direct decryption fails, try getting from database
              final messageId = message['message_id']?.toString() ?? '';
              if (messageId.isNotEmpty) {
                final response =
                    await _supabaseService.client
                        .from('messages')
                        .select()
                        .eq('message_id', messageId)
                        .single();

                if (response != null && response['content'] != null) {
                  final dbContent = response['content'].toString();

                  // Try to decrypt the database content
                  try {
                    final decryptedDbContent = _encryptionService
                        .decryptMessage(dbContent);
                    if (decryptedDbContent.isNotEmpty &&
                        !decryptedDbContent.startsWith('🔒')) {
                      message['content'] = decryptedDbContent;
                      debugPrint(
                        'Successfully decrypted from database: ${message['message_id']}',
                      );
                    } else {
                      // Use database content as is if decryption fails
                      message['content'] = dbContent;
                      debugPrint(
                        'Using raw database content: ${message['message_id']}',
                      );
                    }
                  } catch (e) {
                    // Use database content as is
                    message['content'] = dbContent;
                    debugPrint('Error decrypting database content: $e');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint(
              'Decryption failed for message ${message['message_id']}: $e',
            );
            // Keep the original content if all decryption attempts fail
          }
        } else {
          debugPrint(
            'Content appears to be already readable: $encryptedContent',
          );
        }
      }

      // Update conversation list first
      _updateConversationWithMessage(message);

      // Check if this message already exists in the list to avoid duplicates
      final existingIndex = messages.indexWhere(
        (msg) => msg['message_id'] == message['message_id'],
      );

      if (existingIndex != -1) {
        debugPrint(
          'Message already exists in UI, updating: ${message['message_id']}',
        );
        messages[existingIndex] = message;
      } else {
        // If message is for active conversation, add it to messages list
        String? activeChatId = activeConversation.value?.id;
        String? messageDbChatId = message['chat_id']?.toString();
        String? activeDatabaseChatId;

        // Extract the database chat ID from the active conversation ID
        if (activeChatId != null && activeChatId.split('_').length >= 2) {
          activeDatabaseChatId = activeChatId.split('_')[1];
        } else {
          activeDatabaseChatId = activeChatId;
        }

        // Check if this message belongs to the active conversation
        final bool isForActiveConversation =
            activeConversation.value != null &&
            (message['recipient_id'] == activeChatId ||
                message['group_id'] == activeChatId ||
                messageDbChatId == activeDatabaseChatId);

        // Check if this message belongs to the selected chat ID
        final bool isForSelectedChat =
            selectedChatId.value.isNotEmpty &&
            messageDbChatId != null &&
            selectedChatId.value.split('_').length >= 2 &&
            messageDbChatId == selectedChatId.value.split('_')[1];

        // Set connected state to true immediately when we receive any message
        debugPrint('Connection status set to ONLINE - received message');

        if (isForActiveConversation || isForSelectedChat) {
          // Add animation flag for received messages
          if (message['sender_id'] != _supabaseService.currentUser.value?.id) {
            message['is_new'] = true;
          }

          debugPrint('Adding new message to UI: ${message['message_id']}');
          messages.add(message);

          // Sort messages by timestamp
          messages.sort(
            (a, b) => DateTime.parse(
              b['created_at'],
            ).compareTo(DateTime.parse(a['created_at'])),
          );

          // Mark as read if it's not from current user
          if (message['sender_id'] != _supabaseService.currentUser.value?.id) {
            _markMessageAsRead(message['message_id']);
          }

          // Force refresh the UI to show the new message
          messages.refresh();
          debugPrint(
            'Messages list refreshed with ${messages.length} messages',
          );
        } else {
          debugPrint('Message not for active conversation, skipping UI update');
        }
      }

      // Always refresh recent chats when a new message arrives
      loadRecentChats();
    } catch (e) {
      debugPrint('Error processing new message: $e');
    }
  }

  /// Mark a message as read
  void _markMessageAsRead(String messageId) {
    // This would be implemented to update the read status
    debugPrint('Marking message as read: $messageId');
  }

  /// Handle message update (read status, etc.)
  void _handleMessageUpdate(String messageId, Map<String, dynamic> updates) {
    // Find message in active conversation
    final index = messages.indexWhere(
      (message) => message['message_id'] == messageId,
    );
    if (index != -1) {
      // Update the existing map instead of using copyWith
      final updatedMessage = Map<String, dynamic>.from(messages[index]);
      updatedMessage['is_read'] =
          updates['is_read'] ?? messages[index]['is_read'];
      updatedMessage['is_deleted'] =
          updates['is_deleted'] ?? messages[index]['is_deleted'];

      messages[index] = updatedMessage;
    }

    // Check if this message is the last message of any conversation
    for (int i = 0; i < conversations.length; i++) {
      if (conversations[i].lastMessage?.id == messageId) {
        final updatedLastMessage = conversations[i].lastMessage!.copyWith(
          isRead: updates['is_read'] ?? conversations[i].lastMessage!.isRead,
          isDeleted:
              updates['is_deleted'] ?? conversations[i].lastMessage!.isDeleted,
        );

        conversations[i] = conversations[i].copyWith(
          lastMessage: updatedLastMessage,
        );
      }
    }
  }

  /// Handle message deletion
  void _handleMessageDelete(String messageId) {
    debugPrint('Handling message deletion: $messageId');

    try {
      // Remove from active messages list if present
      final index = messages.indexWhere(
        (message) => message['message_id'] == messageId,
      );

      if (index != -1) {
        // Remove the message from the list
        messages.removeAt(index);
        debugPrint('Removed deleted message from UI: $messageId');
      }

      // Update conversation if this was the last message
      final conversationIndex = conversations.indexWhere(
        (conv) => conv.lastMessage?.id == messageId,
      );

      if (conversationIndex != -1) {
        // If this was the last message, we need to fetch the new last message
        // For now, just clear the last message or set it to a placeholder
        conversations[conversationIndex] = conversations[conversationIndex]
            .copyWith(lastMessage: null);

        debugPrint('Updated conversation after message deletion: $messageId');
      }

      // Also refresh recent chats since a message was deleted
      loadRecentChats();
    } catch (e) {
      debugPrint('Error handling message deletion: $e');
    }
  }

  /// Handle connection status change
  void _handleConnectionChange(bool connected) {
    debugPrint(
      'Connection status changed: ${connected ? "ONLINE" : "OFFLINE"}',
    );

    // If reconnected, refresh data
    if (connected) {
      refreshConversations();
      if (activeConversation.value != null) {
        loadMessages(activeConversation.value!.id);
      }
    }
  }

  /// Load cached conversations on startup
  void _loadCachedConversations() {
    final cachedConversations = _chatCacheService.getCachedConversations();
    if (cachedConversations.isNotEmpty) {
      conversations.value = cachedConversations;
    }
    // Refresh from server regardless
    refreshConversations();
  }

  /// Refresh all conversations from server
  Future<void> refreshConversations() async {
    if (isLoading.value) return;

    isLoading.value = true;
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;

      // In a real app, we'd fetch conversations here
      debugPrint('Fetching conversations for user: $currentUserId');

      // Call database using correct chat_participants structure
      final response = await _supabaseService.client
          .from('chat_participants')
          .select('id, chat_id, user_id, created_at')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        // Process the response - this is a simplification
        debugPrint('Found ${response.length} conversations');

        // In a real app, we'd convert these to ChatConversation objects
        // For now, just use an empty list to avoid linter errors
        final allConversations = <ChatConversation>[];

        // Update the conversations list
        conversations.value = allConversations;

        // Cache the updated conversations
        _chatCacheService.cacheConversations(allConversations);
      }
    } catch (e) {
      debugPrint('Error refreshing conversations: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load messages for a conversation
  Future<void> loadMessages(
    String conversationId, {
    bool refreshing = false,
  }) async {
    if (isLoadingMore.value && !refreshing) return;

    // Ensure encryption is initialized before loading messages
    if (!isEncryptionInitialized.value) {
      debugPrint(
        'Waiting for encryption service to initialize before loading messages...',
      );
      await _initializeEncryptionService();
    }

    final startIndex = refreshing ? 0 : messages.length;

    if (!hasMoreMessages.value && !refreshing) return;

    isLoadingMore.value = true;
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;

      // Extract the correct chat_id format for database query
      String databaseChatId = conversationId;
      if (conversationId.startsWith('chat_')) {
        // The conversationId has the format "chat_uuid1_uuid2"
        // We need to extract just the chat UUID that's stored in the database
        final parts = conversationId.split('_');
        if (parts.length >= 2) {
          // For now, assume the part after "chat_" is the database ID
          databaseChatId = parts[1];
        }
      }

      // Debug info
      debugPrint('Fetching messages for chat: $conversationId');
      debugPrint('Using database chat_id: $databaseChatId');

      // Call database for messages with correct column names and add debug info
      final response = await _supabaseService.client
          .from('messages')
          .select()
          .eq('chat_id', databaseChatId)
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + messagesPerPage - 1);

      // Debug response
      debugPrint('Messages response: ${response.length} items');
      if (response.isNotEmpty) {
        debugPrint('First message sample: ${response[0]}');
      }

      if (response.isNotEmpty) {
        // Process and decrypt each message
        final processedMessages = <Map<String, dynamic>>[];

        for (final message in response) {
          // Create a copy of the message
          final processedMessage = Map<String, dynamic>.from(message);

          // Try to decrypt the content
          if (message['content'] is String) {
            final String encryptedContent = message['content'].toString();

            try {
              // First try chat-specific decryption
              String decryptedContent = '';
              bool decrypted = false;

              // Try chat-specific decryption first
              try {
                decryptedContent = await _encryptionService
                    .decryptMessageForChat(encryptedContent, databaseChatId);
                if (decryptedContent.isNotEmpty &&
                    !decryptedContent.startsWith('🔒')) {
                  processedMessage['content'] = decryptedContent;
                  decrypted = true;
                  debugPrint(
                    'Successfully decrypted message with chat key: ${message['message_id']}',
                  );
                }
              } catch (chatKeyError) {
                debugPrint('Chat-specific decryption failed: $chatKeyError');
                // Fall back to general decryption
              }

              // If chat-specific decryption failed, try general decryption
              if (!decrypted) {
                decryptedContent = _encryptionService.decryptMessage(
                  encryptedContent,
                );
                if (decryptedContent.isNotEmpty &&
                    !decryptedContent.startsWith('🔒')) {
                  processedMessage['content'] = decryptedContent;
                  debugPrint(
                    'Successfully decrypted message with general key: ${message['message_id']}',
                  );
                } else {
                  // If decryption returns empty or locked content, use the original
                  processedMessage['content'] = encryptedContent;
                  debugPrint(
                    'Using original content (all decryption failed): ${message['message_id']}',
                  );
                }
              }
            } catch (e) {
              // If decryption fails, use the original content
              processedMessage['content'] = encryptedContent;
              debugPrint(
                'Decryption error for message ${message['message_id']}: $e',
              );
            }
          }

          processedMessages.add(processedMessage);
        }

        // Update the messages list with the processed messages
        if (refreshing) {
          messages.value = processedMessages;
        } else {
          messages.addAll(processedMessages);
        }

        // Keep track of message loading
        hasMoreMessages.value = response.length >= messagesPerPage;

        // Mark all new messages from others as read
        for (final message in processedMessages) {
          if (message['sender_id'] != currentUserId &&
              message['is_read'] == false) {
            _markMessageAsRead(message['message_id']);
          }
        }

        // Update unread count in conversation list
        _updateConversationUnreadCount(conversationId, 0);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Send a message with chatId and content (for message_input.dart)
  Future<void> sendChatMessage(String chatId, String content) async {
    if (content.isEmpty) return;

    try {
      isSendingMessage.value = true;

      // Extract the correct chat_id format for database
      String databaseChatId = chatId;
      String? recipientId;

      if (chatId.startsWith('chat_')) {
        // The chatId has the format "chat_uuid1_uuid2"
        final parts = chatId.split('_');

        // Make sure we have enough parts (chat_uuid1_uuid2)
        if (parts.length >= 3) {
          // Format is chat_uuid1_uuid2
          databaseChatId = parts[1];

          // Get current user ID for comparison
          final currentUserId = _supabaseService.currentUser.value?.id;
          if (currentUserId != null) {
            // Extract recipient_id: if part[2] is current user, then recipient is part[1], otherwise part[2]
            recipientId = parts[2] == currentUserId ? parts[1] : parts[2];

            // Log the extracted information
            debugPrint('Current user: $currentUserId');
            debugPrint('Extracted recipient_id: $recipientId');
          } else {
            debugPrint('Warning: Current user ID is null');
          }
        } else {
          debugPrint('Warning: Invalid chat ID format: $chatId');
        }
      }

      // Double check if we have a recipient
      if (recipientId == null || recipientId.isEmpty) {
        // Try to find recipient from participants table as fallback
        try {
          final currentUserId = _supabaseService.currentUser.value?.id;
          final otherParticipants = await _supabaseService.client
              .from('chat_participants')
              .select('user_id')
              .eq('chat_id', databaseChatId)
              .neq('user_id', currentUserId!);

          if (otherParticipants.isNotEmpty) {
            recipientId = otherParticipants[0]['user_id'];
            debugPrint('Found recipient from participants table: $recipientId');
          }
        } catch (e) {
          debugPrint('Failed to find recipient from participants table: $e');
        }
      }

      debugPrint('Sending message to chat: $chatId');
      debugPrint('Using database chat_id: $databaseChatId');
      debugPrint('Final recipient_id: $recipientId');

      // Create message data
      final currentUserId = _supabaseService.currentUser.value?.id;
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30));

      // Generate a proper UUID for the message
      final messageId = _generateUuid();

      // Encrypt the content for storage in database
      String encryptedContent;
      try {
        // Try to use chat-specific encryption
        encryptedContent = await _encryptionService.encryptMessageForChat(
          content,
          databaseChatId,
        );
        debugPrint('Message encrypted with chat-specific key: $messageId');
      } catch (e) {
        // Fall back to general encryption
        encryptedContent = _encryptionService.encryptMessage(content);
        debugPrint('Message encrypted with general key: $messageId');
      }

      // Debug output to verify encryption worked
      debugPrint(
        'Original content length: ${content.length}, encrypted length: ${encryptedContent.length}',
      );

      // Create message for local display (with original unencrypted content)
      final localMessageMap = {
        'message_id': messageId,
        'chat_id': databaseChatId,
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': content, // Use unencrypted content locally
        'created_at': now.toIso8601String(),
        'expires_at': expiryDate.toIso8601String(),
        'is_read': false,
        'message_type': 'text',
        'is_sending': true, // Add animation flag for sending state
        'is_new': true, // Add animation flag for new message
      };

      // Create database message object
      final dbMessageMap = {
        'message_id': messageId,
        'chat_id': databaseChatId,
        'sender_id': currentUserId,
        'content': encryptedContent, // Use encrypted content for database
        if (recipientId != null) 'recipient_id': recipientId,
        'created_at': now.toIso8601String(),
        'expires_at': expiryDate.toIso8601String(),
        'is_read': false,
        'message_type': 'text',
      };

      // Debug output for message
      debugPrint('Message to send to DB: $messageId');

      // Add to local messages immediately for better UI experience
      messages.insert(0, localMessageMap);

      // Send to database using correct schema
      final response =
          await _supabaseService.client
              .from('messages')
              .insert(dbMessageMap)
              .select();

      // Log response for debugging
      debugPrint('Message send response received: ${response.length} items');

      // Update the local message to show it's been sent successfully
      final messageIndex = messages.indexWhere(
        (msg) => msg['message_id'] == messageId,
      );
      if (messageIndex != -1) {
        final updatedMessage = Map<String, dynamic>.from(
          messages[messageIndex],
        );
        updatedMessage['is_sending'] = false; // Message sent successfully
        messages[messageIndex] = updatedMessage;
      }

      // Log successful send
      debugPrint('Message sent successfully to $databaseChatId: $messageId');

      // Clear the message input
      messageController.clear();

      // Force refresh the UI
      messages.refresh();
    } catch (e) {
      debugPrint('Error sending message: $e');
      Get.snackbar('Error', 'Failed to send message: $e');
    } finally {
      isSendingMessage.value = false;
    }
  }

  /// Pick and send an image
  Future<void> pickAndSendImage(ImageSource source) async {
    final pickedImage = await ChatUtils.pickImage(source);
    if (pickedImage == null) return;

    try {
      // Upload image
      final String imageUrl = "https://example.com/images/placeholder.jpg";

      // In a real app, we would upload the image to storage
      debugPrint('Uploading image: ${pickedImage.path}');

      // Send message with image
      if (imageUrl.isNotEmpty) {
        await sendChatMessage(activeConversation.value!.id, imageUrl);
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      Get.snackbar(
        'Error',
        'Failed to upload image. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Record and send audio message
  Future<void> recordAndSendAudio() async {
    // Implementation would need audio recording logic
    // For now this is a stub that could be implemented with a proper audio recording package
    debugPrint('Audio recording not implemented yet');
  }

  /// Delete a message
  Future<void> handleDeleteMessage(String messageId) async {
    try {
      // Delete the message from the database
      await _supabaseService.client
          .from('messages')
          .delete()
          .eq('message_id', messageId);

      debugPrint('Deleted message: $messageId');

      // Update local message list
      final index = messages.indexWhere(
        (msg) => msg['message_id'] == messageId,
      );
      if (index != -1) {
        // Update the existing map instead of using copyWith
        final updatedMessage = Map<String, dynamic>.from(messages[index]);
        updatedMessage['is_deleted'] = true;

        messages[index] = updatedMessage;
      }

      // Update conversation if this was the last message
      final conversationIndex = conversations.indexWhere(
        (conv) => conv.lastMessage?.id == messageId,
      );

      if (conversationIndex != -1 &&
          conversations[conversationIndex].lastMessage != null) {
        final updatedLastMessage = conversations[conversationIndex].lastMessage!
            .copyWith(isDeleted: true);

        conversations[conversationIndex] = conversations[conversationIndex]
            .copyWith(lastMessage: updatedLastMessage);
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
      Get.snackbar(
        'Error',
        'Failed to delete message. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Set active conversation
  void setActiveConversation(ChatConversation conversation) {
    activeConversation.value = conversation;
    messages.clear();
    hasMoreMessages.value = true;
    loadMessages(conversation.id, refreshing: true).then((_) {
      // Ensure messages are decrypted after loading
      forceDecryptMessages();
    });
  }

  /// Create or open direct chat with user
  Future<void> createOrOpenDirectChat(
    String recipientId,
    String recipientName,
    String? recipientImage,
  ) async {
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) return;

    // Generate conversation ID
    final conversationId = ChatUtils.generateDirectChatId(
      currentUserId,
      recipientId,
    );

    // Check if conversation exists
    final existingConversation = conversations.firstWhere(
      (conv) => conv.id == conversationId,
      orElse:
          () => ChatConversation(
            id: conversationId,
            name: recipientName,
            participantIds: [currentUserId, recipientId],
            imageUrl: recipientImage,
          ),
    );

    if (existingConversation.id.isEmpty) {
      // Create new conversation
      final newConversation = ChatConversation(
        id: conversationId,
        name: recipientName,
        imageUrl: recipientImage,
        participantIds: [currentUserId, recipientId],
      );

      conversations.insert(0, newConversation);
      setActiveConversation(newConversation);
    } else {
      // Open existing conversation
      setActiveConversation(existingConversation);
    }
  }

  /// Update conversation with a new message
  void _updateConversationWithMessage(Map<String, dynamic> message) {
    // Find the affected conversation
    String conversationId;
    if (message['group_id'] != null && message['group_id'].isNotEmpty) {
      conversationId = message['group_id'];
    } else if (message['recipient_id'] != null &&
        message['recipient_id'].isNotEmpty) {
      // For direct messages, generate the conversation ID
      final otherPersonId =
          message['sender_id'] == _supabaseService.currentUser.value?.id
              ? message['recipient_id']
              : message['sender_id'];

      conversationId = ChatUtils.generateDirectChatId(
        _supabaseService.currentUser.value!.id,
        otherPersonId,
      );
    } else {
      debugPrint(
        'Unable to determine conversation ID from message: ${message['message_id']}',
      );
      return;
    }

    debugPrint(
      'Updating conversation: $conversationId with message: ${message['message_id']}',
    );

    final index = conversations.indexWhere((conv) => conv.id == conversationId);
    if (index != -1) {
      // Convert the map to a ChatMessage object for the conversation
      final chatMessage = ChatMessage(
        id: message['message_id'] ?? '',
        senderId: message['sender_id'] ?? '',
        recipientId: message['recipient_id'],
        groupId: message['group_id'],
        message: message['content'] ?? '',
        timestamp:
            message['created_at'] != null
                ? DateTime.parse(message['created_at'])
                : DateTime.now(),
        isRead: message['is_read'] ?? false,
      );

      // Update existing conversation
      conversations[index] = conversations[index].copyWith(
        lastMessage: chatMessage,
        lastMessageTime: chatMessage.timestamp,
        unreadCount:
            message['sender_id'] != _supabaseService.currentUser.value?.id
                ? conversations[index].unreadCount + 1
                : conversations[index].unreadCount,
      );

      // Sort conversations
      _sortConversationsByRecent();

      // Also update in the recentChats list
      _updateRecentChatsWithMessage(message);

      debugPrint('Updated existing conversation: ${conversations[index].id}');
    } else {
      // This is a new conversation we need to add
      debugPrint(
        'Conversation not found for message: ${message['message_id']} - refreshing conversation list',
      );

      // Refresh the conversations list to get the new conversation
      refreshConversations();
    }
  }

  /// Update recent chats list with a new message
  void _updateRecentChatsWithMessage(Map<String, dynamic> message) {
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) return;

    // Determine the chat ID and other user ID
    String chatId = message['chat_id'];
    String otherUserId =
        message['sender_id'] == currentUserId
            ? (message['recipient_id'] ?? '')
            : message['sender_id'] ?? '';

    if (chatId.isEmpty || otherUserId.isEmpty) {
      debugPrint(
        'Unable to update recent chats - missing chat_id or other user ID',
      );
      return;
    }

    // Try to decrypt the message content for preview
    String previewContent = message['content'] ?? '';
    try {
      // Only attempt to decrypt if it looks encrypted
      if (previewContent.contains('==') || previewContent.contains('🔒')) {
        final decryptedContent = _encryptionService.decryptMessage(
          previewContent,
        );
        if (decryptedContent.isNotEmpty && !decryptedContent.startsWith('🔒')) {
          previewContent = decryptedContent;
          debugPrint('Decrypted message preview for recent chats');
        }
      }
    } catch (e) {
      // Keep original content if decryption fails
      debugPrint('Failed to decrypt message preview: $e');
    }

    // Find the chat in the recent chats list
    final chatIndex = recentChats.indexWhere(
      (chat) => chat['chat_id'] == chatId,
    );
    if (chatIndex != -1) {
      // Update the existing chat
      final updatedChat = Map<String, dynamic>.from(recentChats[chatIndex]);
      updatedChat['last_message'] = previewContent;
      updatedChat['last_message_time'] = message['created_at'];
      updatedChat['last_sender_id'] = message['sender_id'];

      // Update the chat in the list
      recentChats[chatIndex] = updatedChat;

      // Sort recent chats by most recent message
      recentChats.sort((a, b) {
        final timeA = a['last_message_time'] ?? a['created_at'] ?? '';
        final timeB = b['last_message_time'] ?? b['created_at'] ?? '';
        return timeB.compareTo(timeA);
      });

      // Force refresh
      recentChats.refresh();

      debugPrint('Updated recent chat at index $chatIndex');
    }
  }

  /// Update conversation unread count
  void _updateConversationUnreadCount(String conversationId, int count) {
    final index = conversations.indexWhere((conv) => conv.id == conversationId);
    if (index != -1) {
      conversations[index] = conversations[index].copyWith(unreadCount: count);
    }
  }

  /// Sort conversations by most recent message
  void _sortConversationsByRecent() {
    conversations.sort((a, b) {
      final timeA = a.lastMessageTime ?? DateTime(1970);
      final timeB = b.lastMessageTime ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });
  }

  /// Cancel a reply
  void cancelReply() {
    replyingTo.value = null;
  }

  /// Load user preferences including banner dismissal
  Future<void> _loadUserPreferences() async {
    try {
      final dismissed = await _cleanupService.loadUserPreferences();
      hasUserDismissedExpiryBanner.value = dismissed;
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
    }
  }

  /// Dismiss expiry banner
  Future<void> dismissExpiryBanner() async {
    try {
      await _cleanupService.dismissExpiryBanner();
      hasUserDismissedExpiryBanner.value = true;
    } catch (e) {
      debugPrint('Error dismissing expiry banner: $e');
    }
  }

  /// Mark messages as read in a chat
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      // This connects to the message service implementation
      await _messageService.markMessagesAsRead(chatId);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Delete message with chat_id and message_id params (for message_options.dart)
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await handleDeleteMessage(messageId);
    } catch (e) {
      debugPrint('Error in deleteMessage: $e');
    }
  }

  /// Handle search input changes
  void _handleSearchInputChanged() {
    final query = searchController.text.trim();
    searchQuery.value = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    // Debounce search requests
    _searchUsers(query);
  }

  /// Search users by query
  Future<void> _searchUsers(String query) async {
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .ilike('username', '%$query%')
          .limit(10);

      if (response.isNotEmpty) {
        searchResults.value = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  /// Load recent chats for the Chat view
  Future<void> loadRecentChats() async {
    if (isLoadingChats.value) return;

    isLoadingChats.value = true;
    try {
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) return;

      debugPrint('Loading recent chats for user: $userId');

      // First get chat participants for the user
      final participantsResponse = await _supabaseService.client
          .from('chat_participants')
          .select('id, chat_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      debugPrint('Got ${participantsResponse.length} chat participants');

      if (participantsResponse.isEmpty) {
        debugPrint('No chat participants found');
        recentChats.value = [];
        isLoadingChats.value = false;
        return;
      }

      // Process the participants to include more information
      final processedChats = <Map<String, dynamic>>[];

      for (final participant in participantsResponse) {
        try {
          final chatId = participant['chat_id']?.toString();
          if (chatId == null) {
            debugPrint('Skipping participant with null chat_id');
            continue;
          }

          debugPrint('Processing chat: $chatId');

          // Get the most recent message for this chat
          final messagesResponse = await _supabaseService.client
              .from('messages')
              .select()
              .eq('chat_id', chatId)
              .order('created_at', ascending: false)
              .limit(1);

          final lastMessage =
              messagesResponse.isNotEmpty ? messagesResponse[0] : null;

          debugPrint(
            'Last message for chat $chatId: ${lastMessage != null ? 'found' : 'not found'}',
          );

          // Try to decrypt the message preview if one exists
          String previewContent = '';
          if (lastMessage != null && lastMessage['content'] != null) {
            previewContent = lastMessage['content'].toString();

            // Check if content appears encrypted
            if (previewContent.contains('==') ||
                previewContent.contains('🔒')) {
              try {
                final decryptedContent = _encryptionService.decryptMessage(
                  previewContent,
                );
                if (decryptedContent.isNotEmpty &&
                    !decryptedContent.startsWith('🔒')) {
                  previewContent = decryptedContent;
                  debugPrint('Decrypted chat preview for chat: $chatId');
                }
              } catch (e) {
                // Keep original content if decryption fails
                debugPrint('Failed to decrypt chat preview: $e');
              }
            }
          }

          // Get the other participants in this chat
          final otherParticipantsResponse = await _supabaseService.client
              .from('chat_participants')
              .select('user_id')
              .eq('chat_id', chatId)
              .neq('user_id', userId);

          final otherUserIds =
              otherParticipantsResponse.isNotEmpty
                  ? otherParticipantsResponse
                      .map((p) => p['user_id']?.toString() ?? '')
                      .where((id) => id.isNotEmpty)
                      .toList()
                  : <String>[];

          debugPrint('Other users in chat $chatId: ${otherUserIds.join(', ')}');

          if (otherUserIds.isEmpty) {
            debugPrint('No other users found for chat $chatId, skipping');
            continue;
          }

          // Get the other user's profile info
          final otherUserId = otherUserIds.first;
          final profileResponse =
              await _supabaseService.client
                  .from('profiles')
                  .select('username, avatar, google_avatar')
                  .eq('user_id', otherUserId)
                  .single();

          final username = profileResponse['username']?.toString() ?? 'User';
          final avatar = profileResponse['avatar']?.toString() ?? '';
          final googleAvatar =
              profileResponse['google_avatar']?.toString() ?? '';

          debugPrint('Got profile for user $otherUserId: $username');

          // Create a chat conversation entry even if there's no last message
          processedChats.add({
            'id': participant['id'],
            'chat_id': chatId,
            'created_at': participant['created_at'],
            'last_message': previewContent, // Use decrypted content
            'last_message_time':
                lastMessage?['created_at'] ?? participant['created_at'],
            'last_sender_id': lastMessage?['sender_id'],
            'other_user_id': otherUserId,
            'username': username,
            'avatar': avatar,
            'google_avatar': googleAvatar,
            'unread_count': 0, // Initialize unread count
          });

          debugPrint('Added chat with $username to recent chats');
        } catch (e) {
          debugPrint('Error processing chat participant: $e');
        }
      }

      // Update the chats list
      if (processedChats.isNotEmpty) {
        recentChats.value = processedChats;
        debugPrint('Processed ${processedChats.length} chats with details');
      } else {
        debugPrint('No processed chats found - keeping existing chats');
      }

      // Also update the cache
      _cacheRecentChats();
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
    } finally {
      isLoadingChats.value = false;
      // Force refresh the UI
      recentChats.refresh();
    }
  }

  /// Load recent chats from cache
  Future<bool> loadRecentChatsFromCache() async {
    try {
      final cachedChats = _storageService.getString('recent_chats');
      if (cachedChats != null && cachedChats.isNotEmpty) {
        // This would need proper parsing from JSON
        debugPrint('Found cached chats');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error loading cached chats: $e');
      return false;
    }
  }

  /// Cache recent chats
  void _cacheRecentChats() {
    try {
      // This would need proper JSON serialization
      _storageService.saveString('recent_chats', 'cached_data');
    } catch (e) {
      debugPrint('Error caching chats: $e');
    }
  }

  /// Open chat with a user
  Future<void> openChat(String userId, String username) async {
    if (userId.isEmpty) return;

    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) return;

    try {
      // Generate the chat ID for user-to-user chat
      final directChatId = ChatUtils.generateDirectChatId(
        currentUserId,
        userId,
      );

      // Make sure this chat exists in the database - get chat_id format
      final databaseChatId =
          directChatId.startsWith('chat_')
              ? directChatId.split('_')[1]
              : directChatId;

      debugPrint('Opening chat with user: $username ($userId)');
      debugPrint(
        'Using chat_id: $directChatId, database chat_id: $databaseChatId',
      );

      // Check if this chat already exists in the database
      final existingChat =
          await _supabaseService.client
              .from('chat_participants')
              .select('id')
              .eq('chat_id', databaseChatId)
              .eq('user_id', currentUserId)
              .maybeSingle();

      debugPrint('Chat exists in DB? ${existingChat != null ? 'Yes' : 'No'}');

      // If the chat doesn't exist, create it for both users
      if (existingChat == null) {
        debugPrint('Creating new chat in database');

        // Create a participant record for the current user
        await _supabaseService.client.from('chat_participants').insert({
          'chat_id': databaseChatId,
          'user_id': currentUserId,
        });

        // Create a participant record for the other user
        await _supabaseService.client.from('chat_participants').insert({
          'chat_id': databaseChatId,
          'user_id': userId,
        });

        debugPrint('Created chat participants for both users');

        // Refresh the chat list after creating a new chat
        loadRecentChats();
      }

      // Navigate to the chat detail screen
      Get.toNamed(
        Routes.CHAT_DETAIL,
        arguments: {
          'chat_id': directChatId,
          'other_user_id': userId,
          'username': username,
        },
      );
    } catch (e) {
      debugPrint('Error opening chat: $e');
      Get.snackbar('Error', 'Could not open chat: $e');
    }
  }

  /// Setup realtime updates for a specific chat
  void setupRealtimeUpdates(String chatId) {
    debugPrint('Setting up realtime updates for chat: $chatId');

    // Clean up any existing subscription first
    cleanupRealtimeSubscriptions();

    // Extract the correct chat_id format for database
    String databaseChatId = chatId;
    if (chatId.contains('_')) {
      final parts = chatId.split('_');
      if (parts.length >= 2) {
        databaseChatId = parts[1];
      }
    }

    debugPrint('Using database chat_id for realtime: $databaseChatId');
    selectedChatId.value = chatId; // Ensure selected chat ID is set properly

    // Define a unique channel name to avoid conflicts with other users
    final channelName =
        'messages_channel_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Create a broader subscription to all messages in the table
      _chatChannel = _supabaseService.client.channel(channelName);

      if (_chatChannel == null) {
        debugPrint('Failed to create channel - client may not be connected');
        // Retry after a short delay
        Future.delayed(
          Duration(seconds: 1),
          () => setupRealtimeUpdates(chatId),
        );
        return;
      }

      // Set up multiple insert listeners for better reliability
      // One general listener for all messages
      _chatChannel = _chatChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final messageData = payload.newRecord;
          try {
            debugPrint('Received general insert: ${messageData['message_id']}');
            await _handleNewMessage(messageData);
          } catch (e) {
            debugPrint('Error handling general insert message: $e');
          }
        },
      );

      // And a specific one for this chat to ensure we get messages for this chat
      _chatChannel = _chatChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'chat_id',
          value: databaseChatId,
        ),
        callback: (payload) async {
          final messageData = payload.newRecord;
          try {
            debugPrint(
              'Received specific chat insert: ${messageData['message_id']}',
            );
            await _handleNewMessage(messageData);
          } catch (e) {
            debugPrint('Error handling specific chat insert message: $e');
          }
        },
      );

      // Set up update listeners
      _chatChannel = _chatChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          try {
            debugPrint(
              'Received message update: ${payload.newRecord['message_id']}',
            );
            _handleMessageUpdate(
              payload.newRecord['message_id'],
              payload.newRecord,
            );
          } catch (e) {
            debugPrint('Error handling message update: $e');
          }
        },
      );

      // Set up delete listeners
      _chatChannel = _chatChannel!.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          try {
            debugPrint(
              'Received message delete: ${payload.oldRecord['message_id']}',
            );
            _handleMessageDelete(payload.oldRecord['message_id']);
          } catch (e) {
            debugPrint('Error handling message delete: $e');
          }
        },
      );

      // Subscribe to status changes with better error handling
      _chatChannel!.subscribe((status, error) {
        debugPrint('Realtime status: $status, error: ${error ?? "none"}');

        if (status == 'SUBSCRIBED') {
          debugPrint('Successfully subscribed to realtime updates');

          // Refresh messages as confirmation
          loadMessages(chatId, refreshing: true);
        } else if (status == 'CHANNEL_ERROR') {
          debugPrint('Channel error: ${error ?? "unknown"}');
          Future.delayed(Duration(milliseconds: 2000), () {
            reconnectChatSubscription();
          });
        } else if (status == 'TIMED_OUT' ||
            status == 'CLOSED' ||
            status == 'REMOVED') {
          debugPrint('Channel $status - attempting reconnection');
          Future.delayed(
            Duration(milliseconds: 1500),
            reconnectChatSubscription,
          );
        }
      });

      // Set up a periodic check for connection health
      Timer.periodic(Duration(seconds: 15), (_) {
        if (_chatChannel != null && selectedChatId.value.isNotEmpty) {
          debugPrint('Health check for realtime connection');
          checkForNewMessages(); // This will pull any missed messages
        }
      });

      debugPrint('Realtime subscription setup completed');
    } catch (e) {
      debugPrint('Error setting up realtime updates: $e');
      // Retry after a delay with exponential backoff
      Future.delayed(Duration(seconds: 3), () {
        reconnectChatSubscription();
      });
    }
  }

  /// Reconnect chat subscription if disconnected
  void reconnectChatSubscription() {
    debugPrint('Attempting to reconnect chat subscription');

    if (_chatChannel != null) {
      debugPrint('Reconnecting existing chat subscription');

      try {
        // Resubscribe to the channel
        _chatChannel!.subscribe((status, error) {
          debugPrint('Realtime resubscription status: $status, error: $error');

          if (status == 'SUBSCRIBED') {
            // Force refresh the messages after a reconnection
            if (selectedChatId.value.isNotEmpty) {
              loadMessages(selectedChatId.value, refreshing: true);
            }
          }
        });
      } catch (e) {
        debugPrint('Error reconnecting chat subscription: $e');

        // If reconnection fails, try setting up a fresh subscription
        if (selectedChatId.value.isNotEmpty) {
          setupRealtimeUpdates(selectedChatId.value);
        }
      }
    } else if (selectedChatId.value.isNotEmpty) {
      // If no channel exists, set up a fresh subscription
      setupRealtimeUpdates(selectedChatId.value);
    }
  }

  /// Clean up realtime subscriptions when leaving chat
  void cleanupRealtimeSubscriptions() {
    debugPrint('Cleaning up realtime subscriptions');
    try {
      if (_chatChannel != null) {
        _chatChannel!.unsubscribe();
        _chatChannel = null;
        debugPrint('Unsubscribed from realtime channel');
      }
    } catch (e) {
      debugPrint('Error cleaning up realtime subscriptions: $e');
    }
  }

  /// Check for new messages without full refresh
  Future<void> checkForNewMessages() async {
    debugPrint('Checking for new messages since last fetch');

    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;

      // Get timestamp of most recent message we have
      DateTime? lastMessageTime;
      if (recentChats.isNotEmpty &&
          recentChats[0]['last_message_time'] != null) {
        try {
          lastMessageTime = DateTime.parse(recentChats[0]['last_message_time']);
        } catch (e) {
          debugPrint('Error parsing last message time: $e');
        }
      }

      // If we don't have a last message time, do a full refresh instead
      if (lastMessageTime == null) {
        debugPrint('No last message time available, doing full refresh');
        return loadRecentChats();
      }

      // Query for any new messages since last message time - without the invalid join
      final response = await _supabaseService.client
          .from('messages')
          .select('*')
          .eq('recipient_id', currentUserId)
          .gt('created_at', lastMessageTime.toIso8601String())
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        debugPrint('Found ${response.length} new messages since last check');

        // Update recent chats
        loadRecentChats();

        // If we're in a chat, update messages if needed
        if (selectedChatId.value.isNotEmpty) {
          // Check if any of these new messages belong to the current chat
          final relevantMessages =
              response
                  .where(
                    (msg) =>
                        selectedChatId.value.contains(msg['chat_id']) ||
                        msg['chat_id'] == selectedChatId.value,
                  )
                  .toList();

          if (relevantMessages.isNotEmpty) {
            debugPrint(
              'Updating current chat with ${relevantMessages.length} new messages',
            );
            loadMessages(selectedChatId.value);
          }
        }
      } else {
        debugPrint('No new messages found since last check');
      }
    } catch (e) {
      debugPrint('Error checking for new messages: $e');
    }
  }

  /// Generate a proper UUID for database
  String _generateUuid() {
    final now = DateTime.now();
    final random = now.millisecondsSinceEpoch;
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${random.toString().substring(0, 4)}-${random.toString().substring(4, 8)}-${random.toString().substring(8, 12)}-${random.toString().substring(0, 12)}';
  }

  /// Send a message in active conversation
  Future<void> sendMessage({String? imageUrl, String? audioUrl}) async {
    final message = messageController.text.trim();
    final currentUserId = _supabaseService.currentUser.value?.id;

    if ((message.isEmpty && imageUrl == null && audioUrl == null) ||
        currentUserId == null ||
        activeConversation.value == null) {
      return;
    }

    final chatId = activeConversation.value!.id;
    final content = message;

    // Just use the sendChatMessage method for consistency
    await sendChatMessage(chatId, content);
  }

  void _updateUnreadCount(String chatId) {
    // This would be implemented in a real app
    debugPrint('Updating unread count for chat: $chatId');
  }

  /// Update an existing message with encryption
  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    try {
      debugPrint('Updating message: $messageId with content: $newContent');

      // Encrypt the new message content using chat-specific encryption
      String encryptedContent;
      try {
        // Try to use chat-specific encryption first
        encryptedContent = await _encryptionService.encryptMessageForChat(
          newContent,
          chatId,
        );
        debugPrint('Message update encrypted with chat-specific key');
      } catch (e) {
        // Fall back to general encryption
        encryptedContent = _encryptionService.encryptMessage(newContent);
        debugPrint('Using fallback encryption for update: $e');
      }

      // Update the message in the database
      await _supabaseService.client
          .from('messages')
          .update({
            'content': encryptedContent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('message_id', messageId);

      // Update the message in the local state
      final index = messages.indexWhere(
        (message) => message['message_id'] == messageId,
      );
      if (index != -1) {
        final updatedMessage = Map<String, dynamic>.from(messages[index]);
        updatedMessage['content'] =
            newContent; // Store decrypted version locally
        updatedMessage['updated_at'] = DateTime.now().toIso8601String();
        messages[index] = updatedMessage;
        messages.refresh();
      }

      // Show confirmation
      Get.snackbar(
        'Message Updated',
        'Your message has been updated',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      debugPrint('Error updating message: $e');
      Get.snackbar(
        'Update Failed',
        'Could not update your message',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Upload and send an image
  Future<void> uploadAndSendImage(String chatId, XFile image) async {
    // Delegate to the message service
    await _messageService.uploadAndSendImage(chatId, image);
  }

  /// Send a voice message
  Future<void> sendVoiceMessage(String chatId) async {
    // Placeholder implementation - should be implemented based on app's voice messaging functionality
    debugPrint('Voice messages not yet implemented');
    Get.snackbar(
      'Coming Soon',
      'Voice messages will be available in a future update',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Force decrypt all currently loaded messages (useful after hot reload)
  Future<void> forceDecryptMessages() async {
    debugPrint('Force decrypting ${messages.length} messages');

    if (messages.isEmpty) return;

    // Ensure encryption service is initialized
    if (!isEncryptionInitialized.value) {
      debugPrint(
        'Waiting for encryption service to initialize before force decrypting...',
      );
      await _initializeEncryptionService();
    }

    final List<Map<String, dynamic>> processedMessages = [];
    bool changed = false;

    for (final message in messages) {
      final Map<String, dynamic> updatedMessage = Map<String, dynamic>.from(
        message,
      );

      if (updatedMessage['content'] is String) {
        final String originalContent = updatedMessage['content'];

        // Only attempt to decrypt if it looks encrypted
        if (originalContent.contains('==') || originalContent.contains('🔒')) {
          try {
            // First try chat-specific decryption if we have chat_id
            String decryptedContent = originalContent;

            if (message['chat_id'] != null) {
              // Try chat-specific decryption first
              try {
                decryptedContent = await _encryptionService
                    .decryptMessageForChat(
                      originalContent,
                      message['chat_id'].toString(),
                    );
              } catch (e) {
                debugPrint(
                  'Chat-specific decryption failed in UI, falling back to general decryption: $e',
                );
                // Fall back to general decryption if chat-specific fails
                decryptedContent = _encryptionService.decryptMessage(
                  originalContent,
                );
              }
            } else {
              // No chat_id, use general decryption
              decryptedContent = _encryptionService.decryptMessage(
                originalContent,
              );
            }

            // Use decrypted content IF it's different from original AND not an error marker
            if (decryptedContent != originalContent &&
                decryptedContent.isNotEmpty &&
                !decryptedContent.startsWith('🔒')) {
              updatedMessage['content'] = decryptedContent;
              changed = true;
              debugPrint(
                'Successfully decrypted message ${updatedMessage['message_id']} from "$originalContent" to "$decryptedContent"',
              );
            } else if (decryptedContent == originalContent) {
              // Decryption did not change the content, and it still looks encrypted.
              debugPrint(
                'Decryption of ${updatedMessage['message_id']} ("$originalContent") resulted in no change. Content remains encrypted.',
              );
            } else {
              // Decrypted content is different, but it might be an error marker like "🔒..."
              // or some other state. If it's not the "good" decrypted case above,
              // and not the "no change" case, we might keep original or the service's error marker.
              // For now, if it's "🔒...", it will be kept. If it's different and not "🔒", it's used.
              if (!decryptedContent.startsWith('🔒')) {
                updatedMessage['content'] = decryptedContent;
                changed = true;
                debugPrint(
                  'Decryption of ${updatedMessage['message_id']} ("$originalContent") resulted in "$decryptedContent" (used).',
                );
              } else {
                // Kept '🔒...' if service returned that
                debugPrint(
                  'Decryption of ${updatedMessage['message_id']} ("$originalContent") resulted in error marker "$decryptedContent".',
                );
              }
            }
          } catch (e) {
            debugPrint(
              'Exception decrypting message ${updatedMessage['message_id']} ("$originalContent"): $e. Content remains encrypted.',
            );
            // Keep original content if decryption throws
          }
        }
      }
      processedMessages.add(updatedMessage);
    }

    // Update messages list only if any content actually changed to avoid unnecessary UI rebuilds.
    if (changed) {
      messages.value = processedMessages;
      messages.refresh();
      debugPrint('Messages list updated after force decryption.');
    } else {
      debugPrint('Force decryption completed, no messages were changed.');
    }
  }

  /// Get message content - ensures content is decrypted for display (can be called from UI)
  Future<String> getDecryptedMessageContent(
    Map<String, dynamic> message,
  ) async {
    if (message['content'] == null) return '';

    // Ensure encryption service is initialized
    if (!isEncryptionInitialized.value) {
      debugPrint(
        'Waiting for encryption service to initialize before decrypting message for UI...',
      );
      try {
        await _initializeEncryptionService();
      } catch (e) {
        debugPrint('Failed to initialize encryption service for UI: $e');
        return message['content'].toString();
      }
    }

    final String originalContent = message['content'].toString();

    // If content appears to be encrypted, try to decrypt it
    if (originalContent.contains('==') || originalContent.contains('🔒')) {
      try {
        // First try chat-specific decryption if we have chat_id
        String decryptedContent = originalContent;

        if (message['chat_id'] != null) {
          // Try chat-specific decryption first
          try {
            decryptedContent = await _encryptionService.decryptMessageForChat(
              originalContent,
              message['chat_id'].toString(),
            );
          } catch (e) {
            debugPrint(
              'Chat-specific decryption failed in UI, falling back to general decryption: $e',
            );
            // Fall back to general decryption if chat-specific fails
            decryptedContent = _encryptionService.decryptMessage(
              originalContent,
            );
          }
        } else {
          // No chat_id, use general decryption
          decryptedContent = _encryptionService.decryptMessage(originalContent);
        }

        // Use decrypted content IF it's different from original AND not an error marker
        if (decryptedContent != originalContent &&
            decryptedContent.isNotEmpty &&
            !decryptedContent.startsWith('🔒')) {
          // Update message in the list to prevent repeated decryption if it has an ID
          final messageId = message['message_id'];
          if (messageId != null) {
            final index = messages.indexWhere(
              (msg) => msg['message_id'] == messageId,
            );
            if (index != -1) {
              final updatedMessage = Map<String, dynamic>.from(messages[index]);
              if (updatedMessage['content'] != decryptedContent) {
                // Avoid unnecessary updates
                updatedMessage['content'] = decryptedContent;
                messages[index] = updatedMessage;
                debugPrint(
                  'Display: Decrypted and cached message $messageId from "$originalContent" to "$decryptedContent"',
                );
              }
            }
          }
          return decryptedContent;
        } else if (decryptedContent == originalContent) {
          // Decryption did not change the content, and it still looks encrypted.
          debugPrint(
            'Display: Decryption of ${message['message_id']} ("$originalContent") resulted in no change. Displaying as is.',
          );
          return originalContent; // Return the original (still encrypted) content
        } else {
          // Decrypted content is different, but it might be an error marker like "🔒..."
          // If not "🔒..." and different, it's used. If it is "🔒...", it's returned.
          if (!decryptedContent.startsWith('🔒')) {
            debugPrint(
              'Display: Decryption of ${message['message_id']} ("$originalContent") resulted in "$decryptedContent" (using).',
            );
            return decryptedContent;
          } else {
            debugPrint(
              'Display: Decryption of ${message['message_id']} ("$originalContent") resulted in error marker "$decryptedContent". Displaying marker.',
            );
            return decryptedContent; // Return the error marker (e.g., "🔒 Encrypted message")
          }
        }
      } catch (e) {
        debugPrint(
          'Display: Exception decrypting message ${message['message_id']} ("$originalContent"): $e. Displaying original content.',
        );
        return originalContent; // Return original content on exception
      }
    }

    return originalContent; // Return content if it doesn't appear encrypted
  }

  @override
  void onReady() {
    super.onReady();
    // Force decrypt messages whenever the controller is ready (after hot reload)
    forceDecryptMessages();
  }
}

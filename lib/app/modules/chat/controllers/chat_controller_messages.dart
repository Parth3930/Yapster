import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import '../services/chat_message_service.dart';

mixin ChatControllerMessages {
  // Initializes the chat controller
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  // Chat controller service initialize it
  ChatController get _chatControler => Get.find<ChatController>();
  RealtimeChannel? _messageSubscription;
  
  // Caching variables
  static final Map<String, Map<String, dynamic>> _chatCache = {};
  static DateTime? _lastChatFetchTime;
  static const Duration _chatCacheDuration = Duration(minutes: 5);
  static const Duration _backgroundRefreshThreshold = Duration(minutes: 1);
  
  // Track deleted messages to prevent showing them again
  static final Set<String> _deletedMessageIds = <String>{};
  final Map<String, DateTime> _chatsFetchTime = {};
  final Map<String, DateTime> _messagesFetchTime = {};
  final Map<String, List<MessageModel>> _messagesCache = {};
  static const Duration chatCacheDuration = Duration(minutes: 5);
  static const Duration messageCacheDuration = Duration(minutes: 10);
  
  // Store whether initial data has loaded
  final RxBool _chatsInitiallyLoaded = false.obs;
  
  // Static flag to prevent repeated preload calls
  static bool _isPreloadingChats = false;
  
  // Method to mark a message as deleted
  void markMessageAsDeleted(String messageId) {
    _deletedMessageIds.add(messageId);
    debugPrint('Marked message $messageId as deleted');
  }
  
  // Static method that can be called from other classes
  static void markMessageDeleted(String messageId) {
    _deletedMessageIds.add(messageId);
    debugPrint('Marked message $messageId as permanently deleted');
  }
  
  // Check if a message has been deleted
  static bool isMessageDeleted(String messageId) {
    return _deletedMessageIds.contains(messageId);
  }

  Future<void> syncMessagesWithDatabase(String chatId) async {
    final supabase = Get.find<SupabaseService>().client;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      // Fetch current messages from database
      final response = await supabase
          .from('messages')
          .select('message_id')
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso);

      final dbMessageIds = response.map((msg) => msg['message_id']).toSet();

      // Remove messages that no longer exist in database
      _chatControler.messages.removeWhere(
        (message) => !dbMessageIds.contains(message.messageId),
      );

      debugPrint('Synced messages with database');
    } catch (e) {
      debugPrint('Error syncing messages: $e');
    }
  }

  /// Checks if messages need to be refreshed based on cache age
  bool shouldRefreshMessages(String chatId) {
    final lastFetch = _messagesFetchTime[chatId];
    final now = DateTime.now();
    
    // Refresh if we haven't fetched before, or if cache is expired
    return lastFetch == null || 
           now.difference(lastFetch) > messageCacheDuration;
  }
  
  /// Updates the messages cache timestamp
  void markMessagesFetched(String chatId) {
    _messagesFetchTime[chatId] = DateTime.now();
    debugPrint('Marked messages for chat $chatId as fetched - cache updated');
  }
  
  /// Preload messages for a specific chat in the background
  Future<void> preloadMessages(String chatId) async {
    // Check if we need to refresh from DB
    if (shouldRefreshMessages(chatId)) {
      debugPrint('Preloading messages for chat $chatId in background');
      await loadMessages(chatId, forceRefresh: false);
    } else {
      debugPrint('Using cached messages for chat $chatId');
    }
  }
  
  // Loads messages for a conversation
  Future<void> loadMessages(String chatId, {bool forceRefresh = false}) async {
    final supabase = Get.find<SupabaseService>().client;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    debugPrint('Loading messages... $chatId');
    try {
      // Cancel any previous real-time message subscription
      await _messageSubscription?.unsubscribe();
      _messageSubscription = null;
      
      // Check if we have cached messages and they're still fresh
      if (!forceRefresh && !shouldRefreshMessages(chatId) && 
          _messagesCache.containsKey(chatId) && 
          _messagesCache[chatId]!.isNotEmpty) {
        debugPrint('Using cached messages for chat $chatId');
        _chatControler.messages.clear();
        _chatControler.messages.assignAll(_messagesCache[chatId]!);
        
        // Still set up real-time subscription even when using cache
        _setupRealtimeSubscription(chatId);
        return;
      }

      // If cache is stale or empty, fetch from database
      debugPrint('Fetching messages from database for chat $chatId');
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      // Initialize encryption service for decryption
      final encryptionService = Get.find<EncryptionService>();
      if (!encryptionService.isInitialized.value) {
        await encryptionService.initialize();
        debugPrint('Encryption service initialized for message loading');
      }
      
      _chatControler.messages.clear();
      if (response.isNotEmpty) {
        debugPrint('Fetched ${response.length} potentially encrypted messages from database');
        
        // Process and decrypt messages
        final List<MessageModel> loadedMessages = [];
        
        for (var msg in response) {
          // Check if message contains encrypted content
          if (msg['content'] != null) {
            try {
              // Attempt to decrypt the message content
              final decryptedContent = await encryptionService.decryptMessageForChat(
                msg['content'].toString(),
                chatId,
              );
              
              // Replace encrypted content with decrypted content
              msg['content'] = decryptedContent;
              debugPrint('Successfully decrypted message: ${msg['message_id']}');
            } catch (e) {
              debugPrint('Could not decrypt message ${msg['message_id']}: $e');
              // If decryption fails, leave content as is (might be plaintext or old format)
            }
          }
          
          // Create message model with decrypted content
          loadedMessages.add(MessageModel.fromJson(msg));
        }

        // Update cache with decrypted messages
        _messagesCache[chatId] = loadedMessages;
        markMessagesFetched(chatId);
        
        _chatControler.messages.assignAll(loadedMessages);
        debugPrint('Loaded and decrypted ${loadedMessages.length} messages from database');
      } else {
        // Even if no messages, mark as fetched to avoid repeated calls
        _messagesCache[chatId] = [];
        markMessagesFetched(chatId);
        debugPrint('No messages found in database for chat $chatId');
      }

      // Setup real-time subscription for this chat
      _setupRealtimeSubscription(chatId);

      debugPrint(
        'Messages loaded successfully ${_chatControler.messages.length}',
      );
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }
  
  // Sets up real-time subscription for a chat channel
  void _setupRealtimeSubscription(String chatId) async {
    final supabase = Get.find<SupabaseService>().client;
    
    // First unsubscribe from any existing subscription
    try {
      await _messageSubscription?.unsubscribe();
      debugPrint('Unsubscribed from previous chat channel');
    } catch (e) {
      debugPrint('Error unsubscribing from previous channel: $e');
    }
    
    debugPrint('Setting up real-time subscription for chat $chatId');
    
    _messageSubscription = supabase
      .channel('public:messages:$chatId') // Make channel name unique per chat
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'chat_id',
          value: chatId,
        ),
        callback: (payload) async {
          debugPrint('Received new message via real-time: ${payload.newRecord['message_id']}');
          final msgMap = Map<String, dynamic>.from(payload.newRecord);
          
          // Decrypt the message content before creating the MessageModel
          if (msgMap['content'] != null) {
            try {
              // Get encryption service
              final encryptionService = Get.find<EncryptionService>();
              if (!encryptionService.isInitialized.value) {
                await encryptionService.initialize();
              }
              
              // Decrypt the message content
              final decryptedContent = await encryptionService.decryptMessageForChat(
                msgMap['content'].toString(),
                chatId,
              );
              
              // Replace encrypted content with decrypted content
              msgMap['content'] = decryptedContent;
              debugPrint('Successfully decrypted real-time message content');
            } catch (e) {
              debugPrint('Could not decrypt real-time message: $e');
              // If decryption fails, leave content as is (might be plaintext or old format)
            }
          }
          
          // Now create the message model with decrypted content
          final message = MessageModel.fromJson(msgMap);
          final now = DateTime.now().toUtc();

          // Check if message is not deleted and not expired
          if (message.expiresAt.isAfter(now) && !_deletedMessageIds.contains(message.messageId)) {
            if (!_chatControler.messages.any(
              (m) => m.messageId == message.messageId,
            )) {
              debugPrint('Adding new message ${message.messageId} from real-time event');
              // Add to cache
              if (_messagesCache.containsKey(chatId)) {
                _messagesCache[chatId]!.add(message);
              }
              
              // Update UI
              _chatControler.messages.add(message);
              _chatControler.messagesToAnimate.add(message.messageId);
              
              // Force UI refresh
              _chatControler.messages.refresh();
              
              // Also refresh recent chats to show latest message
              _chatsFetchTime.clear(); // Force refresh of recent chats
              preloadRecentChats();
            }
          } else if (_deletedMessageIds.contains(message.messageId)) {
            debugPrint('Ignored deleted message ${message.messageId} from real-time event');
          }
          _cleanupExpiredMessages();
        },
      )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: chatId,
              ),
              callback: (payload) async {
                final msgMap = Map<String, dynamic>.from(payload.newRecord);
                
                // Decrypt the message content before creating the MessageModel
                if (msgMap['content'] != null) {
                  try {
                    // Get encryption service
                    final encryptionService = Get.find<EncryptionService>();
                    if (!encryptionService.isInitialized.value) {
                      await encryptionService.initialize();
                    }
                    
                    // Decrypt the message content
                    final decryptedContent = await encryptionService.decryptMessageForChat(
                      msgMap['content'].toString(),
                      chatId,
                    );
                    
                    // Replace encrypted content with decrypted content
                    msgMap['content'] = decryptedContent;
                    debugPrint('Successfully decrypted updated message content');
                  } catch (e) {
                    debugPrint('Could not decrypt updated message: $e');
                    // If decryption fails, leave content as is (might be plaintext or old format)
                  }
                }
                
                // Create the message model with decrypted content
                final message = MessageModel.fromJson(msgMap);
                final index = _chatControler.messages.indexWhere(
                  (m) => m.messageId == message.messageId,
                );
                if (index != -1) {
                  // Update cache
                  if (_messagesCache.containsKey(chatId)) {
                    final cacheIndex = _messagesCache[chatId]!.indexWhere(
                      (m) => m.messageId == message.messageId
                    );
                    if (cacheIndex != -1) {
                      _messagesCache[chatId]![cacheIndex] = message;
                    }
                  }
                  
                  // Update UI
                  _chatControler.messages[index] = message;
                }
                _cleanupExpiredMessages();
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: chatId,
              ),
              callback: (payload) {
                debugPrint('DELETE event received: ${payload.oldRecord}');
                final oldMap = payload.oldRecord;
                final messageId = oldMap['message_id'];
                debugPrint('Removing message with ID: $messageId');
                
                // Add to permanently deleted messages set
                _deletedMessageIds.add(messageId);
                debugPrint('Added message $messageId to deleted messages set');

                // Update cache
                if (_messagesCache.containsKey(chatId)) {
                  _messagesCache[chatId]!.removeWhere(
                    (m) => m.messageId == messageId
                  );
                }
                
                // Update UI
                final initialLength = _chatControler.messages.length;
                _chatControler.messages.removeWhere(
                  (m) => m.messageId == messageId,
                );
                final finalLength = _chatControler.messages.length;

                debugPrint('Messages count: $initialLength -> $finalLength');
                _chatControler.messagesToAnimate.remove(messageId);
                _cleanupExpiredMessages();
                
                // Force UI refresh
                _chatControler.messages.refresh();
              },
            )
            .subscribe();
  }

  void _cleanupExpiredMessages() {
    final now = DateTime.now().toUtc();
    _chatControler.messages.removeWhere((m) => m.expiresAt.isBefore(now));
    _chatControler.messagesToAnimate.removeWhere(
      (id) => !_chatControler.messages.any((m) => m.messageId == id),
    );
    _chatControler.messages.refresh(); // 
  }

  /// Checks if chats need to be refreshed based on cache age
  bool shouldRefreshChats() {
    final userId = _supabaseService.client.auth.currentUser?.id;
    if (userId == null) return true;
    
    final lastFetch = _chatsFetchTime[userId];
    final now = DateTime.now();
    
    // Refresh if we haven't fetched before, or if cache is expired
    return lastFetch == null || 
           now.difference(lastFetch) > chatCacheDuration;
  }
  
  /// Updates the chats cache timestamp
  void markChatsFetched() {
    final userId = _supabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      _chatsFetchTime[userId] = DateTime.now();
      _chatsInitiallyLoaded.value = true;
      debugPrint('Marked chats as fetched - cache updated');
    }
  }

  /// Preload recent chats in the background
  Future<void> preloadRecentChats() async {
    // Use static flag to prevent multiple simultaneous preloads
    if (_isPreloadingChats) {
      debugPrint('Already preloading chats, skipping redundant call');
      return;
    }
    
    final userId = _supabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    
    // Check if we have valid cached data
    final bool shouldUseCache = _lastChatFetchTime != null && 
        DateTime.now().difference(_lastChatFetchTime!) < _chatCacheDuration;
    
    // If we have valid cached chats, use them immediately
    if (shouldUseCache && _chatCache.containsKey(userId)) {
      debugPrint('Using cached recent chats');
      _chatControler.recentChats.value = List<Map<String, dynamic>>.from(_chatCache[userId]!['chats']);
      _chatControler.isLoadingChats.value = false;
      
      // Refresh in background if cache is older than threshold
      if (_lastChatFetchTime != null && 
          DateTime.now().difference(_lastChatFetchTime!) > _backgroundRefreshThreshold) {
        _refreshChatsInBackground();
      }
      return;
    }
    
    // If we have cached chats but they're expired, show them while refreshing
    if (_chatControler.recentChats.isNotEmpty) {
      debugPrint('Using expired cache while refreshing recent chats');
      _refreshChatsInBackground();
      return;
    }
    
    // Initial load or empty cache, must wait for completion
    try {
      _isPreloadingChats = true;
      debugPrint('Preloading recent chats (initial load)');
      await fetchUsersRecentChats(forceRefresh: true);
      _chatsInitiallyLoaded.value = true;
    } finally {
      _isPreloadingChats = false;
    }
  }
  
  /// Refresh chats in background without blocking UI
  Future<void> _refreshChatsInBackground() async {
    // Don't await this, let it run in background
    Future(() async {
      if (_isPreloadingChats) return;
      try {
        _isPreloadingChats = true;
        final userId = _supabaseService.client.auth.currentUser?.id;
        if (userId != null) {
          // Only force refresh if cache is actually stale
          final bool shouldForce = shouldRefreshChats() || 
              (_lastChatFetchTime != null && 
               DateTime.now().difference(_lastChatFetchTime!) > _chatCacheDuration);
          
          await fetchUsersRecentChats(forceRefresh: shouldForce);
          debugPrint('Background chat refresh completed');
        }
      } catch (e) {
        debugPrint('Error in background chat refresh: $e');
      } finally {
        _isPreloadingChats = false;
      }
    });
  }
  
  Future<void> fetchUsersRecentChats({bool forceRefresh = false}) async {
    final userId = _supabaseService.client.auth.currentUser?.id;
    _chatControler.isLoadingChats.value = true;

    if (userId == null) {
      debugPrint('User not logged in');
      _chatControler.isLoadingChats.value = false;
      return;
    }
    
    // Use cached data if available and fresh, unless force refresh is requested
    final bool shouldUseCache = _lastChatFetchTime != null && 
        DateTime.now().difference(_lastChatFetchTime!) < _chatCacheDuration;
    
    if (!forceRefresh && shouldUseCache && _chatCache.containsKey(userId)) {
      debugPrint('Using cached recent chats from memory');
      _chatControler.recentChats.value = List<Map<String, dynamic>>.from(_chatCache[userId]!['chats']);
      _chatControler.isLoadingChats.value = false;
      return;
    }

    debugPrint('Fetching recent chats from database');
    try {
      final List<dynamic> chats = await _supabaseService.client.rpc(
        'fetch_users_recent_chats',
        params: {'user_uuid': userId},
      );

      if (chats.isEmpty) {
        debugPrint('No recent chats found.');
        _chatControler.recentChats.clear();
        markChatsFetched(); // Mark as fetched even if empty
        return;
      }

      // Get encryption service for decryption
      final encryptionService = Get.find<EncryptionService>();
      if (!encryptionService.isInitialized.value) {
        await encryptionService.initialize();
        debugPrint('Encryption service initialized for recent chats');
      }
      
      // Process each chat to ensure it has a valid last_message property
      final processedChats = await Future.wait(chats.map((chat) async {
        // Ensure each chat has a proper last_message
        if (chat is Map<String, dynamic>) {
          // Only set 'No new messages' for actual null values, not for empty strings
          if (chat['last_message'] == null) {
            chat['last_message'] = 'No new messages';
          } else if (chat['last_message'].toString().trim().isEmpty) {
            // If message is just whitespace, use a space to avoid 'No new messages'
            // but still show an empty bubble
            chat['last_message'] = ' ';
          } else {
            // Try to decrypt the last message if it's encrypted
            try {
              final chatId = chat['chat_id']?.toString() ?? '';
              if (chatId.isNotEmpty) {
                final encryptedLastMessage = chat['last_message'].toString();
                final decryptedLastMessage = await encryptionService.decryptMessageForChat(
                  encryptedLastMessage,
                  chatId,
                );
                chat['last_message'] = decryptedLastMessage;
                debugPrint('Successfully decrypted last message for chat: $chatId');
              }
            } catch (e) {
              debugPrint('Could not decrypt last message: $e');
              // If decryption fails, leave content as is (might be plaintext or old format)
            }
          }
          
          // Also ensure other required fields are present
          if (chat['username'] == null) {
            chat['username'] = 'User';
          }
          
          // Ensure profile picture is set
          if (chat['profile_picture'] == null || chat['profile_picture'].toString().isEmpty) {
            chat['profile_picture'] = '';
          }
        }
        return chat;
      }));

      final chatList = processedChats.cast<Map<String, dynamic>>();
      _chatControler.recentChats.value = chatList;
      
      // Update cache
      _chatCache[userId] = {
        'chats': List<Map<String, dynamic>>.from(chatList),
        'timestamp': DateTime.now().toIso8601String(),
      };
      _lastChatFetchTime = DateTime.now();
      
      markChatsFetched();
      debugPrint('Fetched ${processedChats.length} recent chats');
    } catch (e) {
      debugPrint('Error fetching chats: $e');
    } finally {
      _chatControler.isLoadingChats.value = false;
    }
  }

  // Sends a chat message
  Future<void> sendChatMessage(String chatId, String content) async {
    try {
      // Get or initialize the chat service
      final chatService = Get.find<ChatMessageService>();
      
      // Ensure service is initialized
      if (!chatService.isInitialized.value) {
        await chatService.initialize(
          messagesList: _chatControler.messages,
          chatsList: _chatControler.recentChats,
          uploadProgress: _chatControler.localUploadProgress,
        );
      }

      // Get recipient ID from the chat (using existing data or fetching from db)
      String recipientId = '';
      
      // Try to find it in the recent chats data first
      final chatIndex = _chatControler.recentChats.indexWhere((chat) => chat['chat_id'] == chatId);
      if (chatIndex != -1) {
        // Get recipient from the existing chat data
        final chat = _chatControler.recentChats[chatIndex];
        final String currentUserId = _supabaseService.currentUser.value?.id ?? '';
        recipientId = chat['user_two_id'] == currentUserId ? chat['user_one_id'] : chat['user_two_id'];
      } else {
        // If not in cache, fetch from database
        final response = await _supabaseService.client
            .from('chats')
            .select()
            .eq('chat_id', chatId)
            .single();
        
        final String currentUserId = _supabaseService.currentUser.value?.id ?? '';
        recipientId = response['user_two_id'] == currentUserId ? response['user_one_id'] : response['user_two_id'];
      }
      
      // Set default expiration time (7 days from now)
      final DateTime expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
      
      await chatService.sendMessage(
        chatId: chatId,
        recipientId: recipientId,
        content: content,
        messageType: 'text',
        expiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  // Picks and sends an image
  Future<void> pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      await uploadAndSendImage(_chatControler.selectedChatId.value, image);
    }
  }

  // Gets decrypted message content
  Future<String> getDecryptedMessageContent(
    Map<String, dynamic> message,
  ) async {
    return message['content']?.toString() ?? '';
  }

  // Opens chat window
  Future<void> openChat(String userTwoId, String username) async {
    final userId = _supabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    // Check if we already have a chat with this user in cache
    final existingChat = _chatControler.recentChats.firstWhereOrNull(
      (chat) =>
          chat['other_user_id'] == userTwoId ||
          chat['user_one_id'] == userTwoId,
    );

    if (existingChat != null) {
      // Navigate to existing chat
      await Get.toNamed(
        '/chat/${existingChat['chat_id']}',
        arguments: {
          'chatId': existingChat['chat_id'],
          'username': username,
          'userId': userTwoId,
        },
      );
      return;
    }

    // Create new chat if it doesn't exist
    try {
      _chatControler.isLoading.value = true;
      
      // Create new chat in database
      final response = await _supabaseService.client.rpc(
        'create_chat',
        params: {
          'p_user_one_id': userId,
          'p_user_two_id': userTwoId,
        },
      );

      if (response != null && response['chat_id'] != null) {
        // Invalidate cache to ensure fresh data on next load
        _lastChatFetchTime = null;
        _chatCache.remove(userId);
        
        // Force refresh chats to include the new one
        await fetchUsersRecentChats(forceRefresh: true);
        
        // Navigate to the new chat
        await Get.toNamed(
          '/chat/${response['chat_id']}',
          arguments: {
            'chatId': response['chat_id'],
            'username': username,
            'userId': userTwoId,
          },
        );
      }
    } catch (e) {
      debugPrint('Error creating chat: $e');
      Get.snackbar('Error', 'Could not start chat');
    } finally {
      _chatControler.isLoading.value = false;
    }
  }

  /// Marks all messages in a chat as read for the current user
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final userId = _supabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabaseService.client.rpc(
        'mark_messages_as_read',
        params: {
          'p_chat_id': chatId,
          'p_user_id': userId,
        },
      );
      
      // Update local state to reflect read status
      final updatedMessages = _chatControler.messages.map((message) {
        if (message.senderId != userId && !message.isRead) {
          return message.copyWith(isRead: true);
        }
        return message;
      }).toList();
      
      _chatControler.messages.value = updatedMessages;
      
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Update an existing message
  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    try {
      _chatControler.isSendingMessage.value = true;
      
      await _supabaseService.client.rpc(
        'update_chat_message',
        params: {
          'p_message_id': messageId,
          'p_new_content': newContent,
        },
      );
      
      // Update local message
      final messageIndex = _chatControler.messages.indexWhere(
        (m) => m.messageId == messageId,
      );
      
      if (messageIndex != -1) {
        final message = _chatControler.messages[messageIndex];
        final updatedMessage = message.copyWith(
          content: newContent,
        );
        _chatControler.messages[messageIndex] = updatedMessage;
        _chatControler.messages.refresh();
      }
      
    } catch (e) {
      debugPrint('Error updating message: $e');
      Get.snackbar('Error', 'Failed to update message');
    } finally {
      _chatControler.isSendingMessage.value = false;
    }
  }

  // Uploads and sends an image
  Future<void> uploadAndSendImage(String chatId, XFile image) async {
    try {
      // Get recipient ID from the chat (using existing data or fetching from db)
      String recipientId = '';
      
      // Try to find it in the recent chats data first
      final chatIndex = _chatControler.recentChats.indexWhere((chat) => chat['chat_id'] == chatId);
      if (chatIndex != -1) {
        // Get recipient from the existing chat data
        final chat = _chatControler.recentChats[chatIndex];
        final String currentUserId = _supabaseService.currentUser.value?.id ?? '';
        recipientId = chat['user_two_id'] == currentUserId ? chat['user_one_id'] : chat['user_two_id'];
      } else {
        // If not in cache, fetch from database
        final response = await _supabaseService.client
            .from('chats')
            .select()
            .eq('chat_id', chatId)
            .single();
        
        final String currentUserId = _supabaseService.currentUser.value?.id ?? '';
        recipientId = response['user_two_id'] == currentUserId ? response['user_one_id'] : response['user_two_id'];
      }
      
      // Set default expiration time (7 days from now)
      final DateTime expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
      
      // Call the service with all required parameters
      await Get.find<ChatMessageService>().uploadAndSendImage(
        chatId: chatId,
        recipientId: recipientId,
        image: image,
        expiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('Error uploading and sending image: $e');
    }
  }
  
  // Force refresh all messages and caches to ensure proper decryption
  Future<void> forceRefreshAllMessages(String chatId) async {
    try {
      // Clear all caches
      _messagesCache.clear();
      _messagesFetchTime.clear();
      _chatsFetchTime.clear();
      _deletedMessageIds.clear(); // Also clear deleted message tracking
      
      // Clear current messages
      _chatControler.messages.clear();
      _chatControler.messagesToAnimate.clear();
      
      debugPrint('Cleared all caches, loading fresh messages');
      
      // Either use the service method OR the controller method, not both
      // The service has better encryption handling, so we'll use that
      await Get.find<ChatMessageService>().forceRefreshMessages(chatId);
      
      // Update the cache timestamp to prevent immediate re-fetch
      markMessagesFetched(chatId);
      
      // Update UI
      _chatControler.messages.refresh();
      
      debugPrint('Successfully refreshed all messages for chat: $chatId');
    } catch (e) {
      debugPrint('Error refreshing messages: $e');
      // Fall back to the controller's method if service method fails
      await loadMessages(chatId, forceRefresh: true);
    }
    
    // Also refresh recent chats
    await preloadRecentChats();
    
    debugPrint('Forced complete refresh of all messages and caches');
  }

  // Example: Edit a message (stub)
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    // Example: Call a service to edit the message content in the backend.
    throw UnimplementedError('Edit message not implemented');
  }
}

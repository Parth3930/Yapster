import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../services/chat_message_service.dart';

/// Cache entry for storing messages with timestamp
class MessageCacheEntry {
  final List<MessageModel> messages;
  final DateTime timestamp;
  
  static const Duration cacheDuration = Duration(minutes: 10);
  static const Duration backgroundRefreshThreshold = Duration(minutes: 1);
  
  MessageCacheEntry(this.messages) : timestamp = DateTime.now();
  
  bool get isStale => DateTime.now().difference(timestamp) > backgroundRefreshThreshold;
  bool get isExpired => DateTime.now().difference(timestamp) > cacheDuration;
}

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
  
  // Chat list caching
  final Map<String, DateTime> _chatsFetchTime = {};
  
  // Message caching with TTL
  final Map<String, MessageCacheEntry> _messagesCache = {};
  
  // Track active background refreshes to prevent duplicates
  final Set<String> _activeBackgroundRefreshes = {};
  
  // Store whether initial data has loaded
  final RxBool _chatsInitiallyLoaded = false.obs;
  
  // Static flag to prevent repeated preload calls
  static bool _isPreloadingChats = false;
  
  // Cache duration constants
  static const Duration chatCacheDuration = Duration(minutes: 5);
  static const Duration messageCacheDuration = Duration(minutes: 10);
  
  /// Clears all cached data
  void clearCache() {
    _chatCache.clear();
    _chatsFetchTime.clear();
    _messagesCache.clear();
    _activeBackgroundRefreshes.clear();
    _lastChatFetchTime = null;
    debugPrint('Cleared all chat and message caches');
  }
  
  /// Clears the cache for a specific chat
  void clearChatCache(String chatId) {
    _messagesCache.remove(chatId);
    _activeBackgroundRefreshes.remove(chatId);
    debugPrint('Cleared cache for chat $chatId');
  }

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

  // Check if messages for a chat need to be refreshed based on cache age
  bool shouldRefreshMessages(String chatId) {
    final cacheEntry = _messagesCache[chatId];
    
    // If we have a cache entry and it's not expired, use it
    if (cacheEntry != null && !cacheEntry.isExpired) {
      debugPrint('Using cached messages for chat $chatId');
      return false;
    }
    
    // If we get here, we need to refresh
    debugPrint('Cache expired or missing for chat $chatId, refreshing...');
    return true;
  }
  
  /// Checks if messages should be refreshed in the background
  bool _shouldRefreshInBackground(String chatId) {
    final cacheEntry = _messagesCache[chatId];
    return cacheEntry != null && 
           cacheEntry.isStale && 
           !_activeBackgroundRefreshes.contains(chatId);
  }
  
  /// Updates the messages cache with new data
  void _updateMessagesCache(String chatId, List<MessageModel> messages) {
    _messagesCache[chatId] = MessageCacheEntry(messages);
    debugPrint('Updated message cache for chat $chatId with ${messages.length} messages');
  }
  
  /// Gets cached messages if available and fresh
  List<MessageModel>? _getCachedMessages(String chatId) {
    final cacheEntry = _messagesCache[chatId];
    if (cacheEntry != null && !cacheEntry.isExpired) {
      debugPrint('Returning cached messages for chat $chatId');
      return cacheEntry.messages;
    }
    return null;
  }
  
  /// Preload messages for a specific chat in the background
  Future<void> preloadMessages(String chatId) async {
    // Return cached messages immediately if available and fresh
    final cachedMessages = _getCachedMessages(chatId);
    if (cachedMessages != null) {
      debugPrint('Using cached messages for chat $chatId');
      _chatControler.messages.value = List.from(cachedMessages);
      
      // Refresh in background if cache is getting stale
      if (_shouldRefreshInBackground(chatId)) {
        _refreshMessagesInBackground(chatId);
      }
      return;
    }
    
    // If no cache or cache expired, load fresh data
    debugPrint('Preloading messages for chat $chatId in background');
    await loadMessages(chatId, forceRefresh: false);
  }
  
  /// Refresh messages in background without blocking UI
  Future<void> _refreshMessagesInBackground(String chatId) async {
    if (_activeBackgroundRefreshes.contains(chatId)) return;
    
    try {
      _activeBackgroundRefreshes.add(chatId);
      debugPrint('Starting background refresh of messages for chat $chatId');
      
      await loadMessages(chatId, forceRefresh: true);
      
      debugPrint('Background refresh of messages completed for chat $chatId');
    } catch (e) {
      debugPrint('Error during background refresh of messages: $e');
    } finally {
      _activeBackgroundRefreshes.remove(chatId);
    }
  }
  
  // Loads messages for a conversation
  Future<void> loadMessages(String chatId, {bool forceRefresh = false}) async {
    final supabase = Get.find<SupabaseService>().client;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final userId = _supabaseService.client.auth.currentUser?.id;
    
    if (userId == null) {
      debugPrint('User not authenticated, cannot load messages');
      return;
    }

    debugPrint('Loading messages for chat $chatId, forceRefresh: $forceRefresh');
    
    try {
      // Cancel any previous real-time message subscription
      await _messageSubscription?.unsubscribe();
      _messageSubscription = null;
      
      // Return cached messages if available and not forcing refresh
      if (!forceRefresh) {
        final cachedMessages = _getCachedMessages(chatId);
        if (cachedMessages != null) {
          debugPrint('Using cached messages for chat $chatId');
          _chatControler.messages.value = List.from(cachedMessages);
          _setupRealtimeSubscription(chatId);
          
          // Refresh in background if cache is getting stale
          if (_shouldRefreshInBackground(chatId)) {
            _refreshMessagesInBackground(chatId);
          }
          return;
        }
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
        _updateMessagesCache(chatId, loadedMessages);
        
        // Only update UI if this is not a background refresh
        if (!_activeBackgroundRefreshes.contains(chatId)) {
          _chatControler.messages.assignAll(loadedMessages);
        }
        
        debugPrint('Loaded and decrypted ${loadedMessages.length} messages from database');
      } else {
        // Even if no messages, update cache to avoid repeated calls
        _updateMessagesCache(chatId, []);
        if (!_activeBackgroundRefreshes.contains(chatId)) {
          _chatControler.messages.clear();
        }
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
                final cachedMessages = _messagesCache[chatId]!.messages.toList();
                cachedMessages.add(message);
                _messagesCache[chatId] = MessageCacheEntry(cachedMessages);
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
                
                // Handle message update from real-time subscription
                _handleMessageUpdate(chatId, msgMap);
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
                  _messagesCache[chatId]!.messages.removeWhere(
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

  void _handleMessageUpdate(String chatId, Map<String, dynamic> msgMap) {
    try {
      final message = MessageModel.fromJson(msgMap);
      final index = _chatControler.messages.indexWhere(
        (m) => m.messageId == message.messageId,
      );

      if (index != -1) {
        // Update cache
        if (_messagesCache.containsKey(chatId)) {
          final cacheIndex = _messagesCache[chatId]!.messages.indexWhere(
            (m) => m.messageId == message.messageId
          );
          if (cacheIndex != -1) {
            final updatedMessages = _messagesCache[chatId]!.messages.toList();
            updatedMessages[cacheIndex] = message;
            _messagesCache[chatId] = MessageCacheEntry(updatedMessages);
          }
        }
        
        // Update UI
        _chatControler.messages[index] = message;
        _chatControler.messages.refresh();
      }
    } catch (e) {
      debugPrint('Error handling message update: $e');
    }
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
   // opens chat window
  Future<void> openChat(String userTwoId, String username) async {
    final supabaseService = Get.find<SupabaseService>();
    final currentUserId = supabaseService.client.auth.currentUser?.id;

    if (currentUserId == null) {
      debugPrint('User not logged in');
      return;
    }

    try {
      // Call the RPC to get or create a chat_id connecting both users
      final chatId = await supabaseService.client.rpc(
        'user_chat_connect',
        params: {'user_one': currentUserId, 'user_two': userTwoId},
      );

      // chatId is expected to be a String UUID or null
      if (chatId != null && (chatId is String) && chatId.isNotEmpty) {
        // Navigate to the chat detail screen with chatId and username
        Get.toNamed(
          Routes.CHAT_WINDOW,
          arguments: {
            'chatId': chatId,
            'username': username,
            'otherUserId': userTwoId,
          },
        );
      } else {
        debugPrint('Chat ID not found in response');
      }
    } catch (e) {
      debugPrint('Failed to connect/open chat: $e');
    }
  }

  /// Marks all messages in a chat as read for the current user
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final userId = _supabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Update messages where current user is the recipient and they're not already read
      await _supabaseService.client
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chatId)
          .eq('recipient_id', userId)
          .eq('is_read', false);
      
      // Update local state to reflect read status
      final updatedMessages = _chatControler.messages.map((message) {
        if (message.recipientId == userId && !message.isRead) {
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
      clearCache();
      
      // Clear current messages
      _chatControler.messages.clear();
      _chatControler.messagesToAnimate.clear();
      
      // Mark messages as fetched to prevent immediate refetch
      _messagesCache[chatId] = MessageCacheEntry([]);
      
      debugPrint('Cleared all caches, loading fresh messages');
      
      try {
        // Try using the service method first (has better encryption handling)
        await Get.find<ChatMessageService>().forceRefreshMessages(chatId);
      } catch (e) {
        debugPrint('Error using service refresh, falling back to controller method: $e');
        // Fall back to the controller's method if service method fails
        await loadMessages(chatId, forceRefresh: true);
      }
      
      // Update the cache with current messages
      if (_chatControler.messages.isNotEmpty) {
        _updateMessagesCache(chatId, _chatControler.messages.toList());
      }
      
      // Update UI
      _chatControler.messages.refresh();
      
      debugPrint('Successfully refreshed all messages for chat: $chatId');
    } catch (e) {
      debugPrint('Error in forceRefreshAllMessages: $e');
      rethrow; // Re-throw to allow callers to handle the error
    } finally {
      // Always refresh recent chats
      await preloadRecentChats();
      debugPrint('Completed refresh of all messages and caches for chat: $chatId');
    }
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

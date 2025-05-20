import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';

class ChatController extends GetxController with WidgetsBindingObserver {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider = Get.find<AccountDataProvider>();
  late EncryptionService _encryptionService;
  
  // Getter for supabaseService to access from views
  SupabaseService get supabaseService => _supabaseService;
  
  // User search
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;
  Timer? _searchDebounce;
  
  // Chat data
  final RxList<Map<String, dynamic>> recentChats = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingChats = false.obs;
  final RxString selectedChatId = ''.obs;
  
  // Messages
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final TextEditingController messageController = TextEditingController();
  final RxBool isSendingMessage = false.obs;
  
  // Realtime subscription
  RealtimeChannel? _chatSubscription;
  final RxBool isChatConnected = false.obs;
  
  // Track processed message IDs to prevent duplication
  final RxSet<String> _processedMessageIds = <String>{}.obs;
  
  // Preferences
  final RxBool hasUserDismissedExpiryBanner = false.obs;
  
  // Lifecycle tracking
  DateTime? _lastActiveTime;
  
  // Track when the last database update was attempted
  DateTime? _lastReadStatusUpdate;
  final _readStatusThrottleDuration = const Duration(seconds: 10);
  
  @override
  void onInit() {
    super.onInit();
    
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize encryption service with current user ID first
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId != null) {
      // Initialize encryption service
      Get.put(EncryptionService()).init(currentUserId);
      _encryptionService = Get.find<EncryptionService>();
    }
    
    // Setup listeners after encryption is ready
    searchController.addListener(_onSearchChanged);
    
    // Clear processed message IDs before loading anything
    _processedMessageIds.clear();
    
    // Load data after initialization
    loadRecentChats();
    _setupRealtimeSubscription();
    
    // Start the message cleanup timer that runs once per hour
    _startMessageCleanupTimer();
    
    // Load user preferences
    _loadUserPreferences();
    
    // Set initial active time
    _lastActiveTime = DateTime.now();
  }
  
  @override
  void onClose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    messageController.dispose();
    _searchDebounce?.cancel();
    _cleanupRealtimeSubscription();
    super.onClose();
  }
  
  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state changed: $state');
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      final now = DateTime.now();
      final lastActive = _lastActiveTime ?? now;
      final timeDifference = now.difference(lastActive).inSeconds;
      
      // If app was in background for more than 5 seconds, refresh data
      if (timeDifference > 5) {
        debugPrint('App resumed after $timeDifference seconds - refreshing data');
        
        // Refresh chat list
        loadRecentChats();
        
        // Check if we're in a chat and refresh if needed
        if (selectedChatId.isNotEmpty) {
          loadMessages(selectedChatId.value);
          _resubscribeToChat(selectedChatId.value);
        }
      }
      
      _lastActiveTime = now;
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      _lastActiveTime = DateTime.now();
    }
  }
  
  // Re-establish subscription to current chat (if needed)
  void _resubscribeToChat(String chatId) {
    try {
      if (_chatSubscription == null) {
        debugPrint('No existing subscription, creating new chat subscription to: $chatId');
        _subscribeToChat(chatId);
      } else {
        // Since we can't easily check if the subscription is active, 
        // we'll just clean up and resubscribe to be safe
        debugPrint('Refreshing chat subscription to ensure real-time updates');
        _cleanupChatSubscription();
        _subscribeToChat(chatId);
        
        // Also refresh messages from server
        loadMessages(chatId);
      }
    } catch (e) {
      debugPrint('Error in chat subscription: $e');
      // If any error occurs, try to resubscribe from scratch
      _cleanupChatSubscription();
      _subscribeToChat(chatId);
    }
  }
  
  void _onSearchChanged() {
    searchQuery.value = searchController.text;
    
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (searchQuery.isNotEmpty) {
        _searchUsers(searchQuery.value);
      } else {
        searchResults.clear();
      }
    });
  }
  
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    
    isSearching.value = true;
    
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;
      
      // Combined search results list
      List<Map<String, dynamic>> results = [];
      
      // 1. Search all users in database
      final usersResponse = await _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .ilike('username', '%$query%')
          .neq('user_id', currentUserId)
          .limit(10);
      
      if (usersResponse.isNotEmpty) {
        results.addAll(List<Map<String, dynamic>>.from(usersResponse));
      }
      
      // 2. Search in following users
      if (_accountDataProvider.following.isNotEmpty) {
        final followingResults = _accountDataProvider.following.where((user) {
          final username = (user['username'] ?? '').toString().toLowerCase();
          final nickname = (user['nickname'] ?? '').toString().toLowerCase();
          final userId = user['following_id'];
          return userId != currentUserId && 
                (username.contains(query.toLowerCase()) || 
                nickname.contains(query.toLowerCase()));
        }).toList();
        
        // Add a type identifier for display purposes
        for (var user in followingResults) {
          user['source'] = 'following';
        }
        
        results.addAll(followingResults);
      }
      
      // 3. Search in followers
      if (_accountDataProvider.followers.isNotEmpty) {
        final followerResults = _accountDataProvider.followers.where((user) {
          final username = (user['username'] ?? '').toString().toLowerCase();
          final nickname = (user['nickname'] ?? '').toString().toLowerCase();
          final userId = user['follower_id'];
          return userId != currentUserId && 
                (username.contains(query.toLowerCase()) || 
                nickname.contains(query.toLowerCase()));
        }).toList();
        
        // Add a type identifier for display purposes
        for (var user in followerResults) {
          user['source'] = 'follower';
        }
        
        results.addAll(followerResults);
      }
      
      // Remove duplicates (prefer following/follower entries over regular ones)
      final Map<String, Map<String, dynamic>> uniqueResults = {};
      
      for (var user in results) {
        final userId = user['user_id'] ?? user['follower_id'] ?? user['following_id'];
        if (userId != null) {
          if (!uniqueResults.containsKey(userId) || 
              user['source'] != null) {
            uniqueResults[userId] = user;
          }
        }
      }
      
      searchResults.value = uniqueResults.values.toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      isSearching.value = false;
    }
  }
  
  Future<void> loadRecentChats() async {
    if (!_supabaseService.isAuthenticated.value) return;
    
    isLoadingChats.value = true;
    
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;
      
      // Use the new SQL function to get user chats with all necessary data
      final response = await _supabaseService.client
          .rpc('get_user_chats', params: {
            'user_id_param': currentUserId
          });
      
      if (response != null) {
        final chatsList = List<Map<String, dynamic>>.from(response);
        
        // Decrypt message content for previews
        for (final chat in chatsList) {
          if (chat['last_message'] != null && chat['last_message'].toString().isNotEmpty) {
            try {
              // Try to decrypt with chat-specific key first
              if (chat['chat_id'] != null) {
                chat['last_message'] = await _encryptionService.decryptMessageForChat(
                  chat['last_message'],
                  chat['chat_id']
                );
              } else {
                // Fall back to legacy decryption
                chat['last_message'] = _encryptionService.decryptMessage(chat['last_message']);
              }
            } catch (e) {
              debugPrint('Could not decrypt message preview: $e');
            }
          }
        }
        
        recentChats.value = chatsList;
        debugPrint('Loaded ${recentChats.length} chats');
      } else {
        recentChats.value = [];
      }
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
      Get.snackbar(
        'Error',
        'Could not load chats. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white
      );
    } finally {
      isLoadingChats.value = false;
    }
  }
  
  // Open or create a chat with a user
  Future<void> openChat(String otherUserId, String username) async {
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) return;
    
    try {
      // First, ensure we have the other user's profile loaded
      await _loadUserProfile(otherUserId);
      
      // Check if chat already exists between these two users
      // We need to find chats where both users are participants
      final response = await _supabaseService.client
          .rpc('find_chat_between_users', params: {
            'user_id_1': currentUserId,
            'user_id_2': otherUserId
          });
      
      String? chatId;
      
      if (response != null && response.isNotEmpty) {
        chatId = response[0]['chat_id'];
        debugPrint('Found existing chat: $chatId');
      } else {
        debugPrint('Creating new chat between $currentUserId and $otherUserId');
        // Create new chat using secure helper function
        final result = await _supabaseService.client
            .rpc('create_chat_between_users', params: {
              'user_id_1': currentUserId,
              'user_id_2': otherUserId
            });
            
        chatId = result;
        
        debugPrint('Created new chat with ID: $chatId');
      }
      
      if (chatId == null) {
        throw Exception('Failed to get or create chat');
      }
      
      // Update selected chat
      selectedChatId.value = chatId;
      
      // Load messages for this chat
      await loadMessages(chatId);
      
      // Navigate to chat detail screen
      Get.toNamed(
        Routes.CHAT_DETAIL,
        arguments: {
          'chat_id': chatId,
          'other_user_id': otherUserId,
          'username': username
        }
      );
    } catch (e) {
      debugPrint('Error opening chat: $e');
      Get.snackbar(
        'Error',
        'Could not open chat. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white
      );
    }
  }
  
  // Load user profile and add to AccountDataProvider for UI access
  Future<void> _loadUserProfile(String userId) async {
    try {
      final accountProvider = Get.find<AccountDataProvider>();
      
      // Check if we already have this user in our lists
      final userInFollowing = accountProvider.following
          .any((user) => user['following_id'] == userId);
      final userInFollowers = accountProvider.followers
          .any((user) => user['follower_id'] == userId);
          
      if (!userInFollowing && !userInFollowers) {
        debugPrint('Loading profile for user ID: $userId');
        
        // Fetch from profiles table
        final response = await _supabaseService.client
            .from('profiles')
            .select()
            .eq('user_id', userId)
            .single();
            
        if (response != null) {
          debugPrint('Found profile for chat user: $response');
          
          // Add to following list for easy access in UI
          accountProvider.following.add({
            'following_id': userId,
            'username': response['username'] ?? 'User',
            'avatar': response['avatar'],
            'google_avatar': response['google_avatar'],
            'nickname': response['nickname'],
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile for chat: $e');
    }
  }
  
  // Load messages for a chat
  Future<void> loadMessages(String chatId) async {
    isSendingMessage.value = true;
    
    try {
      final response = await _supabaseService.client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at');
      
      if (response.isNotEmpty) {
        final messagesList = List<Map<String, dynamic>>.from(response);
        
        // Clear processed message IDs when loading messages
        _processedMessageIds.clear();
        
        // Decrypt message content
        for (var message in messagesList) {
          // Store processed message IDs
          if (message['message_id'] != null) {
            _processedMessageIds.add(message['message_id'].toString());
          }
          
          // Decrypt message content with chat-specific key
          if (message['content'] != null && message['content'].toString().isNotEmpty) {
            try {
              message['content'] = await _encryptionService.decryptMessageForChat(message['content'], chatId);
            } catch (e) {
              // If decryption fails, try legacy decryption
              try {
                message['content'] = _encryptionService.decryptMessage(message['content']);
              } catch (e2) {
                debugPrint('Could not decrypt message: $e2');
              }
            }
          }
        }
        
        messages.value = messagesList;
        debugPrint('Loaded ${messages.length} messages');
        
        // Subscribe to realtime updates for this chat
        _subscribeToChat(chatId);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      isSendingMessage.value = false;
    }
  }
  
  // Send a message
  Future<void> sendMessage(String chatId, String content) async {
    if (content.isEmpty) {
      debugPrint('Cannot send empty message');
      return;
    }
    
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) {
      debugPrint('Cannot send message: User not logged in');
      return;
    }
    
    debugPrint('Sending message to chat $chatId: $content');
    isSendingMessage.value = true;
    
    try {
      // Set expiration time to 24 hours from now
      final expiresAt = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
      final now = DateTime.now().toIso8601String();
      
      // Encrypt the message content with chat-specific key
      final encryptedContent = await _encryptionService.encryptMessageForChat(content, chatId);
      
      // Add message to database
      debugPrint('Inserting encrypted message into database...');
      final response = await _supabaseService.client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedContent,
        'created_at': now,
        'expires_at': expiresAt,
      }).select();
      
      debugPrint('Message inserted, response: $response');
      
      if (response.isNotEmpty) {
        // Add the message immediately to local state
        final newMessage = Map<String, dynamic>.from(response[0]);
        
        // Add message ID to processed list to prevent duplicates
        if (newMessage['message_id'] != null) {
          final messageId = newMessage['message_id'].toString();
          _processedMessageIds.add(messageId);
          debugPrint('Added sent message ID to processed list: $messageId');
        }
        
        // Use original content for display (not encrypted version)
        newMessage['content'] = content;
        
        // Check if we're already tracking this message (could happen with search + chat)
        final isDuplicate = _isDuplicateMessage(newMessage);
        if (!isDuplicate) {
          final newMessages = List<Map<String, dynamic>>.from(messages);
          newMessages.add(newMessage);
          messages.assignAll(newMessages); // Use assignAll instead of .value =
        } else {
          debugPrint('Skipping duplicate of sent message in UI update');
        }
        
        // Reload recent chats to update the chat list
        loadRecentChats();
        
        // Clear the message input
        messageController.clear();
        debugPrint('Message sent successfully');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      Get.snackbar(
        'Error',
        'Could not send message. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white
      );
    } finally {
      isSendingMessage.value = false;
    }
  }
  
  // Set up realtime subscription for messages
  void _setupRealtimeSubscription() {
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) return;
    
    try {
      _cleanupRealtimeSubscription();
      
      debugPrint('Setting up global message subscription');
      
      // Subscribe to messages table to detect new messages for our chats
      _chatSubscription = _supabaseService.client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (_) {
              // Reload recent chats when there's a new message
              loadRecentChats();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              // When a message is updated (like read status), refresh chat list
              debugPrint('Global message update detected: ${payload.newRecord}');
              loadRecentChats();
              
              // If we have an active chat open and this message belongs to that chat
              if (selectedChatId.isNotEmpty && 
                  payload.newRecord['chat_id'] == selectedChatId.value) {
                
                // Reload messages to reflect the update
                loadMessages(selectedChatId.value);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up chat subscription: $e');
    }
  }
  
  // Subscribe to a specific chat for realtime message updates
  void _subscribeToChat(String chatId) {
    try {
      // First unsubscribe from any existing channel to avoid duplicate subscriptions
      _cleanupChatSubscription();
      
      debugPrint('Creating new real-time subscription for chat: $chatId');
      
      // Create a new subscription with enhanced logging
      final chatChannel = _supabaseService.client
          .channel('public:messages:$chatId')
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
              debugPrint('Realtime message received: ${payload.newRecord}');
              
              // Add the new message to the messages list
              final newMessage = Map<String, dynamic>.from(payload.newRecord);
              final messageId = newMessage['message_id']?.toString();
              
              // Skip if we've already processed this message ID
              if (messageId != null && _processedMessageIds.contains(messageId)) {
                debugPrint('Skipping already processed message: $messageId');
                return;
              }
              
              // Add to processed IDs to prevent future duplicates
              if (messageId != null) {
                _processedMessageIds.add(messageId);
                
                // Log for debugging
                debugPrint('Added message ID to processed list: $messageId');
                debugPrint('Processed IDs count: ${_processedMessageIds.length}');
              }
              
              // Decrypt message content with chat-specific key
              if (newMessage['content'] != null && newMessage['content'].toString().isNotEmpty) {
                try {
                  newMessage['content'] = await _encryptionService.decryptMessageForChat(
                    newMessage['content'], 
                    chatId
                  );
                } catch (e) {
                  // If chat-specific decryption fails, try legacy decryption
                  try {
                    newMessage['content'] = _encryptionService.decryptMessage(newMessage['content']);
                  } catch (e2) {
                    debugPrint('Could not decrypt realtime message: $e2');
                  }
                }
              }
              
              // Extra check to prevent duplicates based on timestamps
              final bool isDuplicate = _isDuplicateMessage(newMessage);
              if (isDuplicate) {
                debugPrint('Skipping duplicate message based on timestamp and content check');
                return;
              }
              
              debugPrint('Adding realtime message to UI: ${newMessage['content']}');
              
              // IMPROVED: More robust approach for updating UI
              // 1. Add the message to the list
              messages.add(newMessage);
              // 2. Refresh the observable to notify listeners
              messages.refresh();
              // 3. Force UI update at app level to ensure UI is refreshed
              Get.forceAppUpdate();
              // 4. Since this method can run in background, post a callback to ensure UI refresh
              WidgetsBinding.instance.addPostFrameCallback((_) {
                debugPrint('Post-frame callback: updating UI with new message');
                messages.refresh();
                Get.forceAppUpdate();
              });
              
              // Also reload recent chats to update the chat list
              loadRecentChats();
              
              debugPrint('New message received and UI updated: ${newMessage['content']}');
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
              debugPrint('Realtime message update received: ${payload.newRecord}');
              
              // Get the updated message data
              final updatedMessage = Map<String, dynamic>.from(payload.newRecord);
              final messageId = updatedMessage['message_id']?.toString();
              
              if (messageId == null) {
                debugPrint('No message ID found in update payload, skipping');
                return;
              }
              
              debugPrint('Processing message update for ID: $messageId, is_read: ${updatedMessage['is_read']}');
              
              // Update the corresponding message in our local list
              bool updated = false;
              for (var i = 0; i < messages.length; i++) {
                final msg = messages[i];
                final msgId = msg['message_id']?.toString();
                
                if (msgId == messageId) {
                  // Preserve the decrypted content when updating
                  updatedMessage['content'] = msg['content'];
                  messages[i] = updatedMessage;
                  updated = true;
                  debugPrint('Updated message read status for ID: $messageId to ${updatedMessage['is_read']}');
                  break;
                }
              }
              
              // IMPROVED: More robust update process
              if (updated) {
                // 1. Refresh observable to notify listeners
                messages.refresh();
                // 2. Force UI update at app level
                Get.forceAppUpdate();
                // 3. Post a callback to ensure UI is updated
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  messages.refresh();
                  Get.forceAppUpdate();
                  debugPrint('Post-frame callback: UI updated for read status change');
                });
                debugPrint('Message read status updated in UI');
              } else {
                debugPrint('Could not find message with ID: $messageId to update');
              }
              
              // Also refresh recent chats in case the read status affects the UI there
              loadRecentChats();
            },
          );
      
      // Subscribe and store the channel reference
      chatChannel.subscribe((status, error) {
        debugPrint('Chat channel subscription status: $status, error: $error');
        if (error != null) {
          debugPrint('Error with chat subscription: $error');
          // Try to resubscribe if there was an error
          Future.delayed(const Duration(seconds: 2), () {
            debugPrint('Attempting to resubscribe after error');
            _resubscribeToChat(chatId);
          });
        }
      });
      _chatSubscription = chatChannel;
      
      // Set a flag to track connection status
      isChatConnected.value = true;
      
      debugPrint('Subscribed to chat: $chatId');
    } catch (e) {
      debugPrint('Error subscribing to chat: $e');
      
      // Try to resubscribe after a delay
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint('Attempting to resubscribe after exception');
        _subscribeToChat(chatId);
      });
    }
  }
  
  // Helper method to check for duplicate messages with more robust checks
  bool _isDuplicateMessage(Map<String, dynamic> newMessage) {
    // First check for ID-based duplicates (already handled above, but just in case)
    if (newMessage['message_id'] != null && 
        messages.any((msg) => msg['message_id'] != null && msg['message_id'] == newMessage['message_id'])) {
      return true;
    }
    
    // Get timestamps to check for messages sent in the last 5 seconds
    final newMessageTime = DateTime.tryParse(newMessage['created_at'] ?? '');
    if (newMessageTime == null) return false;
    
    final content = newMessage['content']?.toString() ?? '';
    final senderId = newMessage['sender_id'];
    
    // Check if we have a message with the same content, sender, and recently sent
    return messages.any((msg) {
      if (msg['sender_id'] != senderId) return false;
      if (msg['content'] != content) return false;
      
      final existingMsgTime = DateTime.tryParse(msg['created_at'] ?? '');
      if (existingMsgTime == null) return false;
      
      // Check if messages were sent within 5 seconds of each other
      return (existingMsgTime.difference(newMessageTime).inSeconds.abs() < 5);
    });
  }
  
  // Clean up chat subscription to prevent duplicates
  void _cleanupChatSubscription() {
    if (_chatSubscription != null) {
      try {
        _chatSubscription!.unsubscribe();
        debugPrint('Unsubscribed from previous chat channel');
      } catch (e) {
        debugPrint('Error unsubscribing from chat: $e');
      }
      _chatSubscription = null;
    }
  }
  
  void _cleanupRealtimeSubscription() {
    _cleanupChatSubscription();
  }
  
  // Timer to check for and delete expired messages
  void _startMessageCleanupTimer() {
    Timer.periodic(const Duration(hours: 1), (_) {
      _deleteExpiredMessages();
    });
  }
  
  // Delete messages that are older than 24 hours
  Future<void> _deleteExpiredMessages() async {
    try {
      final now = DateTime.now().toIso8601String();
      
      // Delete messages where expires_at is in the past
      await _supabaseService.client
          .from('messages')
          .delete()
          .lt('expires_at', now);
          
      debugPrint('Deleted expired messages');
      
      // If we have an active chat open, reload messages
      if (selectedChatId.value.isNotEmpty) {
        loadMessages(selectedChatId.value);
      }
    } catch (e) {
      debugPrint('Error deleting expired messages: $e');
    }
  }
  
  // Mark all messages in a chat as read - New implementation
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
      
      // Set last update time
      _lastReadStatusUpdate = now;
      
      debugPrint('⚠️ ATTEMPTING TO MARK MESSAGES AS READ IN CHAT: $chatId');
      
      // Look for unread messages in this chat that are sent by others
      final unreadMessages = await _supabaseService.client
          .from('messages')
          .select('*')
          .eq('chat_id', chatId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);
      
      if (unreadMessages == null || unreadMessages.isEmpty) {
        debugPrint('No unread messages found');
        return;
      }
      
      final List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(unreadMessages);
      
      // Log first message to check structure
      if (messages.isNotEmpty) {
        debugPrint('First message structure: ${messages.first}');
      }
      
      debugPrint('Found ${messages.length} unread messages');
      
      // Try using the RPC function approach, which is the most reliable
      try {
        debugPrint('⚠️ Attempting to use RPC function to mark messages as read');
        final result = await _supabaseService.client.rpc(
          'mark_messages_as_read',
          params: {
            'p_chat_id': chatId,
            'p_user_id': currentUserId,
          },
        );
        
        debugPrint('RPC function result: $result');
      } catch (e) {
        debugPrint('⚠️ RPC function failed (you may need to create it in Supabase): $e');
        
        // Fall back to previous bulk update approach
        try {
          debugPrint('⚠️ Falling back to bulk update');
          
          // Attempt bulk update
          final bulkResult = await _supabaseService.client
              .from('messages')
              .update({'is_read': true})
              .eq('chat_id', chatId)
              .neq('sender_id', currentUserId)
              .eq('is_read', false);
          
          debugPrint('Bulk update result: $bulkResult');
        } catch (bulkError) {
          debugPrint('⚠️ Bulk update failed: $bulkError');
          
          // If bulk update fails, try individual updates
          for (final message in messages) {
            final String? messageId = message['message_id'] as String?;
            
            if (messageId == null) {
              debugPrint('⚠️ Message ID is null, skipping update');
              continue;
            }
            
            debugPrint('⚠️ Updating individual message with ID: $messageId');
            
            try {
              final result = await _supabaseService.client
                  .from('messages')
                  .update({'is_read': true})
                  .eq('message_id', messageId);
              
              debugPrint('Individual update result: $result');
            } catch (updateError) {
              debugPrint('⚠️ Error updating individual message: $updateError');
            }
          }
        }
      }
      
      // Update local UI
      _updateLocalReadStatus(chatId, currentUserId);
      
      debugPrint('⚠️ Completed marking messages as read');
    } catch (e) {
      debugPrint('⚠️ Error in markMessagesAsRead: $e');
    }
  }
  
  // Helper to update local UI without database calls
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
  
  // Load user preferences from local storage
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = Get.find<StorageService>();
      final dismissed = prefs.getBool('dismissed_expiry_banner') ?? false;
      hasUserDismissedExpiryBanner.value = dismissed;
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }
  
  // Dismiss the expiry banner and save preference
  void dismissExpiryBanner() {
    hasUserDismissedExpiryBanner.value = true;
    try {
      final prefs = Get.find<StorageService>();
      prefs.saveBool('dismissed_expiry_banner', true);
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }
}
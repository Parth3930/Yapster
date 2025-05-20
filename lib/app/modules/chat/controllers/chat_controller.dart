import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';

class ChatController extends GetxController {
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
  
  @override
  void onInit() {
    super.onInit();
    
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
  }
  
  @override
  void onClose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    messageController.dispose();
    _searchDebounce?.cancel();
    _cleanupRealtimeSubscription();
    super.onClose();
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
      
      if (usersResponse != null) {
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
              chat['last_message'] = _encryptionService.decryptMessage(chat['last_message']);
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
  
  // Load messages for a chat
  Future<void> loadMessages(String chatId) async {
    isSendingMessage.value = true;
    
    try {
      final response = await _supabaseService.client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at');
      
      if (response != null) {
        final messagesList = List<Map<String, dynamic>>.from(response);
        
        // Clear processed message IDs when loading messages
        _processedMessageIds.clear();
        
        // Decrypt message content
        for (var message in messagesList) {
          // Store processed message IDs
          if (message['id'] != null) {
            _processedMessageIds.add(message['id'].toString());
          }
          
          // Decrypt message content
          if (message['content'] != null && message['content'].toString().isNotEmpty) {
            try {
              message['content'] = _encryptionService.decryptMessage(message['content']);
            } catch (e) {
              // If decryption fails, message might not be encrypted yet
              debugPrint('Could not decrypt message: $e');
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
      
      // Encrypt the message content
      final encryptedContent = _encryptionService.encryptMessage(content);
      
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
      
      if (response is List && response.isNotEmpty) {
        // Add the message immediately to local state
        final newMessage = Map<String, dynamic>.from(response[0]);
        
        // Add message ID to processed list to prevent duplicates
        if (newMessage['id'] != null) {
          final messageId = newMessage['id'].toString();
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
      
      // Create a new subscription
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
            callback: (payload) {
              // Add the new message to the messages list
              final newMessage = Map<String, dynamic>.from(payload.newRecord);
              final messageId = newMessage['id']?.toString();
              
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
              
              // Decrypt message content
              if (newMessage['content'] != null && newMessage['content'].toString().isNotEmpty) {
                try {
                  newMessage['content'] = _encryptionService.decryptMessage(newMessage['content']);
                } catch (e) {
                  debugPrint('Could not decrypt realtime message: $e');
                }
              }
              
              // Extra check to prevent duplicates based on timestamps
              final bool isDuplicate = _isDuplicateMessage(newMessage);
              if (isDuplicate) {
                debugPrint('Skipping duplicate message based on timestamp and content check');
                return;
              }
              
              // Use more aggressive update method for UI refresh
              final newMessages = List<Map<String, dynamic>>.from(messages);
              newMessages.add(newMessage);
              messages.assignAll(newMessages); // Use assignAll instead of .value =
              
              // Also reload recent chats to update the chat list
              loadRecentChats();
              
              debugPrint('New message received: ${newMessage['content']}');
            },
          );
      
      // Subscribe and store the channel reference
      chatChannel.subscribe();
      _chatSubscription = chatChannel;
      
      debugPrint('Subscribed to chat: $chatId');
    } catch (e) {
      debugPrint('Error subscribing to chat: $e');
    }
  }
  
  // Helper method to check for duplicate messages with more robust checks
  bool _isDuplicateMessage(Map<String, dynamic> newMessage) {
    // First check for ID-based duplicates (already handled above, but just in case)
    if (newMessage['id'] != null && 
        messages.any((msg) => msg['id'] != null && msg['id'] == newMessage['id'])) {
      return true;
    }
    
    // Get timestamps to check for messages sent in the last 5 seconds
    final now = DateTime.now();
    final newMessageTime = DateTime.tryParse(newMessage['created_at'] ?? '');
    if (newMessageTime == null) return false;
    
    final timeDifference = now.difference(newMessageTime).inSeconds.abs();
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
  
  // Mark all messages in a chat as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;
      
      // Update all unread messages sent by the other user to read=true
      await _supabaseService.client
          .from('messages')
          .update({ 'is_read': true })
          .eq('chat_id', chatId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);
      
      // If we already have messages loaded, update them locally too
      if (messages.isNotEmpty) {
        final updatedMessages = messages.map((msg) {
          if (msg['sender_id'] != currentUserId && msg['is_read'] == false) {
            return {...msg, 'is_read': true};
          }
          return msg;
        }).toList();
        
        messages.assignAll(updatedMessages);
      }
      
      debugPrint('Marked messages as read in chat $chatId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
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
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';

class ChatController extends GetxController with WidgetsBindingObserver {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider = Get.find<AccountDataProvider>();
  final ChatCacheService _chatCacheService = Get.find<ChatCacheService>();
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
  
  // Performance optimization: batch operations
  final bool _useBatchOperations = true;
  
  // Cache for decrypted messages to avoid repeated decryption
  final Map<String, String> _decryptedContentCache = {};
  
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
    
    // Load data after initialization - try from cache first
    _loadInitialDataFromCache();
    
    // Set up realtime subscription
    _setupRealtimeSubscription();
    
    // Start the message cleanup timer that runs once per hour
    _startMessageCleanupTimer();
    
    // Load user preferences
    _loadUserPreferences();
    
    // Set initial active time
    _lastActiveTime = DateTime.now();
  }
  
  // Load initial data from cache when controller starts
  Future<void> _loadInitialDataFromCache() async {
    // Load recent chats from cache to show immediately
    final cachedChats = _chatCacheService.getCachedRecentChats();
    if (cachedChats != null && cachedChats.isNotEmpty) {
      recentChats.value = cachedChats;
      debugPrint('Loaded ${cachedChats.length} chats from cache');
    }
    
    // Then refresh from network
    loadRecentChats();
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
        
        // Refresh chat list - try cache first then network
        _refreshChatsWithCacheFallback();
        
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
  
  // Load chats with cache fallback
  Future<void> _refreshChatsWithCacheFallback() async {
    // Try to refresh from network
    final refreshSuccess = await loadRecentChats();
    
    // If network refresh failed, ensure we at least have cached data
    if (!refreshSuccess && recentChats.isEmpty) {
      final cachedChats = _chatCacheService.getCachedRecentChats();
      if (cachedChats != null && cachedChats.isNotEmpty) {
        recentChats.value = cachedChats;
        debugPrint('Using cached chats as network refresh failed');
      }
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
        
        // Also refresh messages from server with cache fallback
        _refreshMessagesWithCacheFallback(chatId);
      }
    } catch (e) {
      debugPrint('Error in chat subscription: $e');
      // If any error occurs, try to resubscribe from scratch
      _cleanupChatSubscription();
      _subscribeToChat(chatId);
    }
  }
  
  // Refresh messages with cache fallback
  Future<void> _refreshMessagesWithCacheFallback(String chatId) async {
    try {
      // Try to load from network first
      await loadMessages(chatId);
    } catch (e) {
      debugPrint('Error loading messages from network: $e');
      
      // Fallback to cache if available and not already loaded
      if (messages.isEmpty) {
        final cachedMessages = _chatCacheService.getCachedMessages(chatId);
        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          messages.value = cachedMessages;
          debugPrint('Using cached messages as network refresh failed');
        }
      }
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
      
      // Check if we have this search result cached
      final cacheKey = 'search_${query.toLowerCase()}';
      final cachedSearchResults = _getCachedSearchResults(cacheKey);
      
      if (cachedSearchResults != null) {
        searchResults.value = cachedSearchResults;
        isSearching.value = false;
        return;
      }
      
      // Combined search results list
      List<Map<String, dynamic>> results = [];
      
      // Parallel search for better performance
      final futures = <Future>[];
      
      // 1. Search all users in database
      final userSearchFuture = _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .ilike('username', '%$query%')
          .neq('user_id', currentUserId)
          .limit(10)
          .then((usersResponse) {
            if (usersResponse.isNotEmpty) {
              results.addAll(List<Map<String, dynamic>>.from(usersResponse));
            }
          });
      
      futures.add(userSearchFuture);
      
      // Process local data in memory for faster results
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
      
      // Wait for all search operations to complete
      await Future.wait(futures);
      
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
      
      final finalResults = uniqueResults.values.toList();
      
      // Cache the results for future use
      _cacheSearchResults(cacheKey, finalResults);
      
      searchResults.value = finalResults;
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      isSearching.value = false;
    }
  }
  
  // Cache search results in memory
  void _cacheSearchResults(String cacheKey, List<Map<String, dynamic>> results) {
    // Use a simple in-memory cache with a 5 minute TTL
    final storage = Get.find<StorageService>();
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'results': results
    };
    storage.saveObject(cacheKey, cacheData);
  }
  
  // Get cached search results
  List<Map<String, dynamic>>? _getCachedSearchResults(String cacheKey) {
    try {
      final storage = Get.find<StorageService>();
      final cacheData = storage.getObject(cacheKey);
      
      if (cacheData != null) {
        final timestamp = DateTime.parse(cacheData['timestamp']);
        final now = DateTime.now();
        
        // Check if cache is still valid (5 minutes)
        if (now.difference(timestamp).inMinutes < 5) {
          return List<Map<String, dynamic>>.from(cacheData['results']);
        }
      }
    } catch (e) {
      debugPrint('Error retrieving cached search results: $e');
    }
    
    return null;
  }
  
  Future<bool> loadRecentChats() async {
    if (!_supabaseService.isAuthenticated.value) return false;
    
    // Check cache first unless it's a forced refresh
    final cachedChats = _chatCacheService.getCachedRecentChats();
    if (cachedChats != null && cachedChats.isNotEmpty && !isLoadingChats.value) {
      recentChats.value = cachedChats;
      debugPrint('Using cached recent chats');
      
      // Refresh in background unless we're already loading
      if (!isLoadingChats.value) {
        _loadRecentChatsFromNetwork();
      }
      return true;
    }
    
    // No valid cache, load from network
    return await _loadRecentChatsFromNetwork();
  }
  
  Future<bool> _loadRecentChatsFromNetwork() async {
    isLoadingChats.value = true;
    
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) {
        isLoadingChats.value = false;
        return false;
      }
      
      // Use the SQL function to get user chats with all necessary data
      final response = await _supabaseService.client
          .rpc('get_user_chats', params: {
            'user_id_param': currentUserId
          });
      
      if (response != null) {
        final chatsList = List<Map<String, dynamic>>.from(response);
        
        // Decrypt message content for previews more efficiently
        await _decryptChatPreviews(chatsList);
        
        recentChats.value = chatsList;
        
        // Cache the results
        _chatCacheService.cacheRecentChats(chatsList);
        
        debugPrint('Loaded and cached ${recentChats.length} chats');
        isLoadingChats.value = false;
        return true;
      } else {
        recentChats.value = [];
        isLoadingChats.value = false;
        return false;
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
      isLoadingChats.value = false;
      return false;
    }
  }
  
  // More efficient way to decrypt chat previews in parallel
  Future<void> _decryptChatPreviews(List<Map<String, dynamic>> chats) async {
    final decryptionFutures = <Future>[];
    
    for (final chat in chats) {
      if (chat['last_message'] != null && chat['last_message'].toString().isNotEmpty) {
        // Add each decryption task to our futures list
        decryptionFutures.add(_decryptChatPreview(chat));
      }
    }
    
    // Wait for all decryption tasks to complete in parallel
    await Future.wait(decryptionFutures);
  }
  
  Future<void> _decryptChatPreview(Map<String, dynamic> chat) async {
    if (chat['last_message'] == null || chat['last_message'].toString().isEmpty) {
      return;
    }
    
    try {
      final encryptedMessage = chat['last_message'].toString();
      final chatId = chat['chat_id'];
      
      // Check if we already have it decrypted in our cache
      final cacheKey = '$chatId:$encryptedMessage';
      if (_decryptedContentCache.containsKey(cacheKey)) {
        chat['last_message'] = _decryptedContentCache[cacheKey];
        return;
      }
      
      // Try to decrypt with chat-specific key first
      if (chatId != null) {
        final decrypted = await _encryptionService.decryptMessageForChat(
          encryptedMessage,
          chatId
        );
        chat['last_message'] = decrypted;
        
        // Cache the decrypted result
        _decryptedContentCache[cacheKey] = decrypted;
      } else {
        // Fall back to legacy decryption
        final decrypted = _encryptionService.decryptMessage(encryptedMessage);
        chat['last_message'] = decrypted;
        
        // Cache the decrypted result
        _decryptedContentCache[cacheKey] = decrypted;
      }
    } catch (e) {
      debugPrint('Could not decrypt message preview: $e');
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
      
      // Try preload messages from cache while loading from network
      // This provides instant UI response while fresh data loads
      final cachedMessages = await _chatCacheService.preloadMessagesFromStorage(chatId);
      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        messages.value = cachedMessages;
        debugPrint('Showed ${cachedMessages.length} cached messages while loading fresh data');
      }
      
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
    } catch (e) {
      debugPrint('Error loading user profile for chat: $e');
    }
  }
  
  // Load messages for a chat
  Future<void> loadMessages(String chatId) async {
    // Set loading state
    isSendingMessage.value = true;
    
    try {
      // Check cache first for immediate UI update
      final cachedMessages = _chatCacheService.getCachedMessages(chatId);
      final bool useCache = cachedMessages != null && cachedMessages.isNotEmpty;
      
      if (useCache) {
        // Update UI immediately from cache
        messages.value = cachedMessages;
        debugPrint('Loaded ${cachedMessages.length} messages from cache');
        
        // Lazy load from network if cache is fresh
        final shouldRefreshFromNetwork = !_isCacheFresh(chatId);
        if (shouldRefreshFromNetwork) {
          // Continue loading from network in background
          debugPrint('Cache is stale, refreshing from network in background');
        } else {
          // Cache is fresh enough, skip network load for now
          isSendingMessage.value = false;
          // Still set up subscription to ensure realtime updates
          _subscribeToChat(chatId);
          return;
        }
      }
      
      // Load from network
      final response = await _supabaseService.client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at');
      
      if (response != null && response.isNotEmpty) {
        final messagesList = List<Map<String, dynamic>>.from(response);
        
        // Clear processed message IDs when loading messages
        _processedMessageIds.clear();
        
        // Decrypt message content in parallel for better performance
        await _decryptMessages(messagesList, chatId);
        
        // Update the messages list
        messages.value = messagesList;
        
        // Cache the messages for future use
        _chatCacheService.cacheMessages(chatId, messagesList);
        
        debugPrint('Loaded and cached ${messages.length} messages from network');
        
        // Subscribe to realtime updates for this chat
        _subscribeToChat(chatId);
      } else if (!useCache) {
        // No messages from network and no cache - set empty list
        messages.value = [];
        debugPrint('No messages found for chat $chatId');
        
        // Still set up subscription to receive new messages
        _subscribeToChat(chatId);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      // If we have cache, keep using it even if network failed
      if (messages.isEmpty) {
        final fallbackCache = _chatCacheService.getCachedMessages(chatId);
        if (fallbackCache != null) {
          messages.value = fallbackCache;
          debugPrint('Using cached messages due to network error');
        }
      }
    } finally {
      isSendingMessage.value = false;
    }
  }
  
  // Decrypt messages in parallel for better performance
  Future<void> _decryptMessages(List<Map<String, dynamic>> messagesList, String chatId) async {
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
  
  // Decrypt a single message
  Future<void> _decryptMessage(Map<String, dynamic> message, String chatId) async {
    try {
      final encryptedContent = message['content'].toString();
      
      // Check decryption cache first
      final cacheKey = '$chatId:$encryptedContent';
      if (_decryptedContentCache.containsKey(cacheKey)) {
        message['content'] = _decryptedContentCache[cacheKey];
        return;
      }
      
      // Decrypt with chat-specific key
      final decrypted = await _encryptionService.decryptMessageForChat(encryptedContent, chatId);
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
    
    debugPrint('Sending message to chat $chatId');
    isSendingMessage.value = true;
    
    try {
      // Set expiration time to 24 hours from now
      final expiresAt = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
      final now = DateTime.now().toIso8601String();
      
      // Encrypt the message content with chat-specific key
      final encryptedContent = await _encryptionService.encryptMessageForChat(content, chatId);
      
      // Create message object
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedContent,
        'created_at': now,
        'expires_at': expiresAt,
      };
      
      // Add message to database
      debugPrint('Inserting encrypted message into database...');
      final response = await _supabaseService.client
          .from('messages')
          .insert(messageData)
          .select();
      
      if (response != null && response.isNotEmpty) {
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
        
        // Cache the decrypted content for future reference
        final cacheKey = '$chatId:$encryptedContent';
        _decryptedContentCache[cacheKey] = content;
        
        // Check if we're already tracking this message
        final isDuplicate = _isDuplicateMessage(newMessage);
        if (!isDuplicate) {
          final newMessages = List<Map<String, dynamic>>.from(messages);
          newMessages.add(newMessage);
          messages.assignAll(newMessages); // Use assignAll instead of .value =
          
          // Update the cache
          _chatCacheService.cacheMessages(chatId, messages);
        } else {
          debugPrint('Skipping duplicate of sent message in UI update');
        }
        
        // Update recent chats cache to avoid having to reload from network
        _updateRecentChatsAfterSend(chatId, content, currentUserId);
        
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
  
  // Update recent chats in memory after sending a message
  void _updateRecentChatsAfterSend(String chatId, String content, String senderId) {
    // Find the chat in recent chats
    final chatIndex = recentChats.indexWhere((chat) => chat['chat_id'] == chatId);
    
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
        final aTime = DateTime.tryParse(a['last_message_time'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['last_message_time'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime); // Newest first
      });
      
      // Update the observable and cache
      recentChats.value = updatedChats;
      _chatCacheService.cacheRecentChats(updatedChats);
      
      debugPrint('Updated recent chats in cache after sending message');
    } else {
      // Chat not in recent chats yet, refresh from server
      loadRecentChats();
    }
  }
  
  // Mark all messages in a chat as read - Optimized implementation
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
        await _supabaseService.client.rpc(
          'mark_messages_as_read',
          params: {
            'p_chat_id': chatId,
            'p_user_id': currentUserId,
          },
        ).then((_) {
          debugPrint('Successfully marked messages as read via RPC');
        }).catchError((e) {
          debugPrint('RPC function failed, falling back to direct update: $e');
          
          // Fall back to bulk update
          return _supabaseService.client
              .from('messages')
              .update({'is_read': true})
              .eq('chat_id', chatId)
              .neq('sender_id', currentUserId)
              .eq('is_read', false);
        });
        
        // Update the cached messages to reflect read status
        final updatedMessages = List<Map<String, dynamic>>.from(messages);
        for (var i = 0; i < updatedMessages.length; i++) {
          if (updatedMessages[i]['chat_id'] == chatId && 
              updatedMessages[i]['sender_id'] != currentUserId) {
            updatedMessages[i]['is_read'] = true;
          }
        }
        
        // Update cache with read status changed
        _chatCacheService.cacheMessages(chatId, updatedMessages);
        
      } catch (e) {
        debugPrint('Error marking messages as read: $e');
        // Even if the server update fails, keep optimistic UI update
      }
    } catch (e) {
      debugPrint('Error in markMessagesAsRead: $e');
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
  
  // Set up realtime subscription for messages
  void _setupRealtimeSubscription() {
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) return;
    
    try {
      _cleanupRealtimeSubscription();
      
      debugPrint('Setting up global message subscription');
      
      // Subscribe to messages table to detect new messages for our chats
      // Use a lighter approach that doesn't require full reload on every message
      _chatSubscription = _supabaseService.client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              // Check if this message affects us
              final chatId = payload.newRecord['chat_id'];
              final senderId = payload.newRecord['sender_id'];
              
              // Skip if we're the sender (we already handled local updates)
              if (senderId == currentUserId) {
                return;
              }
              
              // Check if this message is for a chat we're viewing
              if (selectedChatId.value == chatId) {
                // We'll handle this in the chat-specific subscription
                return;
              }
              
              // We received a message in a chat we're not currently viewing
              // Just refresh recent chats to update unread counts and previews
              _refreshRecentChatsAfterNewMessage(chatId);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              // For updates (usually read status), selectively refresh only what's needed
              final chatId = payload.newRecord['chat_id'];
              
              // Check if chat list needs refreshing due to this update
              final shouldRefreshChats = _shouldRefreshChatsAfterUpdate(payload.newRecord);
              if (shouldRefreshChats) {
                _refreshRecentChatsAfterMessageUpdate(chatId);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up chat subscription: $e');
    }
  }
  
  // Intelligently decide if we need to refresh chats list based on an update
  bool _shouldRefreshChatsAfterUpdate(Map<String, dynamic> record) {
    // Check if this update is for read status, which affects unread counts
    if (record.containsKey('is_read')) {
      return true;
    }
    
    // Check if this is updating the last message in a chat
    final chatId = record['chat_id'];
    final messageId = record['message_id'];
    
    if (chatId != null) {
      final chat = recentChats.firstWhereOrNull((c) => c['chat_id'] == chatId);
      if (chat != null && chat['last_message_id'] == messageId) {
        return true;
      }
    }
    
    return false;
  }
  
  // Refresh recent chats after receiving a new message
  void _refreshRecentChatsAfterNewMessage(String? chatId) {
    if (chatId == null) return;
    
    // Check if we already have this chat in our list
    final chatIndex = recentChats.indexWhere((chat) => chat['chat_id'] == chatId);
    
    if (chatIndex >= 0) {
      // We have this chat, selectively update just this one instead of reload all
      _loadSingleChatDetails(chatId).then((updatedChat) {
        if (updatedChat != null) {
          // Create updated list
          final updatedChats = List<Map<String, dynamic>>.from(recentChats);
          
          // Replace the old chat data
          updatedChats[chatIndex] = updatedChat;
          
          // Sort by most recent first
          updatedChats.sort((a, b) {
            final aTime = DateTime.tryParse(a['last_message_time'] ?? '') ?? DateTime(1970);
            final bTime = DateTime.tryParse(b['last_message_time'] ?? '') ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });
          
          // Update observable and cache
          recentChats.value = updatedChats;
          _chatCacheService.cacheRecentChats(updatedChats);
          
          debugPrint('Updated single chat in list after receiving message');
        }
      });
    } else {
      // Chat not in list, need full refresh
      loadRecentChats();
    }
  }
  
  // Load details for a single chat
  Future<Map<String, dynamic>?> _loadSingleChatDetails(String chatId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return null;
      
      // Use RPC to get single chat details
      final response = await _supabaseService.client
          .rpc('get_single_chat', params: {
            'chat_id_param': chatId,
            'user_id_param': currentUserId
          });
      
      if (response != null && response.isNotEmpty) {
        final chat = Map<String, dynamic>.from(response[0]);
        
        // Decrypt the message preview if needed
        if (chat['last_message'] != null && chat['last_message'].toString().isNotEmpty) {
          await _decryptChatPreview(chat);
        }
        
        return chat;
      }
    } catch (e) {
      debugPrint('Error loading single chat details: $e');
    }
    
    return null;
  }
  
  // Update recent chats after a message update
  void _refreshRecentChatsAfterMessageUpdate(String? chatId) {
    if (chatId == null) return;
    
    // Use more efficient targeted update approach similar to new message case
    _refreshRecentChatsAfterNewMessage(chatId);
  }
  
  // Subscribe to a specific chat for realtime message updates
  void _subscribeToChat(String chatId) {
    try {
      // First unsubscribe from any existing channel to avoid duplicate subscriptions
      _cleanupChatSubscription();
      
      debugPrint('Creating new real-time subscription for chat: $chatId');
      
      // Get current user ID
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;
      
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
              
              // Skip if we're the sender (already handled locally)
              if (payload.newRecord['sender_id'] == currentUserId) {
                debugPrint('Skipping own message from realtime updates');
                return;
              }
              
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
              }
              
              // Handle the new message
              await _handleNewRealtimeMessage(newMessage, chatId);
              
              // Mark as read immediately if we're looking at this chat
              if (selectedChatId.value == chatId) {
                markMessagesAsRead(chatId);
              }
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
              debugPrint('Realtime message update received');
              
              // Handle message updates (like read status changes)
              await _handleMessageUpdate(payload.newRecord, chatId);
            },
          );
      
      // Subscribe and store the channel reference
      chatChannel.subscribe((status, error) {
        debugPrint('Chat channel subscription status: $status, error: $error');
        if (error != null) {
          debugPrint('Error with chat subscription: $error');
          // Try to resubscribe if there was an error after a delay
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
  
  // Handle a new message from realtime subscription
  Future<void> _handleNewRealtimeMessage(Map<String, dynamic> newMessage, String chatId) async {
    try {
      // Decrypt message content
      if (newMessage['content'] != null && newMessage['content'].toString().isNotEmpty) {
        try {
          // Check decryption cache first
          final encryptedContent = newMessage['content'].toString();
          final cacheKey = '$chatId:$encryptedContent';
          
          if (_decryptedContentCache.containsKey(cacheKey)) {
            newMessage['content'] = _decryptedContentCache[cacheKey];
          } else {
            // Decrypt with chat-specific key
            final decrypted = await _encryptionService.decryptMessageForChat(
              encryptedContent, 
              chatId
            );
            newMessage['content'] = decrypted;
            
            // Cache for future use
            _decryptedContentCache[cacheKey] = decrypted;
          }
        } catch (e) {
          debugPrint('Could not decrypt realtime message: $e');
        }
      }
      
      // Check for duplicates
      final isDuplicate = _isDuplicateMessage(newMessage);
      if (isDuplicate) {
        debugPrint('Skipping duplicate message');
        return;
      }
      
      // IMPROVED: More efficient UI updates
      // 1. Create a copy of the current messages
      final updatedMessages = List<Map<String, dynamic>>.from(messages);
      // 2. Add the new message
      updatedMessages.add(newMessage);
      // 3. Update the observable list
      messages.value = updatedMessages;
      
      // Update cache
      _chatCacheService.cacheMessages(chatId, messages);
      
      debugPrint('Added new realtime message to chat');
    } catch (e) {
      debugPrint('Error handling realtime message: $e');
    }
  }
  
  // Handle message updates from realtime subscription
  Future<void> _handleMessageUpdate(Map<String, dynamic> updatedMessage, String chatId) async {
    try {
      final messageId = updatedMessage['message_id']?.toString();
      if (messageId == null) return;
      
      // Find and update the message in our local list
      final index = messages.indexWhere((msg) => msg['message_id']?.toString() == messageId);
      
      if (index >= 0) {
        // Get existing message
        final existingMessage = messages[index];
        
        // Preserve decrypted content
        updatedMessage['content'] = existingMessage['content'];
        
        // Update the message
        final updatedMessages = List<Map<String, dynamic>>.from(messages);
        updatedMessages[index] = updatedMessage;
        
        // Update observable
        messages.value = updatedMessages;
        
        // Update cache
        _chatCacheService.cacheMessages(chatId, messages);
        
        debugPrint('Updated message status in UI');
      }
    } catch (e) {
      debugPrint('Error handling message update: $e');
    }
  }
  
  // Helper method to check for duplicate messages with robust checks
  bool _isDuplicateMessage(Map<String, dynamic> newMessage) {
    // First check for ID-based duplicates
    if (newMessage['message_id'] != null && 
        messages.any((msg) => msg['message_id'] != null && msg['message_id'] == newMessage['message_id'])) {
      return true;
    }
    
    // Get timestamps to check for messages sent in the last 5 seconds
    final newMessageTime = DateTime.tryParse(newMessage['created_at'] ?? '');
    if (newMessageTime == null) return false;
    
    final content = newMessage['content']?.toString() ?? '';
    final senderId = newMessage['sender_id'];
    
    // Check if we have a message with the same content, sender, and sent within 5 seconds
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

  bool _isCacheFresh(String chatId) {
    final cachedMessages = _chatCacheService.getCachedMessages(chatId);
    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      final now = DateTime.now();
      final cachedTimestamp = DateTime.parse(cachedMessages[0]['created_at']);
      final age = now.difference(cachedTimestamp).inSeconds;
      return age < 120; // Assuming a 2-minute cache freshness
    }
    return false;
  }
}
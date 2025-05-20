import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';

/// Service for caching chat data to reduce database load
class ChatCacheService extends GetxService {
  // Singleton instance getter
  static ChatCacheService get to => Get.find<ChatCacheService>();
  
  // Dependencies
  final StorageService _storageService = Get.find<StorageService>();
  late EncryptionService _encryptionService;
  
  // In-memory cache for faster access
  final Map<String, List<Map<String, dynamic>>> _messagesCache = {};
  final Map<String, List<Map<String, dynamic>>> _recentChatsCache = {};
  
  // Cache expiration times (in seconds)
  final int _messagesCacheExpiry = 60; // 1 minute
  final int _recentChatsCacheExpiry = 120; // 2 minutes
  
  // Cache timestamps
  final Map<String, DateTime> _messagesCacheTimestamps = {};
  DateTime? _recentChatsCacheTimestamp;
  
  // Statistics for monitoring
  final RxInt cacheHits = 0.obs;
  final RxInt cacheMisses = 0.obs;
  
  // Constructor
  ChatCacheService() : _recentChatsCacheTimestamp = null;
  
  // Initialize the service
  Future<ChatCacheService> init() async {
    try {
      // Initialize encryption service reference if available
      if (Get.isRegistered<EncryptionService>()) {
        _encryptionService = Get.find<EncryptionService>();
      }
      
      // Load cached recent chats from storage
      await _loadRecentChatsFromStorage();
      
      return this;
    } catch (e) {
      debugPrint('Error initializing ChatCacheService: $e');
      return this;
    }
  }
  
  // Load recent chats from persistent storage on init
  Future<void> _loadRecentChatsFromStorage() async {
    try {
      final cachedData = _storageService.getString('recent_chats_cache');
      if (cachedData != null) {
        final decoded = json.decode(cachedData);
        final List<dynamic> chats = decoded['data'];
        
        if (chats.isNotEmpty) {
          final List<Map<String, dynamic>> typedChats = 
              chats.map((chat) => Map<String, dynamic>.from(chat)).toList();
          
          _recentChatsCache['global'] = typedChats;
          
          // Set the timestamp from storage
          final timestamp = DateTime.parse(decoded['timestamp']);
          _recentChatsCacheTimestamp = timestamp;
          
          debugPrint('Loaded ${typedChats.length} chats from persistent cache');
        }
      }
    } catch (e) {
      debugPrint('Error loading cached chats from storage: $e');
    }
  }
  
  // Check if cache is still valid
  bool _isCacheValid(String cacheKey, CacheType type) {
    final now = DateTime.now();
    
    if (type == CacheType.messages) {
      final timestamp = _messagesCacheTimestamps[cacheKey];
      if (timestamp == null) return false;
      
      return now.difference(timestamp).inSeconds < _messagesCacheExpiry;
    } else if (type == CacheType.recentChats) {
      if (_recentChatsCacheTimestamp == null) return false;
      
      return now.difference(_recentChatsCacheTimestamp!).inSeconds < _recentChatsCacheExpiry;
    }
    
    return false;
  }
  
  // Get messages from cache
  List<Map<String, dynamic>>? getCachedMessages(String chatId) {
    if (_isCacheValid(chatId, CacheType.messages) && _messagesCache.containsKey(chatId)) {
      cacheHits.value++;
      return _messagesCache[chatId];
    }
    
    cacheMisses.value++;
    return null;
  }
  
  // Store messages in cache
  Future<void> cacheMessages(String chatId, List<Map<String, dynamic>> messages) async {
    _messagesCache[chatId] = messages;
    _messagesCacheTimestamps[chatId] = DateTime.now();
    
    // Optionally persist to storage for important chats
    // This is an optimization to avoid excessive storage writes
    if (messages.length > 10) {
      await _persistMessagesToStorage(chatId, messages);
    }
  }
  
  // Get recent chats from cache
  List<Map<String, dynamic>>? getCachedRecentChats() {
    if (_isCacheValid('global', CacheType.recentChats) && _recentChatsCache.containsKey('global')) {
      cacheHits.value++;
      return _recentChatsCache['global'];
    }
    
    cacheMisses.value++;
    return null;
  }
  
  // Store recent chats in cache
  Future<void> cacheRecentChats(List<Map<String, dynamic>> chats) async {
    _recentChatsCache['global'] = chats;
    
    // Persist to storage
    await _persistRecentChatsToStorage(chats);
  }
  
  // Persist messages to storage (selectively)
  Future<void> _persistMessagesToStorage(String chatId, List<Map<String, dynamic>> messages) async {
    try {
      // Store only the last 50 messages to conserve space
      final messagesToStore = messages.length > 50 
          ? messages.sublist(messages.length - 50) 
          : messages;
      
      final Map<String, dynamic> cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': messagesToStore
      };
      
      await _storageService.saveString(
        'messages_cache_$chatId', 
        json.encode(cacheData)
      );
      
      debugPrint('Persisted ${messagesToStore.length} messages for chat $chatId');
    } catch (e) {
      debugPrint('Error persisting messages to storage: $e');
    }
  }
  
  // Persist recent chats to storage
  Future<void> _persistRecentChatsToStorage(List<Map<String, dynamic>> chats) async {
    try {
      final Map<String, dynamic> cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': chats
      };
      
      await _storageService.saveString(
        'recent_chats_cache', 
        json.encode(cacheData)
      );
      
      debugPrint('Persisted ${chats.length} recent chats to storage');
    } catch (e) {
      debugPrint('Error persisting chats to storage: $e');
    }
  }
  
  // Invalidate message cache for a specific chat
  void invalidateMessageCache(String chatId) {
    _messagesCache.remove(chatId);
    _messagesCacheTimestamps.remove(chatId);
    debugPrint('Invalidated message cache for chat $chatId');
  }
  
  // Invalidate recent chats cache
  void invalidateRecentChatsCache() {
    _recentChatsCache.clear();
    debugPrint('Invalidated recent chats cache');
  }
  
  // Preload messages for a chat from storage
  Future<List<Map<String, dynamic>>?> preloadMessagesFromStorage(String chatId) async {
    try {
      final cachedData = _storageService.getString('messages_cache_$chatId');
      if (cachedData != null) {
        final decoded = json.decode(cachedData);
        final List<dynamic> messages = decoded['data'];
        
        if (messages.isNotEmpty) {
          final List<Map<String, dynamic>> typedMessages = 
              messages.map((msg) => Map<String, dynamic>.from(msg)).toList();
          
          // Don't update the cache timestamp so it will still be refreshed from network
          // but the UI can show something while waiting
          _messagesCache[chatId] = typedMessages;
          
          debugPrint('Preloaded ${typedMessages.length} messages for chat $chatId from storage');
          return typedMessages;
        }
      }
    } catch (e) {
      debugPrint('Error preloading messages from storage: $e');
    }
    
    return null;
  }
  
  // Clear all caches (for logout or memory pressure)
  void clearAllCaches() {
    _messagesCache.clear();
    _messagesCacheTimestamps.clear();
    _recentChatsCache.clear();
    debugPrint('Cleared all chat caches');
  }
}

// Cache types for type safety
enum CacheType {
  messages,
  recentChats
} 
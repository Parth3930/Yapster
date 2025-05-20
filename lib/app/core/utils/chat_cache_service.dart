import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/modules/chat/models/chat_conversation_model.dart';
import 'package:yapster/app/modules/chat/models/chat_message_model.dart';

/// Service for caching chat conversations and messages to improve user experience
class ChatCacheService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();
  static const String _conversationsKey = 'cached_conversations';
  static const String _messagesPrefix = 'chat_messages_';

  /// Initialize the service
  Future<void> init() async {
    debugPrint('ChatCacheService initialized');
  }

  /// Cache a list of conversations
  void cacheConversations(List<ChatConversation> conversations) {
    try {
      final List<Map<String, dynamic>> conversationMaps =
          conversations.map((conv) => conv.toJson()).toList();
      _storage.saveString(_conversationsKey, jsonEncode(conversationMaps));
      debugPrint('Cached ${conversations.length} conversations');
    } catch (e) {
      debugPrint('Error caching conversations: $e');
    }
  }

  /// Get cached conversations
  List<ChatConversation> getCachedConversations() {
    try {
      final cachedData = _storage.getString(_conversationsKey);
      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        return decodedData
            .map(
              (item) =>
                  ChatConversation.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error reading cached conversations: $e');
    }
    return [];
  }

  /// Cache messages for a specific chat
  void cacheMessages(String conversationId, List<ChatMessage> messages) {
    try {
      final List<Map<String, dynamic>> messageMaps =
          messages.map((msg) => msg.toJson()).toList();
      _storage.saveString(
        '$_messagesPrefix$conversationId',
        jsonEncode(messageMaps),
      );
      debugPrint('Cached ${messages.length} messages for chat $conversationId');
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  /// Get cached messages for a specific chat
  List<ChatMessage> getCachedMessages(String conversationId) {
    try {
      final cachedData = _storage.getString('$_messagesPrefix$conversationId');
      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        return decodedData
            .map(
              (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error reading cached messages: $e');
    }
    return [];
  }

  /// Clear all cached data for a specific chat
  void clearChatCache(String conversationId) {
    _storage.remove('$_messagesPrefix$conversationId');
    debugPrint('Cleared cache for chat $conversationId');
  }

  /// Clear all cached data (for logout or similar scenarios)
  void clearAllChatCache() {
    _storage.remove(_conversationsKey);
    // Since StorageService doesn't support listing keys, we can't easily clear
    // all message caches. In a production app, we would need to maintain a list
    // of active conversation IDs to clear their caches.
    debugPrint('Cleared conversations cache');
  }

  /// Get chat data from cache if available, or fetch from network otherwise
  Future<List<ChatMessage>> getOrFetchMessages(
    String conversationId,
    Future<List<ChatMessage>> Function() fetchFromNetwork,
  ) async {
    // Try cache first
    final cached = getCachedMessages(conversationId);

    if (cached.isNotEmpty) {
      debugPrint(
        'Using ${cached.length} cached messages for chat $conversationId',
      );

      // Fetch from network in background
      fetchFromNetwork().then((fetchedMessages) {
        if (fetchedMessages.isNotEmpty) {
          cacheMessages(conversationId, fetchedMessages);
        }
      });

      return cached;
    }

    // No cache available, fetch from network and then cache
    try {
      final messages = await fetchFromNetwork();
      if (messages.isNotEmpty) {
        cacheMessages(conversationId, messages);
      }
      return messages;
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// Update cache with read status changes
  void updateMessageReadStatus(
    String conversationId,
    String messageId,
    bool isRead,
  ) {
    try {
      final messages = getCachedMessages(conversationId);
      if (messages.isNotEmpty) {
        final index = messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          final updatedMessage = messages[index].copyWith(isRead: isRead);
          messages[index] = updatedMessage;
          cacheMessages(conversationId, messages);
        }
      }
    } catch (e) {
      debugPrint('Error updating message read status in cache: $e');
    }
  }
}

// Cache types for type safety
enum CacheType { messages, recentChats }

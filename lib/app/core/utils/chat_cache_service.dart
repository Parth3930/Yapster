import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/storage_service.dart';

/// Service for caching chat conversations and messages to improve user experience
class ChatCacheService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();
  static const String _conversationsKey = 'cached_conversations';
  static const String _messagesPrefix = 'chat_messages_';

  /// Initialize the service
  Future<void> init() async {
    debugPrint('ChatCacheService initialized');
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
}

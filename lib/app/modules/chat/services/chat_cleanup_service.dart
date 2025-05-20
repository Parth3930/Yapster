import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/modules/chat/models/chat_conversation_model.dart';
import 'package:yapster/app/modules/chat/models/chat_message_model.dart';
import 'dart:async';

/// Service responsible for message cleanup and background maintenance tasks
class ChatCleanupService extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final ChatCacheService _chatCacheService = Get.find<ChatCacheService>();
  final StorageService _storageService = Get.find<StorageService>();

  Timer? _messageCleanupTimer;
  Timer? _tempFilesCleanupTimer;

  // Lifecycle tracking
  DateTime? _lastActiveTime;

  /// Initialize the service
  void initialize() {
    _lastActiveTime = DateTime.now();
    startMessageCleanupTimer();
    startTempFilesCleanupTimer();
  }

  /// Start timer for regular message cleanup
  void startMessageCleanupTimer() {
    // Check and clean expired messages every hour
    _messageCleanupTimer?.cancel();
    _messageCleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      cleanupExpiredMessages();
    });
  }

  /// Start timer for temporary files cleanup
  void startTempFilesCleanupTimer() {
    // Check and clean temporary files every 12 hours
    _tempFilesCleanupTimer?.cancel();
    _tempFilesCleanupTimer = Timer.periodic(const Duration(hours: 12), (_) {
      cleanupTemporaryFiles();
    });
  }

  /// Stop all cleanup timers
  void stopCleanupTimers() {
    _messageCleanupTimer?.cancel();
    _tempFilesCleanupTimer?.cancel();
  }

  /// Clean up expired messages
  Future<void> cleanupExpiredMessages() async {
    try {
      final now = DateTime.now().toIso8601String();

      // Get the current user ID
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) return;

      // Find message IDs that are older than 30 days and mark as expired
      await _supabaseService.client.rpc(
        'mark_old_messages_expired',
        params: {'days_old': 30, 'user_id': userId},
      );

      debugPrint('Marked expired messages');
    } catch (e) {
      debugPrint('Error cleaning up expired messages: $e');
    }
  }

  /// Clean up temporary files
  Future<void> cleanupTemporaryFiles() async {
    try {
      // Check local storage for temporary files
      final tempFilesList = _storageService.getString('temp_chat_files');

      if (tempFilesList != null) {
        // Parse the JSON string into a list
        final fileList =
            tempFilesList.split(',').where((file) => file.isNotEmpty).toList();

        // Process each file
        for (final filePath in fileList) {
          try {
            // Extract file details from path
            final parts = filePath.split('/');
            if (parts.length >= 3) {
              final bucketName = parts[0];
              final remainingPath = parts.sublist(1).join('/');

              // Delete the file from storage
              await _supabaseService.client.storage.from(bucketName).remove([
                remainingPath,
              ]);

              debugPrint('Deleted temporary file: $filePath');
            }
          } catch (fileError) {
            debugPrint('Error deleting temporary file $filePath: $fileError');
          }
        }

        // Clear the list
        _storageService.remove('temp_chat_files');
      }
    } catch (e) {
      debugPrint('Error cleaning up temporary files: $e');
    }
  }

  /// Record app lifecycle changes
  void recordAppActivity() {
    _lastActiveTime = DateTime.now();
  }

  /// Check if the app has been inactive for a while
  bool hasBeenInactiveFor(Duration duration) {
    if (_lastActiveTime == null) return false;

    final now = DateTime.now();
    return now.difference(_lastActiveTime!) > duration;
  }

  /// Mark a file as temporary (to be cleaned up later)
  void markFileAsTemporary(String filePath) {
    try {
      // Get existing list
      final existingList = _storageService.getString('temp_chat_files') ?? '';

      // Add new file
      final updatedList =
          existingList.isEmpty ? filePath : '$existingList,$filePath';

      // Save updated list
      _storageService.saveString('temp_chat_files', updatedList);
    } catch (e) {
      debugPrint('Error marking file as temporary: $e');
    }
  }

  /// Delete messages that are older than 24 hours
  Future<void> _deleteExpiredMessages() async {
    try {
      final now = DateTime.now().toIso8601String();

      // Delete messages where expires_at is in the past
      await _supabaseService.client
          .from('messages')
          .delete()
          .lt('expires_at', now);

      debugPrint('Deleted expired messages');

      // Clear expired messages from cache
      _cleanExpiredMessagesFromCache();
    } catch (e) {
      debugPrint('Error deleting expired messages: $e');
    }
  }

  /// Clean expired messages from local cache
  void _cleanExpiredMessagesFromCache() {
    try {
      final now = DateTime.now();

      // Get all cached chats
      final List<ChatConversation> chats =
          _chatCacheService.getCachedConversations();
      if (chats.isEmpty) return;

      // For each chat, clean up expired messages in cache
      for (final chat in chats) {
        final chatId = chat.id;
        if (chatId.isEmpty) continue;

        final List<ChatMessage> messages = _chatCacheService.getCachedMessages(
          chatId,
        );
        if (messages.isEmpty) continue;

        // Filter out expired messages
        final validMessages =
            messages.where((msg) {
              // Check if message has metadata with expiration date
              final expiresAtStr = msg.metadata?['expires_at'] as String?;
              if (expiresAtStr == null) return true; // Keep if no expiration

              try {
                final expiresAt = DateTime.parse(expiresAtStr);
                return now.isBefore(expiresAt); // Keep if not expired
              } catch (e) {
                return true; // Keep if date parsing fails
              }
            }).toList();

        // If we filtered out any messages, update the cache
        if (validMessages.length != messages.length) {
          _chatCacheService.cacheMessages(chatId, validMessages);
          debugPrint(
            'Removed ${messages.length - validMessages.length} expired messages from cache for chat $chatId',
          );
        }
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }

  /// Load user preferences from local storage
  Future<bool> loadUserPreferences() async {
    try {
      final dismissed =
          _storageService.getBool('dismissed_expiry_banner') ?? false;
      return dismissed;
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      return false;
    }
  }

  /// Dismiss the expiry banner and save preference
  Future<void> dismissExpiryBanner() async {
    try {
      await _storageService.saveBool('dismissed_expiry_banner', true);
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }

  /// Check if the chat cache is fresh enough
  bool isCacheFresh(String chatId, {int maxAgeSeconds = 120}) {
    final List<ChatMessage> cachedMessages = _chatCacheService
        .getCachedMessages(chatId);
    if (cachedMessages.isNotEmpty) {
      try {
        final now = DateTime.now();
        final lastMessage = cachedMessages.last;
        final createdAt = lastMessage.timestamp;
        final age = now.difference(createdAt).inSeconds;
        return age <
            maxAgeSeconds; // Fresh if less than maxAgeSeconds (default 2min)
      } catch (e) {
        debugPrint('Error checking cache freshness: $e');
      }
    }
    return false;
  }

  /// Update last active time
  void updateLastActiveTime() {
    _lastActiveTime = DateTime.now();
  }

  /// Get the time since last active
  Duration? getTimeSinceLastActive() {
    if (_lastActiveTime == null) return null;
    return DateTime.now().difference(_lastActiveTime!);
  }

  @override
  void onClose() {
    stopCleanupTimers();
    super.onClose();
  }
}

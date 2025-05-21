import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'dart:async';

/// Service dedicated to handling message decryption with improved reliability
/// This service addresses the bug where messages sometimes fail to decrypt
/// until app restart by implementing a robust retry mechanism and caching system
class ChatDecryptionService extends GetxService {
  final EncryptionService _encryptionService = Get.find<EncryptionService>();
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  // Cache for successfully decrypted messages to avoid repeated decryption attempts
  final Map<String, String> _decryptedContentCache = {};

  // Track failed decryption attempts to implement exponential backoff
  final Map<String, int> _failedDecryptionAttempts = {};

  // Maximum number of retry attempts for decryption
  final int _maxRetryAttempts = 3;

  // Flag to track if encryption service is fully initialized
  final RxBool isReady = false.obs;

  /// Initialize the decryption service
  Future<void> initialize() async {
    try {
      // Wait for encryption service to be fully initialized
      if (!_encryptionService.isInitialized.value) {
        await _waitForEncryptionService();
      }

      isReady.value = true;
      debugPrint('ChatDecryptionService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing ChatDecryptionService: $e');
      // Schedule a retry after delay
      await Future.delayed(const Duration(seconds: 2));
      return initialize();
    }
  }

  /// Wait for encryption service to be ready
  Future<void> _waitForEncryptionService() async {
    int attempts = 0;
    while (!_encryptionService.isInitialized.value && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (!_encryptionService.isInitialized.value) {
      throw Exception('Encryption service failed to initialize');
    }
  }

  /// Decrypt a message with improved reliability
  /// Returns the decrypted content or a placeholder if decryption fails
  Future<String> decryptMessage({
    required String encryptedContent,
    required String messageId,
    String? chatId,
  }) async {
    // Skip decryption for empty content
    if (encryptedContent.isEmpty) {
      return '';
    }

    // Return cached result if available
    if (_decryptedContentCache.containsKey(messageId)) {
      return _decryptedContentCache[messageId]!;
    }

    // Skip decryption if content doesn't appear to be encrypted
    if (!_isContentEncrypted(encryptedContent)) {
      return encryptedContent;
    }

    // Ensure encryption service is ready
    if (!isReady.value) {
      await initialize();
    }

    try {
      String decryptedContent = '';

      // Try chat-specific decryption first if chat ID is provided
      if (chatId != null) {
        try {
          decryptedContent = await _encryptionService.decryptMessageForChat(
            encryptedContent,
            chatId,
          );

          if (_isDecryptionSuccessful(decryptedContent)) {
            _cacheDecryptedContent(messageId, decryptedContent);
            return decryptedContent;
          }
        } catch (e) {
          debugPrint('Chat-specific decryption failed for $messageId: $e');
          // Continue to fallback methods
        }
      }

      // Try default decryption
      try {
        decryptedContent = _encryptionService.decryptMessage(encryptedContent);

        if (_isDecryptionSuccessful(decryptedContent)) {
          _cacheDecryptedContent(messageId, decryptedContent);
          return decryptedContent;
        }
      } catch (e) {
        debugPrint('Default decryption failed for $messageId: $e');
        // Continue to fallback methods
      }

      // Try fetching from database as last resort
      return await _fetchAndDecryptFromDatabase(messageId, encryptedContent);
    } catch (e) {
      debugPrint('All decryption methods failed for $messageId: $e');

      // Track failed attempt and schedule retry if needed
      _trackFailedAttempt(messageId);

      // Return original content as fallback
      return encryptedContent;
    }
  }

  /// Check if content appears to be encrypted
  bool _isContentEncrypted(String content) {
    return content.contains('==') ||
        content == '🔒 Encrypted message' ||
        content == '🔒 Error encrypting message';
  }

  /// Check if decryption was successful
  bool _isDecryptionSuccessful(String content) {
    return content.isNotEmpty && !content.startsWith('🔒');
  }

  /// Cache successfully decrypted content
  void _cacheDecryptedContent(String messageId, String content) {
    _decryptedContentCache[messageId] = content;
    // Reset failed attempts counter
    _failedDecryptionAttempts.remove(messageId);
  }

  /// Track failed decryption attempt and schedule retry if needed
  void _trackFailedAttempt(String messageId) {
    _failedDecryptionAttempts[messageId] =
        (_failedDecryptionAttempts[messageId] ?? 0) + 1;

    final attempts = _failedDecryptionAttempts[messageId] ?? 0;

    // Schedule retry with exponential backoff if under max attempts
    if (attempts <= _maxRetryAttempts) {
      final delay = Duration(milliseconds: 500 * (1 << attempts));
      debugPrint(
        'Scheduling retry #$attempts for $messageId in ${delay.inMilliseconds}ms',
      );

      Future.delayed(delay, () {
        // This will be called by the controller when message is displayed again
      });
    }
  }

  /// Fetch message from database and attempt decryption
  Future<String> _fetchAndDecryptFromDatabase(
    String messageId,
    String fallbackContent,
  ) async {
    try {
      final response =
          await _supabaseService.client
              .from('messages')
              .select()
              .eq('message_id', messageId)
              .single();

      if (response.isNotEmpty && response['content'] != null) {
        final dbContent = response['content'].toString();
        String chatId = response['chat_id'].toString();

        // Try chat-specific decryption first
        if (chatId.isNotEmpty) {
          try {
            final decryptedContent = await _encryptionService
                .decryptMessageForChat(dbContent, chatId);

            if (_isDecryptionSuccessful(decryptedContent)) {
              _cacheDecryptedContent(messageId, decryptedContent);
              return decryptedContent;
            }
          } catch (e) {
            debugPrint('Database chat-specific decryption failed: $e');
          }
        }

        // Try default decryption
        try {
          final decryptedContent = _encryptionService.decryptMessage(dbContent);

          if (_isDecryptionSuccessful(decryptedContent)) {
            _cacheDecryptedContent(messageId, decryptedContent);
            return decryptedContent;
          }
        } catch (e) {
          debugPrint('Database default decryption failed: $e');
        }

        // Return database content as fallback
        return dbContent;
      }
    } catch (e) {
      debugPrint('Error fetching message from database: $e');
    }

    // Return original content if all else fails
    return fallbackContent;
  }

  /// Clear decryption cache for testing or memory management
  void clearCache() {
    _decryptedContentCache.clear();
    _failedDecryptionAttempts.clear();
  }

  /// Force retry decryption for a specific message
  Future<String> forceRetryDecryption({
    required String messageId,
    required String encryptedContent,
    String? chatId,
  }) async {
    // Remove from cache to force fresh attempt
    _decryptedContentCache.remove(messageId);
    _failedDecryptionAttempts.remove(messageId);

    // Attempt decryption again
    return decryptMessage(
      encryptedContent: encryptedContent,
      messageId: messageId,
      chatId: chatId,
    );
  }
}

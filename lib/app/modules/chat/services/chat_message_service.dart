import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';

/// Service for handling chat message operations with encryption support
/// Optimized to handle message encryption/decryption efficiently
class ChatMessageService extends GetxService {
  // Core services and dependencies
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  late final EncryptionService _encryptionService;
  
  // Message tracking and UI state
  final RxSet<String> _processedMessageIds = <String>{}.obs;
  final RxSet<String> _deletedMessageIds = <String>{}.obs;
  
  // Observable collections
  RxList<MessageModel>? _messages;
  RxList<MessageModel> get messages => _messages ??= RxList<MessageModel>();
  
  RxList<Map<String, dynamic>>? _recentChats;
  RxList<Map<String, dynamic>> get recentChats => _recentChats ??= RxList<Map<String, dynamic>>();
  
  RxMap<String, double>? _uploadProgress;
  RxMap<String, double> get uploadProgress => _uploadProgress ??= RxMap<String, double>();
  
  // Real-time subscription
  StreamSubscription? _messageSubscription;
  
  // Performance optimizations
  final Map<String, String> _decryptionCache = {};
  final RxBool isInitialized = false.obs;
  
  // Main controller reference
  ChatController get controller => Get.find<ChatController>();

  /// Initialize the service with observable lists and set up dependencies
  Future<void> initialize({
    RxList<MessageModel>? messagesList,
    RxList<Map<String, dynamic>>? chatsList,
    RxMap<String, double>? uploadProgress,
  }) async {
    // Initialize observable collections if provided
    if (messagesList != null) _messages = messagesList;
    if (chatsList != null) _recentChats = chatsList;
    if (uploadProgress != null) _uploadProgress = uploadProgress;
    
    // Clear tracking sets
    _processedMessageIds.clear();
    _deletedMessageIds.clear();
    _decryptionCache.clear();
    
    // Set up encryption service
    try {
      _encryptionService = Get.find<EncryptionService>();
      if (!_encryptionService.isInitialized.value) {
        await _encryptionService.initialize();
      }
    } catch (e) {
      debugPrint('Error initializing encryption service: $e');
      // Create and initialize if not found
      _encryptionService = Get.put(EncryptionService());
      await _encryptionService.initialize();
    }
    
    isInitialized.value = true;
    debugPrint('ChatMessageService initialized successfully');
  }

  /// Load messages for a chat with encryption support
  Future<void> loadMessages(String chatId) async {
    if (!isInitialized.value) {
      debugPrint('ChatMessageService not initialized, initializing now...');
      await initialize(
        messagesList: messages,
        chatsList: recentChats,
        uploadProgress: uploadProgress,
      );
    }
    
    final supabase = _supabaseService.client;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    debugPrint('Loading messages for chat: $chatId');
    try {
      // Cancel any previous real-time message subscription
      await _messageSubscription?.cancel();
      _messageSubscription = null;

      // Ensure encryption service is ready
      if (!_encryptionService.isInitialized.value) {
        await _encryptionService.initialize();
        debugPrint('Encryption service initialized for message loading');
      }

      // 1. Fetch old (non-expired) messages
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: true);

      // Clear the local message list before assigning new messages
      messages.clear();
      if (response.isNotEmpty) {
        debugPrint('Loaded ${response.length} messages from database');
        
        // Process and decrypt messages
        final List<MessageModel> loadedMessages = [];
        
        for (var msg in response) {
          // Check if message contains encrypted content
          final String messageId = msg['message_id']?.toString() ?? '';
          if (msg['content'] != null) {
            // Check if we have this message in cache first
            final String cacheKey = '$chatId:$messageId';
            if (_decryptionCache.containsKey(cacheKey)) {
              // Use cached decrypted content
              msg['content'] = _decryptionCache[cacheKey];
              msg['is_encrypted'] = false;
              debugPrint('Used cached decryption for message: $messageId');
            } else {
              try {
                // Attempt to decrypt the message content
                final decryptedContent = await _encryptionService.decryptMessageForChat(
                  msg['content'].toString(),
                  chatId,
                );
                
                // Cache successfully decrypted content
                _decryptionCache[cacheKey] = decryptedContent;
                
                // Replace encrypted content with decrypted content
                msg['content'] = decryptedContent;
                msg['is_encrypted'] = false;
                debugPrint('Successfully decrypted message: $messageId');
              } catch (e) {
                debugPrint('Could not decrypt message $messageId: $e');
                // If decryption fails, leave content as is (might be plaintext or old format)
              }
            }
          }
          
          // Create message model with decrypted content
          loadedMessages.add(MessageModel.fromJson(msg));
        }

        // Directly assign List<MessageModel> to observable list
        messages.assignAll(loadedMessages);
      }

      // 2. Set up real-time subscription for new messages
      _setupRealtimeSubscription(chatId);
      
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }
  
  /// Set up real-time subscription for message updates
  void _setupRealtimeSubscription(String chatId) {
    final supabase = _supabaseService.client;
    
    _messageSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['message_id'])
        .eq('chat_id', chatId)
        .listen((List<Map<String, dynamic>> data) async {
          if (!isInitialized.value) return;
          
          // Ensure encryption service is ready
          if (!_encryptionService.isInitialized.value) {
            await _encryptionService.initialize();
          }

          for (var msgData in data) {
            // Process real-time message with encryption support
            final String messageId = msgData['message_id']?.toString() ?? '';
            
            // Skip deleted messages
            if (_deletedMessageIds.contains(messageId)) continue;
            
            // Skip already processed messages to avoid duplicates
            if (_processedMessageIds.contains(messageId)) continue;
            
            if (msgData['content'] != null) {
              // Check if we have this message in cache first
              final String cacheKey = '$chatId:$messageId';
              if (_decryptionCache.containsKey(cacheKey)) {
                // Use cached decrypted content
                msgData['content'] = _decryptionCache[cacheKey];
                msgData['is_encrypted'] = false;
                debugPrint('Used cached decryption for real-time message: $messageId');
              } else {
                try {
                  // Attempt to decrypt the message content
                  final decryptedContent = await _encryptionService.decryptMessageForChat(
                    msgData['content'].toString(),
                    chatId,
                  );
                  
                  // Cache successfully decrypted content
                  _decryptionCache[cacheKey] = decryptedContent;
                  
                  // Replace encrypted content with decrypted content
                  msgData['content'] = decryptedContent;
                  msgData['is_encrypted'] = false;
                  debugPrint('Successfully decrypted real-time message: $messageId');
                } catch (e) {
                  debugPrint('Could not decrypt real-time message $messageId: $e');
                  // If decryption fails, leave content as is (might be plaintext or old format)
                }
              }
            }
            
            // Mark this message as processed
            _processedMessageIds.add(messageId);
            
            // Create message from JSON
            final MessageModel message = MessageModel.fromJson(msgData);
            
            // Check if message already exists in the list
            if (!messages.any((m) => m.messageId == message.messageId)) {
              // Add to messages list
              messages.add(message);
              // Add to animation list in controller
              controller.messagesToAnimate.add(message.messageId);
              messages.refresh();
            }
          }
        });
  }
  
  /// Send a text message with encryption
  Future<void> sendMessage({
    required String chatId,
    required String recipientId,
    required String content,
    required String messageType,
    required DateTime expiresAt,
  }) async {
    if (!isInitialized.value) {
      await initialize(
        messagesList: messages,
        chatsList: recentChats,
        uploadProgress: uploadProgress,
      );
    }

    // Get current user ID safely
    final String? currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) {
      debugPrint('Cannot send message: Current user ID is null');
      return;
    }

    final String plainMessageContent = content;
    
    // Create a temporary message for optimistic UI update with a temporary ID
    // This will be replaced by the actual message from the database
    final tempMessage = MessageModel(
      messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: currentUserId,
      content: plainMessageContent,
      messageType: messageType,
      recipientId: recipientId,
      expiresAt: expiresAt,
      isRead: false,
      createdAt: DateTime.now().toUtc(),
    );
    
    // Add the temporary message to the list immediately
    messages.add(tempMessage);
    controller.messagesToAnimate.add(tempMessage.messageId);
    messages.refresh();
    
    try {
      // Encrypt the message content
      final encryptedContent = await _encryptionService.encryptMessageForChat(
        plainMessageContent,
        chatId,
      );
      
      // Prepare the message data (don't include message_id to let the DB generate it)
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedContent,
        'message_type': messageType,
        'recipient_id': recipientId,
        'expires_at': expiresAt.toIso8601String(),
        'is_read': false,
      };
      
      // Insert the message into the database
      final response = await _supabaseService.client
        .from('messages')
        .insert(messageData)
        .select();
        
      if (response.isEmpty) {
        debugPrint('Error: Empty response when sending message');
        // Keep the plaintext version in the UI
        messages.refresh();
        return;
      }

      debugPrint('Message sent to database: ${response.first['message_id']}');

      // Get the real message from database with server-generated ID
      final sentMessage = MessageModel.fromJson(response.first);
      
      // Replace the temporary message with the real one from database
      final index = messages.indexWhere((m) => m.messageId == tempMessage.messageId);
      if (index != -1) {
        // Create a copy of the sent message with the decrypted content
        final updatedMessage = sentMessage.copyWith(
          content: plainMessageContent,
          isEncrypted: false,
        );
        
        messages[index] = updatedMessage;
        controller.messagesToAnimate.remove(tempMessage.messageId);
        controller.messagesToAnimate.add(sentMessage.messageId);
      }
      
      // Force update both UI lists
      messages.refresh();
      controller.messages.refresh();
      
      // Also refresh recent chats list to show latest message
      await _updateRecentChat(chatId, plainMessageContent);
      
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Keep the plaintext version in the UI for user experience
    }
  }
  
  /// Update recent chat with the latest message
  Future<void> _updateRecentChat(String chatId, String lastMessageText) async {
    try {
      // Find the chat in recent chats
      final chatIndex = recentChats.indexWhere((chat) => chat['chat_id'] == chatId);
      if (chatIndex != -1) {
        // Update the last message and timestamp
        recentChats[chatIndex]['last_message'] = lastMessageText;
        recentChats[chatIndex]['last_message_time'] = DateTime.now().toUtc().toIso8601String();
        
        // Move this chat to the top of the list
        final chat = recentChats.removeAt(chatIndex);
        recentChats.insert(0, chat);
        recentChats.refresh();
      }
    } catch (e) {
      debugPrint('Error updating recent chat: $e');
    }
  }
  
  /// Upload and send an audio message
  Future<void> uploadAndSendAudio({
    required String chatId,
    required String recipientId,
    required File audioFile,
    required DateTime expiresAt,
  }) async {
    if (!isInitialized.value) {
      await initialize(
        messagesList: messages,
        chatsList: recentChats,
        uploadProgress: uploadProgress,
      );
    }

    // Get current user ID safely
    final String? currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) {
      debugPrint('Cannot send audio: Current user ID is null');
      return;
    }

    // Generate a temporary ID for optimistic UI update
    final String tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final String localAudioPath = audioFile.path;
    
    try {
      // Create a temporary message for optimistic UI
      final tempMessage = MessageModel(
        messageId: tempMessageId,
        chatId: chatId,
        senderId: currentUserId,
        content: localAudioPath, // Local path as content for now
        messageType: 'audio',
        recipientId: recipientId,
        expiresAt: expiresAt,
        isRead: false,
        createdAt: DateTime.now().toUtc(),
      );
      
      // Add temp message to UI
      messages.add(tempMessage);
      controller.messagesToAnimate.add(tempMessageId);
      messages.refresh();
      
      // Set initial upload progress
      uploadProgress[tempMessageId] = 0.0;
      
      // Generate a unique filename for the audio
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(localAudioPath)}';
      final storageRef = '$chatId/$fileName';
      
      // Read the file as bytes
      final fileBytes = await audioFile.readAsBytes();
      
      // Upload the file to Supabase Storage
      await _supabaseService.client.storage
        .from('chat-media')
        .uploadBinary(
          storageRef,
          fileBytes,
          fileOptions: FileOptions(
            contentType: 'audio/m4a',
          ),
        );
      
      // Get the public URL for the uploaded audio
      final audioUrl = _supabaseService.client.storage
        .from('chat-media')
        .getPublicUrl(storageRef);
      
      // Set upload as complete
      uploadProgress[tempMessageId] = 1.0;
      
      // Encrypt the audio URL
      final encryptedUrl = await _encryptionService.encryptMessageForChat(
        audioUrl,
        chatId,
      );
      
      // Prepare the message data for database (let DB generate the message_id)
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedUrl,
        'message_type': 'audio',
        'recipient_id': recipientId,
        'expires_at': expiresAt.toIso8601String(),
        'is_read': false,
      };
      
      // Insert the message into the database
      final response = await _supabaseService.client
        .from('messages')
        .insert(messageData)
        .select();
        
      if (response.isEmpty) {
        debugPrint('Error: Empty response when sending audio message');
        return;
      }

      // Get the real message from database with server-generated ID
      final sentMessage = MessageModel.fromJson(response.first);
      
      // Replace the temporary message with the real one from database
      final index = messages.indexWhere((m) => m.messageId == tempMessageId);
      if (index != -1) {
        // Create a copy with the decrypted URL
        final updatedMessage = sentMessage.copyWith(
          content: audioUrl, // Store the original URL for display
          isEncrypted: false,
        );
        
        messages[index] = updatedMessage;
        controller.messagesToAnimate.remove(tempMessageId);
        controller.messagesToAnimate.add(sentMessage.messageId);
      }
      
      // Force update UI lists
      messages.refresh();
      controller.messages.refresh();
      
      // Update recent chats
      await _updateRecentChat(chatId, '🎤 Audio');
      
    } catch (e) {
      debugPrint('Error uploading and sending audio: $e');
      // Update progress to show error
      uploadProgress[tempMessageId] = -1.0;
      uploadProgress.refresh();
    }
  }

  /// Upload and send an image message
  Future<void> uploadAndSendImage({
    required String chatId,
    required String recipientId,
    required XFile image,
    required DateTime expiresAt,
  }) async {
    if (!isInitialized.value) {
      await initialize(
        messagesList: messages,
        chatsList: recentChats,
        uploadProgress: uploadProgress,
      );
    }

    // Get current user ID safely
    final String? currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId == null) {
      debugPrint('Cannot send image: Current user ID is null');
      return;
    }

    // Generate a temporary ID for optimistic UI update
    final String tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final String localImagePath = image.path;
    
    try {
      // Create a temporary message with local image path
      final MessageModel tempMessage = MessageModel(
        messageId: tempMessageId,
        chatId: chatId,
        senderId: currentUserId,
        content: localImagePath, // Local path as content for now
        messageType: 'image',
        recipientId: recipientId,
        expiresAt: expiresAt,
        isRead: false,
        createdAt: DateTime.now().toUtc(),
      );
      
      // Add temp message to UI
      messages.add(tempMessage);
      controller.messagesToAnimate.add(tempMessageId);
      messages.refresh();
      
      // Set initial upload progress
      uploadProgress[tempMessageId] = 0.0;
      
      // Generate a unique filename for the image
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(localImagePath)}';
      final storageRef = '$chatId/$fileName';
      
      // Read the file as bytes
      final fileBytes = await File(localImagePath).readAsBytes();
      
      // Upload the file to Supabase Storage
      await _supabaseService.client.storage
        .from('chat-media')
        .uploadBinary(
          storageRef,
          fileBytes,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
          ),
        );
      
      // Get the public URL for the uploaded image
      final imageUrl = _supabaseService.client.storage
        .from('chat-media')
        .getPublicUrl(storageRef);
      
      // Set upload as complete
      uploadProgress[tempMessageId] = 1.0;
      
      // Encrypt the image URL
      final encryptedUrl = await _encryptionService.encryptMessageForChat(
        imageUrl,
        chatId,
      );
      
      // Prepare the message data for database (let DB generate the message_id)
      final messageData = {
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': encryptedUrl,
        'message_type': 'image',
        'recipient_id': recipientId,
        'expires_at': expiresAt.toIso8601String(),
        'is_read': false,
      };
      
      // Insert the message into the database
      final response = await _supabaseService.client
        .from('messages')
        .insert(messageData)
        .select();
        
      if (response.isEmpty) {
        debugPrint('Error: Empty response when sending image message');
        return;
      }

      // Get the real message from database with server-generated ID
      final sentMessage = MessageModel.fromJson(response.first);
      
      // Replace the temporary message with the real one from database
      final index = messages.indexWhere((m) => m.messageId == tempMessageId);
      if (index != -1) {
        // Create a copy with the decrypted URL
        final updatedMessage = sentMessage.copyWith(
          content: imageUrl, // Store the original URL for display
          isEncrypted: false,
        );
        
        messages[index] = updatedMessage;
        controller.messagesToAnimate.remove(tempMessageId);
        controller.messagesToAnimate.add(sentMessage.messageId);
      }
      
      // Force update UI lists
      messages.refresh();
      controller.messages.refresh();
      
      // Update recent chats
      await _updateRecentChat(chatId, '📷 Image');
      
    } catch (e) {
      debugPrint('Error uploading and sending image: $e');
      // Update progress to show error
      uploadProgress[tempMessageId] = -1.0;
      uploadProgress.refresh();
    }
  }
  
  /// Mark messages in a chat as read
  Future<void> markMessagesAsRead(String chatId) async {
    if (!isInitialized.value) return;
    
    try {
      // Get current user ID safely
      final String? currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) {
        debugPrint('Cannot mark messages as read: Current user ID is null');
        return;
      }
      
      // Get unread messages from current user
      final unreadMessages = messages.where((msg) => 
        msg.chatId == chatId && 
        msg.recipientId == currentUserId &&
        !msg.isRead
      ).toList();
      
      if (unreadMessages.isEmpty) return;
      
      // Get message IDs to update
      final messageIds = unreadMessages.map((msg) => msg.messageId).toList();
      
      // Update messages in database - Fix for the in_ method
      if (messageIds.isNotEmpty) {
        // For a single ID, use eq
        if (messageIds.length == 1) {
          await _supabaseService.client
            .from('messages')
            .update({'is_read': true})
            .eq('message_id', messageIds.first);
        } else {
          // For multiple IDs, use filter with the 'in' operator
          await _supabaseService.client
            .from('messages')
            .update({'is_read': true})
            .filter('message_id', 'in', messageIds);
        }
      }
      
      // Update local messages
      for (var msg in unreadMessages) {
        final index = messages.indexWhere((m) => m.messageId == msg.messageId);
        if (index != -1) {
          messages[index] = msg.copyWith(isRead: true);
        }
      }
      
      messages.refresh();
      controller.messages.refresh();
      
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
  
  /// Delete expired messages and clear cache
  Future<void> cleanupExpiredMessages() async {
    if (!isInitialized.value) return;
    
    try {
      // Get current time
      final now = DateTime.now().toUtc();
      
      // Find expired messages
      final expiredMessages = messages.where((msg) => msg.expiresAt.isBefore(now)).toList();
      
      if (expiredMessages.isEmpty) return;
      
      // Get message IDs to track as deleted
      final messageIds = expiredMessages.map((msg) => msg.messageId).toList();
      
      // Add to deleted set
      _deletedMessageIds.addAll(messageIds);
      
      // Remove from UI
      messages.removeWhere((msg) => messageIds.contains(msg.messageId));
      messages.refresh();
      controller.messages.refresh();
      
      // Clean up cache entries
      for (var msg in expiredMessages) {
        _decryptionCache.remove('${msg.chatId}:${msg.messageId}');
      }
      
    } catch (e) {
      debugPrint('Error cleaning up expired messages: $e');
    }
  }
  
  /// Force refresh all messages with decryption
  Future<void> forceRefreshMessages(String chatId) async {
    // Clear caches
    _decryptionCache.clear();
    _processedMessageIds.clear();
    
    // Reload messages
    await loadMessages(chatId);
  }
  
  /// Dispose method to cleanup resources
  @override
  void onClose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _decryptionCache.clear();
    _processedMessageIds.clear();
    _deletedMessageIds.clear();
    super.onClose();
  }
}

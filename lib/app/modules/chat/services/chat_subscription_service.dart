import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef MessageHandler = Function(Map<String, dynamic>);
typedef MessageUpdateHandler = Function(String, Map<String, dynamic>);
typedef MessageDeleteHandler = Function(String);
typedef ConnectionHandler = Function(bool);

/// Service for managing realtime chat subscriptions
class ChatSubscriptionService extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final ChatCacheService _chatCacheService = Get.find<ChatCacheService>();
  final EncryptionService _encryptionService = Get.find<EncryptionService>();

  // Realtime channel
  RealtimeChannel? _messageChannel;
  final RxBool isConnected = false.obs;

  // Callbacks
  late MessageHandler _onNewMessage;
  late MessageUpdateHandler _onMessageUpdate;
  late MessageDeleteHandler _onMessageDelete;
  late ConnectionHandler _onConnectionChange;

  // Message list references
  RxList<Map<String, dynamic>>? _messagesList;
  RxList<Map<String, dynamic>>? _chatsList;

  /// Initialize the service with message list reference
  void initialize({
    required RxList<Map<String, dynamic>> messagesList,
    required RxList<Map<String, dynamic>> chatsList,
  }) {
    _messagesList = messagesList;
    _chatsList = chatsList;
  }

  /// Subscribe to chat updates
  Future<void> subscribeToChatUpdates({
    required String userId,
    required MessageHandler onNewMessage,
    required MessageUpdateHandler onMessageUpdate,
    required MessageDeleteHandler onMessageDelete,
    required ConnectionHandler onConnectionChange,
  }) async {
    _onNewMessage = onNewMessage;
    _onMessageUpdate = onMessageUpdate;
    _onMessageDelete = onMessageDelete;
    _onConnectionChange = onConnectionChange;

    // Clean up existing subscription
    disconnectChat();

    try {
      // Create a channel for messages
      _messageChannel = _supabaseService.client.channel('messages:$userId');

      // Listen for sent messages
      _messageChannel = _messageChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: userId,
        ),
        callback: _handleNewMessage,
      );

      // Listen for received messages
      _messageChannel = _messageChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
        ),
        callback: _handleNewMessage,
      );

      // Listen for message updates
      _messageChannel = _messageChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: userId,
        ),
        callback: _handleMessageUpdate,
      );

      // Listen for received message updates
      _messageChannel = _messageChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
        ),
        callback: _handleMessageUpdate,
      );

      // Listen for sent message deletions
      _messageChannel = _messageChannel!.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: userId,
        ),
        callback: _handleMessageDelete,
      );

      // Listen for received message deletions
      _messageChannel = _messageChannel!.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
        ),
        callback: _handleMessageDelete,
      );

      // Subscribe to the channel
      _messageChannel!.subscribe((status, error) {
        if (error != null) {
          debugPrint('Error subscribing to messages: $error');
          isConnected.value = false;
          _onConnectionChange(false);
          return;
        }

        // Update connection status
        final connected = status == 'SUBSCRIBED';
        debugPrint('Subscription status for messages: $status');
        isConnected.value = connected;
        _onConnectionChange(connected);

        if (connected) {
          debugPrint('Successfully subscribed to chat messages');
        }
      });
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
      isConnected.value = false;
      _onConnectionChange(false);
    }
  }

  /// Handle new message events
  void _handleNewMessage(PostgresChangePayload payload) {
    try {
      debugPrint(
        'New message received through subscription: ${payload.newRecord}',
      );

      // Convert payload to map
      final Map<String, dynamic> message = Map<String, dynamic>.from(
        payload.newRecord,
      );

      // Add a timestamp if not present
      message['created_at'] =
          message['created_at'] ?? DateTime.now().toIso8601String();

      // Process through callback
      _onNewMessage(message);
    } catch (e) {
      debugPrint('Error handling new message from subscription: $e');
    }
  }

  /// Handle message updates
  void _handleMessageUpdate(PostgresChangePayload payload) {
    try {
      debugPrint('Message update received: ${payload.newRecord}');

      final String messageId =
          payload.newRecord['message_id']?.toString() ?? '';
      if (messageId.isEmpty) return;

      final Map<String, dynamic> updates = Map<String, dynamic>.from(
        payload.newRecord,
      );

      _onMessageUpdate(messageId, updates);
    } catch (e) {
      debugPrint('Error handling message update: $e');
    }
  }

  /// Handle message deletions
  void _handleMessageDelete(PostgresChangePayload payload) {
    try {
      debugPrint('Message delete received: ${payload.oldRecord}');

      final String messageId =
          payload.oldRecord['message_id']?.toString() ?? '';
      if (messageId.isEmpty) return;

      // Call the delete callback with the message ID
      _onMessageDelete(messageId);
    } catch (e) {
      debugPrint('Error handling message deletion: $e');
    }
  }

  /// Disconnect from chat subscriptions when done
  void disconnectChat() {
    try {
      if (_messageChannel != null) {
        _supabaseService.client.removeChannel(_messageChannel!);
        debugPrint('Disconnected from chat subscriptions');
      }
    } catch (e) {
      debugPrint('Error disconnecting chat: $e');
    }
  }

  /// Reconnect to chat (call after network recovery)
  Future<void> reconnectChat() async {
    try {
      // Refresh the subscription
      if (_supabaseService.currentUser.value?.id != null) {
        await subscribeToChatUpdates(
          userId: _supabaseService.currentUser.value!.id,
          onNewMessage: _onNewMessage,
          onMessageUpdate: _onMessageUpdate,
          onMessageDelete: _onMessageDelete,
          onConnectionChange: _onConnectionChange,
        );

        debugPrint('Reconnected to chat subscriptions');
      }
    } catch (e) {
      debugPrint('Error reconnecting chat: $e');
    }
  }

  @override
  void onClose() {
    disconnectChat();
    super.onClose();
  }
}

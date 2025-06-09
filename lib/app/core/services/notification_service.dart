import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

/// Service to create and manage notifications
class NotificationService extends GetxService {
  SupabaseService? _supabaseService;

  /// Get SupabaseService instance with lazy loading and error handling
  SupabaseService? get _supabase {
    if (_supabaseService == null) {
      try {
        if (Get.isRegistered<SupabaseService>()) {
          _supabaseService = Get.find<SupabaseService>();
        }
      } catch (e) {
        debugPrint('NotificationService: SupabaseService not available: $e');
        return null;
      }
    }
    return _supabaseService;
  }

  /// Initialize the notification service
  Future<NotificationService> init() async {
    debugPrint('NotificationService: Initialized');
    // Try to get SupabaseService during initialization
    _supabase;
    return this;
  }

  /// Create a follow notification
  Future<void> createFollowNotification({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint(
          'NotificationService: SupabaseService not available for follow notification',
        );
        return;
      }

      // Get follower's profile information
      final followerProfile =
          await supabase.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', followerId)
              .single();

      final followerNickname =
          followerProfile['nickname'] ??
          followerProfile['username'] ??
          'Someone';

      // Create notification record
      await supabase.client.from('notifications').insert({
        'user_id': followingId,
        'type': 'follow',
        'actor_id': followerId,
        'actor_nickname': followerNickname,
        'message': '$followerNickname started following you',
        'target_id': followerId, // The follower's profile
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
        'Follow notification created: $followerNickname -> $followingId',
      );

      // Send push notification
      await _sendPushNotification(
        userId: followingId,
        title: 'New Follower',
        body: '$followerNickname started following you',
        type: 'follow',
        targetId: followerId,
      );
    } catch (e) {
      debugPrint('Error creating follow notification: $e');
    }
  }

  /// Create a like notification
  Future<void> createLikeNotification({
    required String likerId,
    required String postOwnerId,
    required String postId,
  }) async {
    try {
      // Don't create notification if user likes their own post
      if (likerId == postOwnerId) return;

      final supabase = _supabase;
      if (supabase == null) {
        debugPrint(
          'NotificationService: SupabaseService not available for like notification',
        );
        return;
      }

      // Get liker's profile information
      final likerProfile =
          await supabase.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', likerId)
              .single();

      final likerNickname =
          likerProfile['nickname'] ?? likerProfile['username'] ?? 'Someone';

      // Create notification record
      await supabase.client.from('notifications').insert({
        'user_id': postOwnerId,
        'type': 'like',
        'actor_id': likerId,
        'actor_nickname': likerNickname,
        'message': '$likerNickname liked your post',
        'target_id': postId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Like notification created: $likerNickname -> $postOwnerId');

      // Send push notification
      await _sendPushNotification(
        userId: postOwnerId,
        title: 'Post Liked',
        body: '$likerNickname liked your post',
        type: 'like',
        targetId: postId,
      );
    } catch (e) {
      debugPrint('Error creating like notification: $e');
    }
  }

  /// Create a comment notification
  Future<void> createCommentNotification({
    required String commenterId,
    required String postOwnerId,
    required String postId,
    required String commentText,
  }) async {
    try {
      // Don't create notification if user comments on their own post
      if (commenterId == postOwnerId) return;

      final supabase = _supabase;
      if (supabase == null) {
        debugPrint(
          'NotificationService: SupabaseService not available for comment notification',
        );
        return;
      }

      // Get commenter's profile information
      final commenterProfile =
          await supabase.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', commenterId)
              .single();

      final commenterNickname =
          commenterProfile['nickname'] ??
          commenterProfile['username'] ??
          'Someone';

      // Create notification record
      await supabase.client.from('notifications').insert({
        'user_id': postOwnerId,
        'type': 'comment',
        'actor_id': commenterId,
        'actor_nickname': commenterNickname,
        'message': '$commenterNickname commented on your post',
        'target_id': postId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
        'Comment notification created: $commenterNickname -> $postOwnerId',
      );

      // Send push notification
      await _sendPushNotification(
        userId: postOwnerId,
        title: 'New Comment',
        body: '$commenterNickname commented on your post',
        type: 'comment',
        targetId: postId,
      );
    } catch (e) {
      debugPrint('Error creating comment notification: $e');
    }
  }

  /// Send push notification to user's devices
  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? targetId,
  }) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint(
          'NotificationService: SupabaseService not available for push notification',
        );
        return;
      }

      // Get user's device tokens
      final deviceTokens = await supabase.client
          .from('device_tokens')
          .select('token, platform')
          .eq('user_id', userId);

      if (deviceTokens.isEmpty) {
        debugPrint('No device tokens found for user $userId');
        return;
      }

      // For now, we'll use Supabase Edge Functions to send push notifications
      // This would typically call a cloud function that handles FCM/APNS
      await supabase.client.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type,
          'target_id': targetId,
          'device_tokens': deviceTokens,
        },
      );

      debugPrint('Push notification sent to $userId: $title');
    } catch (e) {
      debugPrint('Error sending push notification: $e');
      // Don't throw error - notification creation should still succeed
    }
  }

  /// Create a message notification
  Future<void> createMessageNotification({
    required String senderId,
    required String receiverId,
    required String messageText,
    String? chatId,
  }) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        debugPrint(
          'NotificationService: SupabaseService not available for message notification',
        );
        return;
      }

      // Get sender's profile information
      final senderProfile =
          await supabase.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', senderId)
              .single();

      final senderNickname =
          senderProfile['nickname'] ?? senderProfile['username'] ?? 'Someone';

      // Create notification record
      await supabase.client.from('notifications').insert({
        'user_id': receiverId,
        'type': 'message',
        'actor_id': senderId,
        'actor_nickname': senderNickname,
        'message':
            messageText.length > 50
                ? '${messageText.substring(0, 50)}...'
                : messageText,
        'target_id': chatId ?? senderId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
        'Message notification created: $senderNickname -> $receiverId',
      );

      // Send push notification
      await _sendPushNotification(
        userId: receiverId,
        title: 'New Message',
        body: '$senderNickname sent you a message',
        type: 'message',
        targetId: chatId ?? senderId,
      );
    } catch (e) {
      debugPrint('Error creating message notification: $e');
    }
  }
}

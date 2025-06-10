import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/notification_model.dart';

/// Repository for handling notification data operations
class NotificationRepository extends GetxService {
  SupabaseService get _supabase => Get.find<SupabaseService>();

  /// Get notifications for the current user
  Future<List<NotificationModel>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _supabase.currentUser.value?.id;
      if (userId == null) return [];

      try {
        final response = await _supabase.client
            .from('notifications')
            .select('*')
            .eq('user_id', userId)
            .neq('type', 'message') // Exclude message notifications
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        final notifications = response as List;

        return notifications.map((notification) {
          // Safe type casting to handle Map<dynamic, dynamic> from Supabase
          final notificationMap = <String, dynamic>{};
          if (notification is Map) {
            notification.forEach((key, value) {
              notificationMap[key.toString()] = value;
            });
          }
          return NotificationModel.fromMap(notificationMap);
        }).toList();
      } catch (tableError) {
        // Handle case where table doesn't exist yet
        debugPrint('Notification table error: $tableError');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final userId = _supabase.currentUser.value?.id;
      if (userId == null) return false;

      await _supabase.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .neq('type', 'message'); // Exclude message notifications
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final userId = _supabase.currentUser.value?.id;
      if (userId == null) return 0;

      try {
        // Use the count() method to get the count of unread notifications (excluding messages)
        final count =
            await _supabase.client
                .from('notifications')
                .select()
                .eq('user_id', userId)
                .eq('is_read', false)
                .neq('type', 'message') // Exclude message notifications
                .count();

        return count.count;
      } catch (tableError) {
        // Handle case where table doesn't exist yet
        debugPrint('Notification table error in count: $tableError');
        return 0;
      }
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
      return 0;
    }
  }
}

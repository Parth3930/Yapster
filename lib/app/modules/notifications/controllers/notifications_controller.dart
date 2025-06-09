import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/notification_model.dart';
import 'package:yapster/app/data/repositories/notification_repository.dart';

class NotificationsController extends GetxController {
  final NotificationRepository _notificationRepository =
      Get.find<NotificationRepository>();
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  final RxBool isLoading = false.obs;
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool hasMore = true.obs;
  final int limit = 20;
  int offset = 0;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
    initRealtimeSubscription();
  }

  @override
  void onClose() {
    // Clean up any subscriptions
    super.onClose();
  }

  /// Initialize realtime subscription for notifications
  void initRealtimeSubscription() {
    final userId = _supabaseService.currentUser.value?.id;
    if (userId == null) return;

    try {
      _supabaseService.client
          .channel('public:notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              try {
                if (payload.newRecord.isNotEmpty) {
                  final notification = NotificationModel.fromMap(
                    payload.newRecord,
                  );
                  notifications.insert(0, notification);
                  unreadCount.value++;
                }
              } catch (e) {
                debugPrint('Error processing notification: $e');
              }
            },
          )
          .subscribe((status, [error]) {
            if (error != null) {
              debugPrint('Notification subscription error: $error');
            } else {
              debugPrint('Notification subscription status: $status');
            }
          });
    } catch (e) {
      debugPrint('Error setting up notification subscription: $e');
    }
  }

  /// Load initial notifications
  Future<void> loadNotifications() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      offset = 0;

      final results = await _notificationRepository.getNotifications(
        limit: limit,
        offset: offset,
      );

      notifications.clear();
      notifications.addAll(results);

      hasMore.value = results.length >= limit;
      offset += results.length;

      // Get unread count
      unreadCount.value =
          await _notificationRepository.getUnreadNotificationCount();
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMoreNotifications() async {
    if (isLoading.value || !hasMore.value) return;

    try {
      isLoading.value = true;

      final results = await _notificationRepository.getNotifications(
        limit: limit,
        offset: offset,
      );

      notifications.addAll(results);

      hasMore.value = results.length >= limit;
      offset += results.length;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationRepository.markNotificationAsRead(notificationId);

    // Update local state
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = notifications[index];
      if (!notification.isRead) {
        final updatedNotification = NotificationModel(
          id: notification.id,
          userId: notification.userId,
          actorId: notification.actorId,
          actorUsername: notification.actorUsername,
          actorNickname: notification.actorNickname,
          actorAvatar: notification.actorAvatar,
          type: notification.type,
          postId: notification.postId,
          commentId: notification.commentId,
          message: notification.message,
          isRead: true,
          createdAt: notification.createdAt,
        );

        notifications[index] = updatedNotification;
        if (unreadCount.value > 0) unreadCount.value--;
      }
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await _notificationRepository.markAllNotificationsAsRead();

    // Update local state
    notifications.value =
        notifications.map((notification) {
          return NotificationModel(
            id: notification.id,
            userId: notification.userId,
            actorId: notification.actorId,
            actorUsername: notification.actorUsername,
            actorNickname: notification.actorNickname,
            actorAvatar: notification.actorAvatar,
            type: notification.type,
            postId: notification.postId,
            commentId: notification.commentId,
            message: notification.message,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }).toList();

    unreadCount.value = 0;
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationRepository.deleteNotification(notificationId);

    // Update local state
    notifications.removeWhere((n) => n.id == notificationId);
  }
}

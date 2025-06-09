import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/models/notification_model.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/notifications_controller.dart';

class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: TextStyle(
            fontFamily: GoogleFonts.dongle().fontFamily,
            fontSize: 32,
          ),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          Obx(
            () =>
                controller.notifications.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.done_all),
                      onPressed: controller.markAllAsRead,
                      tooltip: 'Mark all as read',
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  "No notifications yet",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "You'll see notifications here when they arrive",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadNotifications,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels ==
                  scrollInfo.metrics.maxScrollExtent) {
                controller.loadMoreNotifications();
              }
              return false;
            },
            child: ListView.builder(
              itemCount:
                  controller.notifications.length +
                  (controller.hasMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == controller.notifications.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final notification = controller.notifications[index];
                return NotificationItem(
                  notification: notification,
                  onTap: () {
                    // Mark as read when tapped
                    controller.markAsRead(notification.id);

                    // Navigate based on notification type
                    if (notification.type == 'follow') {
                      Get.toNamed('/profile/${notification.actorId}');
                    } else if (notification.type == 'like' ||
                        notification.type == 'comment') {
                      if (notification.postId != null) {
                        Get.toNamed('/post/${notification.postId}');
                      }
                    }
                  },
                  onDismiss:
                      () => controller.deleteNotification(notification.id),
                );
              },
            ),
          ),
        );
      }),
      bottomNavigationBar: const BottomNavigation(),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                notification.isRead ? null : Colors.grey.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                    notification.actorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(notification.actorAvatar)
                        : null,
                child:
                    notification.actorAvatar.isEmpty
                        ? const Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nickname
                    Text(
                      notification.actorNickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Notification text
                    Text(
                      notification.getNotificationText(),
                      style: const TextStyle(fontSize: 14),
                    ),

                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(notification.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Notification type icon
              _getNotificationIcon(notification.type),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'follow':
        return const Icon(Icons.person_add, color: Colors.blue);
      case 'like':
        return const Icon(Icons.favorite, color: Colors.red);
      case 'comment':
        return const Icon(Icons.comment, color: Colors.grey);
      case 'message':
        return const Icon(Icons.message, color: Colors.blueGrey);
      default:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}

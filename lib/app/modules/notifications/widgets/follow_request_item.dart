import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/notification_model.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/profile/views/profile_view.dart';
import 'package:yapster/app/startup/preloader/optimized_bindings.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowRequestItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onDismiss;
  final VoidCallback onRequestHandled;

  const FollowRequestItem({
    Key? key,
    required this.notification,
    required this.onDismiss,
    required this.onRequestHandled,
  }) : super(key: key);

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? null : Colors.grey.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar - tappable to view profile
            GestureDetector(
              onTap: () {
                Get.to(
                  () => ProfileView(userId: notification.actorId),
                  binding: OptimizedProfileBinding(),
                  transition: Transition.noTransition,
                  duration: Duration.zero,
                );
              },
              child: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey[800],
                backgroundImage:
                    notification.actorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(notification.actorAvatar)
                        : null,
                child:
                    notification.actorAvatar.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
              ),
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
                ],
              ),
            ),

            // Action buttons
            Row(
              children: [
                // Accept button
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _acceptRequest(notification.actorId),
                  tooltip: 'Accept',
                ),

                // Reject button
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejectRequest(notification.actorId),
                  tooltip: 'Reject',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(String requesterId) async {
    try {
      final accountDataProvider = Get.find<AccountDataProvider>();
      await accountDataProvider.acceptFollowRequest(requesterId);
      onRequestHandled();
      Get.snackbar(
        'Request Accepted',
        'Follow request accepted',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error accepting follow request: $e');
      Get.snackbar(
        'Error',
        'Failed to accept follow request',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _rejectRequest(String requesterId) async {
    try {
      final accountDataProvider = Get.find<AccountDataProvider>();
      await accountDataProvider.rejectFollowRequest(requesterId);
      onRequestHandled();
      Get.snackbar(
        'Request Rejected',
        'Follow request rejected',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.grey.withOpacity(0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error rejecting follow request: $e');
      Get.snackbar(
        'Error',
        'Failed to reject follow request',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/models/notification_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/profile/views/profile_view.dart';
import 'package:yapster/app/startup/preloader/optimized_bindings.dart';
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
            fontSize: 40,
            fontWeight: FontWeight.w500,
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
            child: _buildGroupedNotifications(),
          ),
        );
      }),
    );
  }

  /// Build notifications grouped by time periods (Today, Yesterday, Older)
  Widget _buildGroupedNotifications() {
    final groupedNotifications = _groupNotificationsByTime(
      controller.notifications,
    );

    return ListView.builder(
      itemCount: _calculateTotalItems(groupedNotifications),
      itemBuilder: (context, index) {
        return _buildGroupedItem(groupedNotifications, index);
      },
    );
  }

  /// Group notifications by time periods
  Map<String, List<NotificationModel>> _groupNotificationsByTime(
    List<NotificationModel> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationModel>> grouped = {
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    for (final notification in notifications) {
      final notificationDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      if (notificationDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(notification);
      } else if (notificationDate.isAtSameMomentAs(yesterday)) {
        grouped['Yesterday']!.add(notification);
      } else {
        grouped['Older']!.add(notification);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  /// Calculate total items including headers and loading indicator
  int _calculateTotalItems(
    Map<String, List<NotificationModel>> groupedNotifications,
  ) {
    int totalItems = 0;

    for (final entry in groupedNotifications.entries) {
      totalItems += 1; // Header
      totalItems += entry.value.length; // Notifications in this group
    }

    // Add loading indicator if there are more notifications
    if (controller.hasMore.value) {
      totalItems += 1;
    }

    return totalItems;
  }

  /// Build individual items (headers, notifications, loading indicator)
  Widget _buildGroupedItem(
    Map<String, List<NotificationModel>> groupedNotifications,
    int index,
  ) {
    int currentIndex = 0;

    for (final entry in groupedNotifications.entries) {
      final groupName = entry.key;
      final groupNotifications = entry.value;

      // Check if this index is the header for this group
      if (currentIndex == index) {
        return _buildGroupHeader(groupName);
      }
      currentIndex++;

      // Check if this index is within this group's notifications
      if (index < currentIndex + groupNotifications.length) {
        final notificationIndex = index - currentIndex;
        final notification = groupNotifications[notificationIndex];

        return NotificationItem(
          notification: notification,
          onTap: () {
            // Mark as read when tapped
            controller.markAsRead(notification.id);

            // Navigate based on notification type
            if (notification.type == 'follow') {
              // Navigate to the actor's profile
              Get.to(
                () => ProfileView(userId: notification.actorId),
                binding: OptimizedProfileBinding(),
                transition: Transition.noTransition,
                duration: Duration.zero,
              );
            } else if (notification.type == 'like' ||
                notification.type == 'comment') {
              if (notification.postId != null) {
                // Navigate to the specific post (implement post detail view if needed)
                debugPrint('Navigate to post: ${notification.postId}');
                // For now, navigate to the actor's profile
                Get.to(
                  () => ProfileView(userId: notification.actorId),
                  binding: OptimizedProfileBinding(),
                  transition: Transition.noTransition,
                  duration: Duration.zero,
                );
              }
            }
          },
          onDismiss: () => controller.deleteNotification(notification.id),
        );
      }
      currentIndex += groupNotifications.length;
    }

    // If we reach here, it must be the loading indicator
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Build group header (Today, Yesterday, Older)
  Widget _buildGroupHeader(String groupName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        groupName,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
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
              NotificationAvatarWidget(
                actorId: notification.actorId,
                actorAvatar: notification.actorAvatar,
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
}

class NotificationAvatarWidget extends StatefulWidget {
  final String actorId;
  final String actorAvatar;

  const NotificationAvatarWidget({
    super.key,
    required this.actorId,
    required this.actorAvatar,
  });

  @override
  State<NotificationAvatarWidget> createState() =>
      _NotificationAvatarWidgetState();
}

class _NotificationAvatarWidgetState extends State<NotificationAvatarWidget> {
  String? googleAvatar;
  bool isLoading = false;

  // Static cache to avoid repeated database calls for the same user
  static final Map<String, String?> _googleAvatarCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.actorAvatar == 'skiped' || widget.actorAvatar.isEmpty) {
      // Check cache first
      if (_googleAvatarCache.containsKey(widget.actorId)) {
        googleAvatar = _googleAvatarCache[widget.actorId];
      } else {
        _fetchGoogleAvatar();
      }
    }
  }

  Future<void> _fetchGoogleAvatar() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final supabase = Get.find<SupabaseService>();
      final response =
          await supabase.client
              .from('profiles')
              .select('google_avatar')
              .eq('user_id', widget.actorId)
              .single();

      final fetchedGoogleAvatar = response['google_avatar'];

      // Cache the result
      _googleAvatarCache[widget.actorId] = fetchedGoogleAvatar;

      if (mounted) {
        setState(() {
          googleAvatar = fetchedGoogleAvatar;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching google avatar for notification: $e');
      // Cache null result to avoid repeated failed requests
      _googleAvatarCache[widget.actorId] = null;

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which avatar to use
    String? avatarUrl;

    if (widget.actorAvatar != 'skiped' &&
        widget.actorAvatar.isNotEmpty &&
        widget.actorAvatar != 'null') {
      avatarUrl = widget.actorAvatar;
    } else if (googleAvatar != null &&
        googleAvatar!.isNotEmpty &&
        googleAvatar != 'null') {
      avatarUrl = googleAvatar;
    }

    // Validate URL before using it
    bool isValidUrl = false;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(avatarUrl);
        isValidUrl =
            uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
      } catch (e) {
        isValidUrl = false;
      }
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[200],
      backgroundImage:
          isValidUrl ? CachedNetworkImageProvider(avatarUrl!) : null,
      child:
          !isValidUrl
              ? const Icon(Icons.person, size: 30, color: Colors.grey)
              : null,
    );
  }
}

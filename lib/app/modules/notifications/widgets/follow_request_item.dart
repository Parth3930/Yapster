import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/notification_model.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/profile/views/profile_view.dart';
import 'package:yapster/app/startup/preloader/optimized_bindings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

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
              child: FollowRequestAvatarWidget(
                actorId: notification.actorId,
                actorAvatar: notification.actorAvatar,
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

class FollowRequestAvatarWidget extends StatefulWidget {
  final String actorId;
  final String actorAvatar;

  const FollowRequestAvatarWidget({
    super.key,
    required this.actorId,
    required this.actorAvatar,
  });

  @override
  State<FollowRequestAvatarWidget> createState() =>
      _FollowRequestAvatarWidgetState();
}

class _FollowRequestAvatarWidgetState extends State<FollowRequestAvatarWidget> {
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
      debugPrint('Error fetching google avatar for follow request: $e');
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
      radius: 25,
      backgroundColor: Colors.grey[800],
      backgroundImage:
          isValidUrl ? CachedNetworkImageProvider(avatarUrl!) : null,
      child: !isValidUrl ? const Icon(Icons.person, color: Colors.white) : null,
    );
  }
}

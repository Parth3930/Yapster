import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../../core/utils/supabase_service.dart';
import '../../../global_widgets/bottom_navigation.dart';
import '../../../core/services/push_notification_service.dart';
import 'posts_feed_controller.dart';

class HomeController extends GetxController {
  final supabaseService = Get.find<SupabaseService>();
  final RxString username = ''.obs;

  // Scroll management
  Timer? _showNavTimer;
  final RxDouble lastOffset = 0.0.obs;
  ScrollController? scrollController;

  // Bottom navigation controller
  late final BottomNavAnimationController bottomNavController;

  // Scroll detection sensitivity and timing
  static const double _scrollSensitivity =
      3.0; // Reduced for more responsive detection
  static const Duration _showNavDelay = Duration(
    milliseconds: 800,
  ); // Faster show delay

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController();
    bottomNavController = Get.find<BottomNavAnimationController>();

    // Check if we need to scroll to a specific post
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScrollToPost();
      _checkNotificationPermission();
    });
  }

  @override
  void onClose() {
    _showNavTimer?.cancel();
    scrollController?.dispose();
    super.onClose();
  }

  /// Handle scroll notifications with improved animation logic
  void onScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification ||
        notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      final offsetDifference = currentOffset - lastOffset.value;

      if (offsetDifference > _scrollSensitivity) {
        // Scrolling down - hide bottom nav immediately
        if (bottomNavController.showBottomNav.value) {
          bottomNavController.hideBottomNav();
        }
        _cancelShowNavTimer();
      } else if (offsetDifference < -_scrollSensitivity) {
        // Scrolling up - show bottom nav immediately
        if (!bottomNavController.showBottomNav.value) {
          bottomNavController.showBottomNavigation();
        }
        _cancelShowNavTimer();
      } else if (notification is UserScrollNotification &&
          notification.direction == ScrollDirection.idle) {
        // Stopped scrolling - show nav after delay if hidden
        _scheduleShowNav();
      }

      lastOffset.value = currentOffset;
    }
  }

  /// Cancel the show navigation timer
  void _cancelShowNavTimer() {
    _showNavTimer?.cancel();
    _showNavTimer = null;
  }

  /// Schedule showing navigation after scroll stops
  void _scheduleShowNav() {
    _cancelShowNavTimer();
    _showNavTimer = Timer(_showNavDelay, () {
      if (!bottomNavController.showBottomNav.value) {
        bottomNavController.showBottomNavigation();
      }
    });
  }

  /// Handle scroll to specific post
  void _handleScrollToPost() {
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      final scrollToPostId = arguments['scrollToPostId'] as String?;
      if (scrollToPostId != null && scrollToPostId.isNotEmpty) {
        // Wait for posts to load, then scroll to the specific post
        Timer(Duration(milliseconds: 1000), () {
          _scrollToPost(scrollToPostId);
        });
      }
    }
  }

  /// Scroll to specific post
  void _scrollToPost(String postId) {
    try {
      final controller = Get.find<PostsFeedController>();
      final postIndex = controller.posts.indexWhere(
        (post) => post.id == postId,
      );

      if (postIndex != -1 && scrollController != null) {
        // Calculate approximate position (each post is roughly 400px)
        final position = (postIndex * 400.0) + 200; // Add offset for header

        scrollController!.animateTo(
          position,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint('Error scrolling to post: $e');
    }
  }

  /// Check and request notification permission if not granted
  Future<void> _checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;

      if (status.isDenied) {
        // Show a dialog asking for permission
        _showNotificationPermissionDialog();
      } else if (status.isPermanentlyDenied) {
        // Permission was permanently denied, show settings dialog
        _showNotificationSettingsDialog();
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
    }
  }

  /// Show dialog to request notification permission
  void _showNotificationPermissionDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.notifications, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Stay Updated',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Get notified when someone follows you, likes your posts, or sends you a message. You can change this anytime in settings.',
          style: TextStyle(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Not Now', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _requestNotificationPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: Text('Allow'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Show dialog to open app settings for notification permission
  void _showNotificationSettingsDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Enable Notifications',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Notifications are disabled. To receive updates about follows, likes, and messages, please enable notifications in your device settings.',
          style: TextStyle(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: Text('Open Settings'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        // Permission granted, initialize push notification service
        final pushService = Get.find<PushNotificationService>();
        await pushService.init();

        Get.snackbar(
          'Notifications Enabled',
          'You\'ll now receive notifications for follows, likes, and messages',
          backgroundColor: Colors.green[700],
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );
      } else if (status.isPermanentlyDenied) {
        _showNotificationSettingsDialog();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Custom navigation function that hides bottom nav before navigating
  void navigateWithBottomNavAnimation(
    Widget destination, {
    Transition? transition,
    Duration? duration,
    dynamic binding,
  }) {
    // Hide bottom nav first to start slide animation
    bottomNavController.hideBottomNav();

    // Small delay to let the slide down animation start, then navigate
    Future.delayed(const Duration(milliseconds: 100), () {
      Get.to(
        () => destination,
        transition: transition ?? Transition.rightToLeft,
        duration: duration ?? const Duration(milliseconds: 300),
        binding: binding,
      )?.then((_) {
        // Show bottom nav when returning
        bottomNavController.onReturnToHome();
      });
    });
  }
}

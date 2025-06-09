import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/notification_model.dart';
import 'package:yapster/app/data/repositories/device_token_repository.dart';

/// Service to handle push notifications using Supabase Realtime
class PushNotificationService extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final DeviceTokenRepository _deviceTokenRepository =
      Get.find<DeviceTokenRepository>();

  // For local notifications when app is in foreground
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Channel for Android notifications
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'yapster_notifications',
    'Yapster Notifications',
    description: 'Notifications from Yapster',
    importance: Importance.max,
  );

  // Track subscription status
  RealtimeChannel? _notificationsChannel;
  bool _isSubscribed = false;

  /// Initialize the push notification service
  Future<PushNotificationService> init() async {
    debugPrint('Initializing Supabase push notification service');

    try {
      // Initialize local notifications for when app is in foreground
      await _initializeLocalNotifications();

      // Set up Supabase realtime subscription
      await _setupRealtimeSubscription();

      // Register device information
      await _registerDeviceInfo();

      debugPrint('Supabase push notification service initialized');
      return this;
    } catch (e) {
      debugPrint('Error initializing push notification service: $e');
      return this;
    }
  }

  /// Initialize local notifications configuration
  Future<void> _initializeLocalNotifications() async {
    try {
      // Set up channel for Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // Define platform-specific settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combine settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      // Initialize the plugin
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('Local notifications initialized');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  /// Set up Supabase Realtime subscription for notifications
  Future<void> _setupRealtimeSubscription() async {
    try {
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) {
        debugPrint('User not authenticated, skipping realtime subscription');
        return;
      }

      // Listen for auth state changes to manage subscriptions
      _setupAuthListeners();

      // Subscribe to the notifications table for this user
      await _subscribeToNotifications(userId);

      debugPrint('Supabase realtime subscription set up successfully');
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  /// Subscribe to notifications for a specific user
  Future<void> _subscribeToNotifications(String userId) async {
    try {
      // Unsubscribe from any existing subscription
      await _unsubscribeFromNotifications();

      // Create a new subscription
      _notificationsChannel = _supabaseService.client
          .channel('public:notifications:user_id=$userId')
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
              debugPrint('New notification received via Supabase Realtime');
              _handleNewNotification(payload);
            },
          );

      // Subscribe to the channel
      _notificationsChannel?.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('Successfully subscribed to notifications');
          _isSubscribed = true;
        } else if (error != null) {
          debugPrint('Error subscribing to notifications: $error');
          _isSubscribed = false;
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to notifications: $e');
      _isSubscribed = false;
    }
  }

  /// Unsubscribe from current notifications channel
  Future<void> _unsubscribeFromNotifications() async {
    try {
      if (_notificationsChannel != null) {
        await _supabaseService.client.removeChannel(_notificationsChannel!);
        debugPrint('Unsubscribed from notifications channel');
        _isSubscribed = false;
        _notificationsChannel = null;
      }
    } catch (e) {
      debugPrint('Error unsubscribing from notifications: $e');
    }
  }

  /// Handle auth state changes
  void _setupAuthListeners() {
    _supabaseService.isAuthenticated.listen((isAuthenticated) async {
      if (isAuthenticated) {
        // User logged in, set up subscription
        final userId = _supabaseService.currentUser.value?.id;
        if (userId != null && !_isSubscribed) {
          await _subscribeToNotifications(userId);
          await _registerDeviceInfo();
        }
      } else {
        // User logged out, remove subscription
        await _unsubscribeFromNotifications();
        // Remove device token if we have it
        await _deviceTokenRepository.removeAllUserTokens();
      }
    });
  }

  /// Register device information for push notifications
  Future<void> _registerDeviceInfo() async {
    try {
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) return;

      // Get the device identifier from DeviceTokenRepository
      final deviceId = await _deviceTokenRepository.getDeviceIdentifier();

      // Register with device token repository
      await _deviceTokenRepository.registerDeviceToken(deviceId);

      debugPrint('Device registered for Supabase push notifications');
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  /// Handle a new notification from Supabase Realtime
  void _handleNewNotification(PostgresChangePayload payload) {
    try {
      // Convert the payload to a notification model
      final notification = NotificationModel.fromMap(payload.newRecord);

      // Show a local notification if app is in foreground
      _showLocalNotification(
        id: notification.id.hashCode,
        title: _getNotificationTitle(notification),
        body: _getNotificationBody(notification),
        payload: _createNotificationPayload(notification),
      );
    } catch (e) {
      debugPrint('Error handling new notification: $e');
    }
  }

  /// Create a simple string payload from a notification
  String _createNotificationPayload(NotificationModel notification) {
    // Create a simple comma-separated format that's easy to parse
    return [
      'type:${notification.type}',
      'target_id:${notification.actorId}',
      'post_id:${notification.postId ?? ""}',
      'comment_id:${notification.commentId ?? ""}',
    ].join(',');
  }

  /// Get notification title based on type
  String _getNotificationTitle(NotificationModel notification) {
    switch (notification.type) {
      case 'follow':
        return '${notification.actorNickname} started following you';
      case 'like':
        return 'New like on your post';
      case 'comment':
        return '${notification.actorNickname} commented on your post';
      case 'message':
        return 'New message from ${notification.actorNickname}';
      default:
        return 'New notification';
    }
  }

  /// Get notification body based on type
  String _getNotificationBody(NotificationModel notification) {
    switch (notification.type) {
      case 'follow':
        return 'Tap to view their profile';
      case 'like':
        return '${notification.actorNickname} liked your post';
      case 'comment':
        return notification.message ?? 'Tap to view the comment';
      case 'message':
        return notification.message ?? 'Tap to view the message';
      default:
        return 'Tap to view details';
    }
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('Notification tapped: ${response.payload}');

      if (response.payload != null) {
        // Try to parse the payload as a notification
        try {
          final Map<String, dynamic> data = Map<String, dynamic>.from({
            for (var entry in response.payload!.split(','))
              entry.split(':')[0].trim(): entry.split(':')[1].trim(),
          });

          _handleNotificationNavigation(data);
        } catch (e) {
          debugPrint('Error parsing notification payload: $e');
          _navigateToNotifications();
        }
      } else {
        _navigateToNotifications();
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      _navigateToNotifications();
    }
  }

  /// Navigate to the notifications screen
  void _navigateToNotifications() {
    Get.toNamed('/notifications');
  }

  /// Handle navigation based on notification type
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      final type = data['type'] as String?;
      final targetId = data['target_id'] as String?;

      if (type == null) {
        _navigateToNotifications();
        return;
      }

      switch (type) {
        case 'follow':
          // Navigate to profile of user who followed
          if (targetId != null) {
            Get.toNamed('/profile/$targetId');
          } else {
            _navigateToNotifications();
          }
          break;

        case 'like':
        case 'comment':
          // Navigate to the post that was liked/commented on
          if (targetId != null) {
            Get.toNamed('/post/$targetId');
          } else {
            _navigateToNotifications();
          }
          break;

        case 'message':
          // Navigate to chat with the user
          if (targetId != null) {
            Get.toNamed('/chat/$targetId');
          } else {
            Get.toNamed('/messages');
          }
          break;

        default:
          // Default to notifications screen
          _navigateToNotifications();
          break;
      }
    } catch (e) {
      debugPrint('Error handling notification navigation: $e');
      _navigateToNotifications();
    }
  }
}

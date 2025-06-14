import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettingsController extends GetxController {
  // Observable variables for notification settings
  final RxBool overallNotifications = true.obs;
  final RxBool likesNotifications = true.obs;
  final RxBool commentsNotifications = true.obs;
  final RxBool newFollowersNotifications = true.obs;
  final RxBool messagesNotifications = true.obs;
  final RxBool directMessagesNotifications = true.obs;

  // SharedPreferences keys
  static const String _overallKey = 'notifications_overall';
  static const String _likesKey = 'notifications_likes';
  static const String _commentsKey = 'notifications_comments';
  static const String _newFollowersKey = 'notifications_new_followers';
  static const String _messagesKey = 'notifications_messages';
  static const String _directMessagesKey = 'notifications_direct_messages';

  @override
  void onInit() {
    super.onInit();
    _loadNotificationSettings();
  }

  /// Load notification settings from SharedPreferences
  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      overallNotifications.value = prefs.getBool(_overallKey) ?? true;
      likesNotifications.value = prefs.getBool(_likesKey) ?? true;
      commentsNotifications.value = prefs.getBool(_commentsKey) ?? true;
      newFollowersNotifications.value = prefs.getBool(_newFollowersKey) ?? true;
      messagesNotifications.value = prefs.getBool(_messagesKey) ?? true;
      directMessagesNotifications.value =
          prefs.getBool(_directMessagesKey) ?? true;
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  /// Save notification settings to SharedPreferences
  Future<void> _saveNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_overallKey, overallNotifications.value);
      await prefs.setBool(_likesKey, likesNotifications.value);
      await prefs.setBool(_commentsKey, commentsNotifications.value);
      await prefs.setBool(_newFollowersKey, newFollowersNotifications.value);
      await prefs.setBool(_messagesKey, messagesNotifications.value);
      await prefs.setBool(
        _directMessagesKey,
        directMessagesNotifications.value,
      );
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  /// Toggle overall notifications
  void toggleOverallNotifications(bool value) {
    overallNotifications.value = value;

    // If overall is turned off, turn off all other notifications
    if (!value) {
      likesNotifications.value = false;
      commentsNotifications.value = false;
      newFollowersNotifications.value = false;
      messagesNotifications.value = false;
      directMessagesNotifications.value = false;
    }

    _saveNotificationSettings();
  }

  /// Toggle likes notifications
  void toggleLikesNotifications(bool value) {
    likesNotifications.value = value;
    _checkOverallNotifications();
    _saveNotificationSettings();
  }

  /// Toggle comments notifications
  void toggleCommentsNotifications(bool value) {
    commentsNotifications.value = value;
    _checkOverallNotifications();
    _saveNotificationSettings();
  }

  /// Toggle new followers notifications
  void toggleNewFollowersNotifications(bool value) {
    newFollowersNotifications.value = value;
    _checkOverallNotifications();
    _saveNotificationSettings();
  }

  /// Toggle messages notifications
  void toggleMessagesNotifications(bool value) {
    messagesNotifications.value = value;
    _checkOverallNotifications();
    _saveNotificationSettings();
  }

  /// Toggle direct messages notifications
  void toggleDirectMessagesNotifications(bool value) {
    directMessagesNotifications.value = value;
    _checkOverallNotifications();
    _saveNotificationSettings();
  }

  /// Check if overall notifications should be turned off
  void _checkOverallNotifications() {
    // If all individual notifications are off, turn off overall
    if (!likesNotifications.value &&
        !commentsNotifications.value &&
        !newFollowersNotifications.value &&
        !messagesNotifications.value &&
        !directMessagesNotifications.value) {
      overallNotifications.value = false;
    }
    // If any individual notification is on, turn on overall
    else if (!overallNotifications.value) {
      overallNotifications.value = true;
    }
  }

  /// Get notification setting for a specific type
  bool getNotificationSetting(String type) {
    switch (type.toLowerCase()) {
      case 'overall':
        return overallNotifications.value;
      case 'likes':
        return likesNotifications.value && overallNotifications.value;
      case 'comments':
        return commentsNotifications.value && overallNotifications.value;
      case 'new_followers':
        return newFollowersNotifications.value && overallNotifications.value;
      case 'messages':
        return messagesNotifications.value && overallNotifications.value;
      case 'direct_messages':
        return directMessagesNotifications.value && overallNotifications.value;
      default:
        return false;
    }
  }
}

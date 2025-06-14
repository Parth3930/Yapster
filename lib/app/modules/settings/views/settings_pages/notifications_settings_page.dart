import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/modules/settings/controllers/notifications_settings_controller.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  late NotificationsSettingsController controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller
    controller = Get.put(
      NotificationsSettingsController(),
      tag: 'notifications_settings',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Overall notifications
              Obx(
                () => _buildNotificationItem(
                  title: 'Overall',
                  value: controller.overallNotifications.value,
                  onChanged: controller.toggleOverallNotifications,
                ),
              ),

              const SizedBox(height: 16),

              // Likes notifications
              Obx(
                () => _buildNotificationItem(
                  title: 'Likes',
                  value: controller.likesNotifications.value,
                  onChanged: controller.toggleLikesNotifications,
                  enabled: controller.overallNotifications.value,
                ),
              ),

              const SizedBox(height: 16),

              // Comments notifications
              Obx(
                () => _buildNotificationItem(
                  title: 'Comments',
                  value: controller.commentsNotifications.value,
                  onChanged: controller.toggleCommentsNotifications,
                  enabled: controller.overallNotifications.value,
                ),
              ),

              const SizedBox(height: 16),

              // New Followers notifications
              Obx(
                () => _buildNotificationItem(
                  title: 'New Followers',
                  value: controller.newFollowersNotifications.value,
                  onChanged: controller.toggleNewFollowersNotifications,
                  enabled: controller.overallNotifications.value,
                ),
              ),

              const SizedBox(height: 16),

              // Messages notifications
              Obx(
                () => _buildNotificationItem(
                  title: 'Messages',
                  value: controller.messagesNotifications.value,
                  onChanged: controller.toggleMessagesNotifications,
                  enabled: controller.overallNotifications.value,
                ),
              ),

              const SizedBox(height: 16),

              // Direct Messages notifications
              Obx(
                () => _buildNotificationItem(
                  title: 'Direct Messages',
                  value: controller.directMessagesNotifications.value,
                  onChanged: controller.toggleDirectMessagesNotifications,
                  enabled: controller.overallNotifications.value,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required bool value,
    required Function(bool) onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.roboto().fontFamily,
            ),
          ),
          _buildCustomSwitch(
            value: enabled ? value : false,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSwitch({
    required bool value,
    required Function(bool)? onChanged,
  }) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? Colors.green : Colors.grey[700],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<NotificationsSettingsController>(tag: 'notifications_settings');
    super.dispose();
  }
}

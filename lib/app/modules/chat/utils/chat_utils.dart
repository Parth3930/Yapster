import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'dart:math';

/// Utility class containing helper methods for chat functionality
class ChatUtils {
  /// Generate a unique conversation ID for direct messages
  static String generateDirectChatId(String userId1, String userId2) {
    // Sort IDs to ensure consistent ID generation
    final List<String> sortedIds = [userId1, userId2]..sort();
    return 'chat_${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Generate a unique ID for a new group chat
  static String generateGroupChatId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'group_${timestamp}_$random';
  }

  /// Generate a unique message ID
  static String generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000000);
    return 'msg_${timestamp}_$random';
  }

  /// Request necessary permissions for image picking
  static Future<bool> requestImagePermission() async {
    // Since we don't have permission_handler, we'll use the image_picker directly
    // which will request permissions as needed
    return true;
  }

  /// Request necessary permissions for audio recording
  static Future<bool> requestAudioPermissions() async {
    // Since we don't have permission_handler, we'll handle this at the usage site
    return true;
  }

  /// Pick image from gallery or camera
  static Future<XFile?> pickImage(ImageSource source) async {
    try {
      final imagePicker = ImagePicker();

      return await imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to pick image: $e');
      return null;
    }
  }

  /// Show permission denied dialog with option to open settings
  static void showPermissionDeniedDialog(String permissionType) {
    Get.dialog(
      AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          '$permissionType permission is required to use this feature. '
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              // No direct way to open app settings without permission_handler
              // This would typically open the app settings
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Calculate time difference for display
  static String getTimeDifference(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  /// Navigate to chat screen with given user ID
  static void navigateToChatWithUser(
    String userId,
    String username,
    String? imageUrl,
  ) {
    Get.toNamed(
      Routes.CHAT_WINDOW,
      arguments: {
        'user_id': userId,
        'username': username,
        'image_url': imageUrl,
      },
    );
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
      return '$gb GB';
    }
  }

  /// Format audio duration for display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Copy text to clipboard and show a toast
  static void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'Text copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.black.withValues(alpha: 0.7),
      colorText: Colors.white,
      margin: const EdgeInsets.all(8),
    );
  }
}

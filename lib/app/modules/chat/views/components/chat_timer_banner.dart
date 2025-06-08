import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';

class ChatTimerBanner extends StatelessWidget {
  const ChatTimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();

    // Check if user has already dismissed the banner
    if (controller.hasUserDismissedExpiryBanner.value) {
      return const SizedBox.shrink(); // Don't show banner if dismissed
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.amber.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Messages will disappear after 24 hours',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.amber,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {},
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.amber,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
        ],
      ),
    );
  }
}

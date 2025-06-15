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
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Center(
            child: Text(
              'Messages will disappear after 24 hrs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(thickness: 0.1, height: 0.1, color: Colors.grey),
        ],
      ),
    );
  }
}

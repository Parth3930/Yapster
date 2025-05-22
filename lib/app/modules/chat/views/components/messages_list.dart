import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import '../../controllers/chat_controller.dart';
import 'message_bubble.dart';

class MessagesList extends StatelessWidget {
  const MessagesList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();
    final currentUserId = SupabaseService.to.currentUser.value?.id;

    // Only observe the length of the messages list to minimize rebuilds
    return Obx(() {
      final messageCount = controller.sortedMessages.length;

      if (messageCount == 0) {
        return const Center(
          child: Text('No messages yet', style: TextStyle(color: Colors.white)),
        );
      }

      final args = Get.arguments;
      if (args == null || args is! Map<String, dynamic>) {
        return const Center(
          child: Text(
            'Chat data unavailable',
            style: TextStyle(color: Colors.red),
          ),
        );
      }

      final String? otherUserId = args['otherUserId'] as String?;
      if (otherUserId == null) {
        return const Center(
          child: Text(
            'Other user info missing',
            style: TextStyle(color: Colors.red),
          ),
        );
      }

      // Use ListView.builder with cacheExtent and keep-alive
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: messageCount,
        reverse: true,
        cacheExtent: 1000, // keep items alive off-screen
        itemBuilder: (context, index) {
          // Access the message directly from the controller to avoid rebuilding the whole list
          final msg = controller.sortedMessages[index];
          final isMe = msg.senderId == currentUserId;

          return _MessageBubbleWrapper(
            message: msg,
            isMe: isMe,
            otherUserId: otherUserId,
            onTapImage: (message) => _handleImageTap(context, message),
          );
        },
      );
    });
  }

  void _handleImageTap(BuildContext context, Map<String, dynamic> message) {
    final String messageContent = (message['content'] ?? '').toString();
    String? imageUrl;

    if (messageContent.startsWith('image:')) {
      imageUrl = messageContent.substring(6);
    } else if (messageContent.startsWith('https://')) {
      imageUrl = messageContent;
    }

    if (imageUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'Image',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(imageUrl!),
                ),
              ),
            ),
      ),
    );
  }
}

// Wrap each message bubble in its own reactive widget to minimize rebuilds
class _MessageBubbleWrapper extends StatelessWidget {
  final dynamic message;
  final bool isMe;
  final String otherUserId;
  final void Function(Map<String, dynamic>) onTapImage;

  const _MessageBubbleWrapper({
    required this.message,
    required this.isMe,
    required this.otherUserId,
    required this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();
    // If message has observable properties (like isRead),
    // you can make those reactive inside MessageBubble itself.

    // If message has observable properties (like isRead),
    // you can make those reactive inside MessageBubble itself.

    // Wrap MessageBubble in Obx to react to changes in messagesToAnimate
    return Obx(() {
      final msgMap = {
        'message_id': message.messageId,
        'content': message.content,
        'created_at': message.createdAt.toIso8601String(),
        'sender_id': message.senderId,
        'is_read': message.isRead,
        'expires_at': message.expiresAt.toIso8601String(),
        'message_type': message.messageType,
        'chat_id': message.chatId,
        'recipient_id': message.recipientId,
        'is_new': controller.messagesToAnimate.contains(message.messageId),
      };
      final isDeleting =
          controller.deletingMessageId.value == message.messageId;
      return MessageBubble(
        key: ValueKey(
          'msg_${message.messageId}_${message.senderId}_${isMe}_${msgMap['is_new']}_$isDeleting',
        ),
        message: msgMap,
        isMe: isMe,
        otherUserId: otherUserId,
        onTapImage: onTapImage,
        onAnimationComplete: controller.onMessageAnimationComplete,
        onDeleteAnimationComplete:
            (id) => controller.onDeleteAnimationComplete(id),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/group_controller.dart';
import 'message_bubble.dart';

class MessagesList extends StatelessWidget {
  const MessagesList({super.key});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final currentUserId = SupabaseService.to.currentUser.value?.id;

    // Check if this is a group chat by trying to find GroupController
    GroupController? groupController;
    try {
      groupController = Get.find<GroupController>();
    } catch (e) {
      // Not a group chat
    }

    final args = Get.arguments;
    final bool isGroupChat =
        args != null &&
        args is Map<String, dynamic> &&
        args.containsKey('groupId') &&
        groupController != null;

    return Obx(() {
      List<dynamic> messages;
      int messageCount;

      if (isGroupChat) {
        // Use group messages
        messages = List.from(groupController!.currentGroupMessages)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        messageCount = messages.length;
      } else {
        // Use regular chat messages
        messages = chatController.sortedMessages;
        messageCount = messages.length;
      }

      if (messageCount == 0) {
        return Center(
          child: Text(
            isGroupChat
                ? 'No messages yet\nStart the conversation!'
                : 'No messages yet',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      }

      if (currentUserId == null) {
        return const Center(
          child: Text(
            'User not authenticated',
            style: TextStyle(color: Colors.red),
          ),
        );
      }

      // For regular chat, we need otherUserId
      String? otherUserId;
      if (!isGroupChat) {
        if (args == null || args is! Map<String, dynamic>) {
          return const Center(
            child: Text(
              'Chat data unavailable',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        otherUserId = args['otherUserId'] as String?;
        if (otherUserId == null) {
          return const Center(
            child: Text(
              'Other user info missing',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
      }

      // Use ListView.builder with cacheExtent and keep-alive
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: messageCount,
        reverse: true,
        cacheExtent: 1000, // keep items alive off-screen
        itemBuilder: (context, index) {
          final msg = messages[index];
          final isMe =
              isGroupChat
                  ? msg.senderId == currentUserId
                  : msg.senderId == currentUserId;

          if (isGroupChat) {
            return _GroupMessageBubbleWrapper(
              message: msg,
              isMe: isMe,
              groupId: args['groupId'] as String,
            );
          } else {
            return _MessageBubbleWrapper(
              message: msg,
              isMe: isMe,
              otherUserId: otherUserId!,
              onTapImage: (message) => _handleImageTap(context, message),
            );
          }
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

    // Wrap MessageBubble in Obx to react to changes in messagesToAnimate and message content
    return Obx(() {
      // CRITICAL: Create a fresh map each time to ensure reactivity to content changes
      final msgMap = {
        'message_id': message.messageId,
        'content':
            message.content, // This will update when image upload completes
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

      // Include content in the key to force rebuild when content changes (e.g., image upload)
      return MessageBubble(
        key: ValueKey(
          'msg_${message.messageId}_${message.senderId}_${isMe}_${msgMap['is_new']}_${isDeleting}_${message.content.hashCode}',
        ),
        message: msgMap,
        isMe: isMe,
        otherUserId: otherUserId,
        onTapImage: onTapImage,
        onAnimationComplete: controller.onMessageAnimationComplete,
      );
    });
  }
}

// Wrapper for group message bubbles
class _GroupMessageBubbleWrapper extends StatelessWidget {
  final dynamic message; // GroupMessageModel
  final bool isMe;
  final String groupId;

  const _GroupMessageBubbleWrapper({
    required this.message,
    required this.isMe,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final groupController = Get.find<GroupController>();

    return Obx(() {
      final isDeleting = groupController.deletingMessageId.value == message.id;

      // Convert group message to format expected by MessageBubble
      final msgMap = {
        'message_id': message.id ?? '',
        'content': message.content ?? '',
        'created_at':
            message.createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'sender_id': message.senderId ?? '',
        'is_read': true, // Group messages are always considered read
        'expires_at':
            DateTime.now()
                .add(const Duration(hours: 24))
                .toIso8601String(), // Default expiry
        'message_type': message.messageType ?? 'text',
        'chat_id': groupId,
        'recipient_id': '', // Not applicable for group messages
        'is_new': groupController.messagesToAnimate.contains(message.id),
      };

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform:
            Matrix4.identity()
              ..scale(isDeleting ? 0.0 : 1.0)
              ..translate(isDeleting ? 50.0 : 0.0, 0.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDeleting ? 0.0 : 1.0,
          child: MessageBubble(
            key: ValueKey(
              'group_msg_${message.id}_${message.senderId}_${isMe}_${msgMap['is_new']}_$isDeleting',
            ),
            message: msgMap,
            isMe: isMe,
            otherUserId:
                groupId, // Use groupId as otherUserId for group messages
            onTapImage: (message) => _handleImageTap(context, message),
            onAnimationComplete: (messageId) {
              // Handle animation complete for group messages
              groupController.onMessageAnimationComplete(messageId);
            },
          ),
        ),
      );
    });
  }

  void _handleImageTap(BuildContext context, Map<String, dynamic> message) {
    final String messageContent = (message['content'] ?? '').toString();
    String? imageUrl;

    // Check if this is an image message
    if (messageContent.startsWith('http') &&
        (messageContent.contains('.jpg') ||
            messageContent.contains('.jpeg') ||
            messageContent.contains('.png') ||
            messageContent.contains('.gif'))) {
      imageUrl = messageContent;
    }

    if (imageUrl != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  iconTheme: const IconThemeData(color: Colors.white),
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
}

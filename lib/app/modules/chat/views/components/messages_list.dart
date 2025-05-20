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

    return Obx(() {
      if (controller.messages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a message to start the conversation',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      final currentUserId = SupabaseService.to.currentUser.value?.id;
      // Get arguments to determine the other user - using a safer approach
      final args = Get.arguments;

      // Make sure we have arguments
      if (args == null || args is! Map<String, dynamic>) {
        // Handle missing arguments case
        debugPrint('Error: Get.arguments is null or invalid in MessagesList');
        return const Center(
          child: Text(
            'Chat data unavailable',
            style: TextStyle(color: Colors.red),
          ),
        );
      }

      // Safely get the other user ID with null check
      final String? otherUserId = args['other_user_id'] as String?;
      if (otherUserId == null) {
        debugPrint('Error: other_user_id is null in chat arguments');
        return const Center(
          child: Text(
            'Other user info missing',
            style: TextStyle(color: Colors.red),
          ),
        );
      }

      // Always operate on a new list to force UI refresh - with safer handling
      try {
        // Use .toList() to create a new list that will trigger the Obx rebuild
        final sortedMessages =
            controller.messages.toList()..sort(
              (a, b) =>
                  (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
            );

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 8),
          itemCount: sortedMessages.length,
          reverse: true, // Show messages from bottom up
          itemBuilder: (context, index) {
            final message = sortedMessages[index];
            final isMe = message['sender_id'] == currentUserId;

            return MessageBubble(
              key: ValueKey(
                'msg_${message['message_id']}_${message['is_sending'] == true}',
              ),
              message: message,
              isMe: isMe,
              otherUserId: otherUserId,
              onTapImage: (msg) => _handleImageTap(context, msg),
            );
          },
        );
      } catch (e) {
        debugPrint('Error building messages list: $e');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading messages: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final args = Get.arguments;
                  if (args is Map<String, dynamic> && args['chat_id'] != null) {
                    controller.loadMessages(args['chat_id']);
                  }
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      }
    });
  }

  // Handle image tap to show full-screen viewer
  void _handleImageTap(BuildContext context, Map<String, dynamic> message) {
    final String messageContent = (message['content'] ?? '').toString();
    String? imageUrl;

    if (messageContent.startsWith('image:')) {
      imageUrl = messageContent.substring(6); // Remove 'image:' prefix
    } else if (messageContent.startsWith('https://')) {
      imageUrl = messageContent;
    }

    if (imageUrl == null) return;

    // Show fullscreen image viewer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
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
                  child: Image.network(
                    imageUrl!, // Non-null assertion is safe here because of early return above
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading image: $error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

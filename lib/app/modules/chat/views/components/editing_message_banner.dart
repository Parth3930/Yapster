import 'package:flutter/material.dart';
import 'message_input.dart';

class EditingMessageBanner extends StatelessWidget {
  const EditingMessageBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final message = MessageInput.messageBeingEdited.value;
    if (message == null) return const SizedBox.shrink();
    
    // Get the message content
    final messageContent = message['content'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        border: Border(
          top: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1),
          bottom: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  messageContent,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 16),
            onPressed: MessageInput.cancelEditMessage,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ],
      ),
    );
  }
} 
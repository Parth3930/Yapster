import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../../controllers/chat_controller.dart';
import '../message_options.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String otherUserId;
  final Function(Map<String, dynamic>) onTapImage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserId,
    required this.onTapImage,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool get isNew => widget.message['is_new'] == true;
  bool get isSending => widget.message['is_sending'] == true;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Start the animation for new messages
    if (isNew || isSending) {
      _controller.forward();

      // Clear the new flag after animation completes
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && widget.message is Map) {
          final message = widget.message as Map<String, dynamic>;
          message['is_new'] = false;
        }
      });
    } else {
      // For existing messages, just set to final state
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccountDataProvider accountDataProvider =
        Get.find<AccountDataProvider>();
    final ChatController chatController = Get.find<ChatController>();

    // Variables to hold avatar info
    String? regularAvatar;
    String? googleAvatar;

    if (widget.isMe) {
      // Current user's message - use current user's avatar
      regularAvatar = accountDataProvider.avatar.value;
      googleAvatar = accountDataProvider.googleAvatar.value;
    } else {
      // First check the following list
      final followingMatch = accountDataProvider.following.firstWhereOrNull(
        (f) => f['following_id'] == widget.otherUserId,
      );

      // Then check the followers list
      final followerMatch = accountDataProvider.followers.firstWhereOrNull(
        (f) => f['follower_id'] == widget.otherUserId,
      );

      if (followingMatch != null) {
        regularAvatar = followingMatch['avatar'];
        googleAvatar = followingMatch['google_avatar'];
        debugPrint(
          'Found other user in following list - avatar: $regularAvatar, google: $googleAvatar',
        );
      } else if (followerMatch != null) {
        regularAvatar = followerMatch['avatar'];
        googleAvatar = followerMatch['google_avatar'];
        debugPrint(
          'Found other user in followers list - avatar: $regularAvatar, google: $googleAvatar',
        );
      }
    }

    // Use AvatarUtils to determine the appropriate avatar image
    ImageProvider? avatarImage;

    // Check if regular avatar is valid first
    if (AvatarUtils.isValidUrl(regularAvatar)) {
      avatarImage = CachedNetworkImageProvider(regularAvatar!);
    }
    // If regular avatar is invalid, try Google avatar
    else if (AvatarUtils.isValidUrl(googleAvatar)) {
      avatarImage = CachedNetworkImageProvider(googleAvatar!);
    }

    // Has any valid avatar
    final bool hasAnyAvatar = avatarImage != null;

    // Check if message is read
    final bool isRead = widget.message['is_read'] == true;

    // Only show read status on sent messages
    final bool shouldShowStatus = widget.isMe;

    // Check if message is edited
    final bool isEdited =
        widget.message['updated_at'] != null &&
        widget.message['created_at'] != widget.message['updated_at'];

    // Check if this is an image upload placeholder
    final bool isPlaceholder = widget.message['is_placeholder'] == true;
    final String? uploadId = widget.message['upload_id']?.toString();

    // Check if the message contains an image
    final String messageContent = (widget.message['content'] ?? '').toString();
    final bool isImageMessage =
        widget.message['message_type'] == 'image' ||
        messageContent.startsWith('image:') ||
        (messageContent.startsWith('https://') &&
            (messageContent.contains('.jpg') ||
                messageContent.contains('.jpeg') ||
                messageContent.contains('.png') ||
                messageContent.contains('.gif')));

    // Extract image URL if message starts with image: prefix
    String? imageUrl;
    if (isImageMessage && !isPlaceholder) {
      if (messageContent.startsWith('image:')) {
        imageUrl = messageContent.substring(6); // Remove 'image:' prefix
      } else if (messageContent.startsWith('https://')) {
        imageUrl = messageContent;
      }
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(opacity: _opacityAnimation.value, child: child),
        );
      },
      child: GestureDetector(
        onLongPress:
            () =>
                isPlaceholder
                    ? null
                    : MessageOptions.show(context, widget.message, widget.isMe),
        child: Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Dismissible(
            key: Key(widget.message['message_id'] ?? DateTime.now().toString()),
            // Only show background when message is from the current user
            background:
                shouldShowStatus
                    ? Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      color: Colors.transparent,
                      child: Text(
                        isRead ? "Read" : "Sent",
                        style: TextStyle(
                          color: isRead ? Colors.blue.shade300 : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    : Container(color: Colors.transparent),
            // Swipe from right to left (Instagram style)
            direction:
                shouldShowStatus
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
            confirmDismiss: (_) async {
              // Don't actually dismiss, just show the status
              return false;
            },
            child: Stack(
              children: [
                // Message bubble with proper margin for avatar
                Container(
                  margin: EdgeInsets.only(
                    top: 15,
                    bottom: 8,
                    left: widget.isMe ? 8 : 24,
                    right: widget.isMe ? 24 : 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isMe ? Colors.blue : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isPlaceholder && uploadId != null)
                        _buildUploadingImageContent(uploadId, chatController)
                      else if (isImageMessage && imageUrl != null)
                        _buildImageContent(imageUrl)
                      else
                        FutureBuilder<String>(
                          future: chatController.getDecryptedMessageContent(
                            widget.message,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              // Show a loading indicator while decrypting
                              return const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              );
                            } else if (snapshot.hasError) {
                              // Show error if decryption fails
                              return Text(
                                '🔒 Error decrypting message',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            } else {
                              // Show decrypted content
                              return Text(
                                snapshot.data ??
                                    widget.message['content'] ??
                                    '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              );
                            }
                          },
                        ),
                      if (isEdited)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "Edited",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Avatar in top right/left corner
                Positioned(
                  top: 0,
                  right: widget.isMe ? 0 : null,
                  left: widget.isMe ? null : 0,
                  child: CircleAvatar(
                    radius: 12.5, // 25px diameter
                    backgroundColor: Colors.black,
                    backgroundImage: avatarImage,
                    child:
                        (!hasAnyAvatar)
                            ? const Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.white,
                            )
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build image content with thumbnail and preview capability
  Widget _buildImageContent(String imageUrl) {
    return GestureDetector(
      onTap: () => widget.onTapImage(widget.message),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message thumbnail with fixed dimensions
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 160,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                height: 160,
                width: 200,
                placeholder:
                    (context, url) => Center(
                      child: SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.red),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Tap to view text
          Text(
            'Tap to view',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Helper to build image upload placeholder with shimmer effect
  Widget _buildUploadingImageContent(
    String uploadId,
    ChatController controller,
  ) {
    return Obx(() {
      // Get current progress value (0.0 to 1.0)
      final progress = controller.localUploadProgress[uploadId] ?? 0.0;
      final progressPercent = (progress * 100).toInt();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shimmer placeholder with fixed dimensions
          Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            child: Container(
              height: 160,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Progress indicator
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade300,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progressPercent%',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
              ),
            ],
          ),
        ],
      );
    });
  }
}

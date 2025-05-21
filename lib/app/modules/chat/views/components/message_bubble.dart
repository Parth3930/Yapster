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
  final void Function(String messageId)? onAnimationComplete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserId,
    required this.onTapImage,
    required this.onAnimationComplete,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  late final AccountDataProvider _accountDataProvider;
  late final ChatController _chatController;

  late final bool _isNew;
  late final bool _isSending;

  late final String _messageContent;
  late final bool _isImageMessage;
  late final String? _imageUrl;
  late final bool _isPlaceholder;
  late final String? _uploadId;
  late final bool _isEdited;
  late final bool _isRead;
  late final bool _shouldShowStatus;

  late final ImageProvider? _avatarImage;
  late final bool _hasAnyAvatar;

  @override
  void initState() {
    super.initState();

    _accountDataProvider = Get.find<AccountDataProvider>();
    _chatController = Get.find<ChatController>();

    _isNew = widget.message['is_new'] == true;
    _isSending = widget.message['is_sending'] == true;

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

    if (_isNew || _isSending) {
      _controller.forward();
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Removed setState call
          // setState(() {
          //   widget.message['is_new'] = false;
          // });
          widget.onAnimationComplete?.call(widget.message['message_id']);
        }
      });
    } else {
      _controller.value = 1.0;
    }

    // Initialize all computed fields here for efficiency

    _messageContent = (widget.message['content'] ?? '').toString();

    _isPlaceholder = widget.message['is_placeholder'] == true;
    _uploadId = widget.message['upload_id']?.toString();

    _isImageMessage =
        widget.message['message_type'] == 'image' ||
        _messageContent.startsWith('image:') ||
        (_messageContent.startsWith('https://') &&
            (_messageContent.contains('.jpg') ||
                _messageContent.contains('.jpeg') ||
                _messageContent.contains('.png') ||
                _messageContent.contains('.gif')));

    if (_isImageMessage && !_isPlaceholder) {
      if (_messageContent.startsWith('image:')) {
        _imageUrl = _messageContent.substring(6);
      } else if (_messageContent.startsWith('https://')) {
        _imageUrl = _messageContent;
      } else {
        _imageUrl = null;
      }
    } else {
      _imageUrl = null;
    }

    _isEdited =
        widget.message['updated_at'] != null &&
        widget.message['created_at'] != widget.message['updated_at'];

    _isRead = widget.message['is_read'] == true;
    _shouldShowStatus = widget.isMe;

    // Avatar logic
    String? regularAvatar;
    String? googleAvatar;

    if (widget.isMe) {
      regularAvatar = _accountDataProvider.avatar.value;
      googleAvatar = _accountDataProvider.googleAvatar.value;
    } else {
      final followingMatch = _accountDataProvider.following.firstWhereOrNull(
        (f) => f['following_id'] == widget.otherUserId,
      );
      final followerMatch = _accountDataProvider.followers.firstWhereOrNull(
        (f) => f['follower_id'] == widget.otherUserId,
      );

      if (followingMatch != null) {
        regularAvatar = followingMatch['avatar'];
        googleAvatar = followingMatch['google_avatar'];
      } else if (followerMatch != null) {
        regularAvatar = followerMatch['avatar'];
        googleAvatar = followerMatch['google_avatar'];
      }
    }

    if (AvatarUtils.isValidUrl(regularAvatar)) {
      _avatarImage = CachedNetworkImageProvider(regularAvatar!);
    } else if (AvatarUtils.isValidUrl(googleAvatar)) {
      _avatarImage = CachedNetworkImageProvider(googleAvatar!);
    } else {
      _avatarImage = null;
    }

    _hasAnyAvatar = _avatarImage != null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the message is now marked as new and was not new before
    final bool wasNew = oldWidget.message['is_new'] == true;
    final bool isNew = widget.message['is_new'] == true;

    if (isNew && !wasNew) {
      // Start the animation if the message just became new
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _isPlaceholder
                ? null
                : () =>
                    MessageOptions.show(context, widget.message, widget.isMe),
        child: Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Dismissible(
            key: Key(widget.message['message_id'] ?? DateTime.now().toString()),
            background:
                _shouldShowStatus
                    ? Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      color: Colors.transparent,
                      child: Text(
                        _isRead ? "Read" : "Sent",
                        style: TextStyle(
                          color: _isRead ? Colors.blue.shade300 : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    : Container(color: Colors.transparent),
            direction:
                _shouldShowStatus
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
            confirmDismiss: (_) async => false,
            child: Stack(
              children: [
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
                      if (_isPlaceholder && _uploadId != null)
                        _buildUploadingImageContent(_uploadId, _chatController)
                      else if (_isImageMessage && _imageUrl != null)
                        _buildImageContent(_imageUrl)
                      else
                        Text(
                          widget.message['content'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      if (_isEdited)
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
                Positioned(
                  top: 0,
                  right: widget.isMe ? 0 : null,
                  left: widget.isMe ? null : 0,
                  child: CircleAvatar(
                    radius: 12.5,
                    backgroundColor: Colors.black,
                    backgroundImage: _avatarImage,
                    child:
                        !_hasAnyAvatar
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

  Widget _buildImageContent(String imageUrl) {
    return GestureDetector(
      onTap: () => widget.onTapImage(widget.message),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 160,
              width: 200,
              color: Colors.grey.shade900,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
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
          Text(
            'Tap to view',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingImageContent(
    String uploadId,
    ChatController controller,
  ) {
    return Obx(() {
      final progress = controller.localUploadProgress[uploadId] ?? 0.0;
      final progressPercent = (progress * 100).toInt();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
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

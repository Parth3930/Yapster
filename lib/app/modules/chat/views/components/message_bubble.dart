import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/animations/message_animations.dart';
import 'package:yapster/app/modules/chat/views/components/audio_message.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';
import '../../controllers/chat_controller.dart';
import '../message_options.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String otherUserId;
  final Function(Map<String, dynamic>) onTapImage;
  final void Function(String messageId)? onAnimationComplete;
  final void Function(String messageId)? onDeleteAnimationComplete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserId,
    required this.onTapImage,
    required this.onAnimationComplete,
    this.onDeleteAnimationComplete,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  // Smooth animation controllers
  MessageAnimationController? _entryController;
  MessageAnimationController? _exitController;
  MessageAnimationController? _pressController;

  bool _isPressed = false;
  bool _hasEntryAnimationStarted = false;

  late final AccountDataProvider _accountDataProvider;
  late final ChatController _chatController;

  // Cached message properties
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
  late final bool _isAudioMessage;
  late final bool _isSharedPost;
  late final Map<String, dynamic>? _sharedPostData;
  late final ImageProvider? _avatarImage;
  late final bool _hasAnyAvatar;
  late final String _messageId;

  @override
  void initState() {
    super.initState();

    _accountDataProvider = Get.find<AccountDataProvider>();
    _chatController = Get.find<ChatController>();

    _initializeMessageProperties();
    _initializeAnimations();
  }

  void _initializeMessageProperties() {
    _messageId = widget.message['message_id']?.toString() ?? '';
    _isNew = widget.message['is_new'] == true;
    _isSending = widget.message['is_sending'] == true;
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

    _isAudioMessage =
        widget.message['message_type'] ==
        'audio'; // New property initialization

    // Check if this is a shared post
    _isSharedPost = _isSharedPostMessage(_messageContent);
    if (_isSharedPost) {
      try {
        _sharedPostData = jsonDecode(_messageContent);
      } catch (e) {
        _isSharedPost = false;
        _sharedPostData = null;
      }
    } else {
      _sharedPostData = null;
    }

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

    _initializeAvatar();
  }

  void _initializeAvatar() {
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

  void _initializeAnimations() {
    // Initialize press animation controller (always available)
    _pressController = MessageAnimationController(
      config: MessageAnimationConfig.tapBounce(),
      vsync: this,
    );

    // Initialize entry animation if message is new
    if (_isNew || _isSending) {
      _entryController = MessageAnimationController(
        config: MessageAnimationUtils.getSendAnimation(widget.isMe),
        vsync: this,
      );

      _entryController!.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete?.call(_messageId);
        }
      });

      // Start entry animation with slight delay for natural feel
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && !_hasEntryAnimationStarted) {
            _hasEntryAnimationStarted = true;
            _entryController!.forward();
          }
        });
      });
    }
  }

  void _initializeExitAnimation() {
    if (_exitController == null) {
      _exitController = MessageAnimationController(
        config: MessageAnimationUtils.getDeleteAnimation(widget.isMe),
        vsync: this,
      );

      _exitController!.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDeleteAnimationComplete?.call(_messageId);
        }
      });
    }
  }

  bool get _isDeleting {
    return _chatController.deletingMessageId.value == _messageId;
  }

  @override
  void dispose() {
    _entryController?.dispose();
    _exitController?.dispose();
    _pressController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle new message animation
    final bool wasNew = oldWidget.message['is_new'] == true;
    final bool isNew = widget.message['is_new'] == true;

    if (isNew &&
        !wasNew &&
        _entryController != null &&
        !_hasEntryAnimationStarted) {
      _hasEntryAnimationStarted = true;
      _entryController!.reset();
      _entryController!.forward();
    }
  }

  void _handlePressDown() {
    if (!_isPlaceholder && !_isDeleting && !_isPressed) {
      _isPressed = true;
      _pressController?.forward();
    }
  }

  void _handlePressUp() {
    if (_isPressed) {
      _isPressed = false;
      _pressController?.reverse();
    }
  }

  void _handlePressCancel() {
    if (_isPressed) {
      _isPressed = false;
      _pressController?.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Check if this message should be deleted and start exit animation
      final isDeleting = _isDeleting;
      if (isDeleting && _exitController == null) {
        _initializeExitAnimation();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _exitController?.forward();
        });
      }

      return _buildFluidAnimatedMessage(isDeleting);
    });
  }

  Widget _buildFluidAnimatedMessage(bool isDeleting) {
    Widget messageWidget = _buildMessageContent();

    // Apply exit animation if deleting
    if (isDeleting && _exitController != null) {
      messageWidget = AnimatedBuilder(
        animation: _exitController!.controller,
        builder: (context, child) {
          final t = _exitController!.controller.value;
          final baseOffset =
              _exitController!.slideValue * MediaQuery.of(context).size.width;
          // Parabola: y = -4a(x-0.5)^2 + a, but normalize so y=0 at t=1
          final a = 30.0;
          final parabolaY =
              (-4 * a * (t - 0.5) * (t - 0.5) + a) -
              (-4 * a * (1 - 0.5) * (1 - 0.5) + a);
          final offset = Offset(baseOffset.dx, baseOffset.dy + parabolaY);
          final opacity = _exitController!.opacityValue.clamp(0.0, 1.0);
          return Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: _exitController!.scaleValue,
              child: Opacity(opacity: opacity, child: child),
            ),
          );
        },
        child: messageWidget,
      );
    }
    // Apply entry animation if new message
    else if ((_isNew || _isSending) && _entryController != null) {
      messageWidget = AnimatedBuilder(
        animation: _entryController!.controller,
        builder: (context, child) {
          final t = _entryController!.controller.value;
          final baseOffset =
              _entryController!.slideValue * MediaQuery.of(context).size.width;
          final a = 30.0;
          final parabolaY =
              (-4 * a * (t - 0.5) * (t - 0.5) + a) -
              (-4 * a * (1 - 0.5) * (1 - 0.5) + a);
          final offset = Offset(baseOffset.dx, baseOffset.dy + parabolaY);
          final opacity = _entryController!.opacityValue.clamp(0.0, 1.0);
          return Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: _entryController!.scaleValue,
              child: Opacity(opacity: opacity, child: child),
            ),
          );
        },
        child: messageWidget,
      );
    }

    // Apply press animation (scale down on press)
    if (_pressController != null) {
      messageWidget = AnimatedBuilder(
        animation: _pressController!.controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _pressController!.scaleValue,
            child: child,
          );
        },
        child: messageWidget,
      );
    }

    return messageWidget;
  }

  Widget _buildMessageContent() {
    return GestureDetector(
      onTapDown: (_) => _handlePressDown(),
      onTapUp: (_) => _handlePressUp(),
      onTapCancel: _handlePressCancel,
      onLongPress:
          _isPlaceholder
              ? null
              : () {
                _handlePressCancel();
                MessageOptions.show(context, widget.message, widget.isMe);
              },
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Dismissible(
          key: Key(
            _messageId.isNotEmpty ? _messageId : DateTime.now().toString(),
          ),
          background:
              _shouldShowStatus
                  ? Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    color: Colors.transparent,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: _isRead ? Colors.blue.shade300 : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Text(_isRead ? "Read" : "Sent"),
                    ),
                  )
                  : Container(color: Colors.transparent),
          direction:
              _shouldShowStatus
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
          confirmDismiss: (_) async => false,
          child: _buildMessageBubble(),
        ),
      ),
    );
  }

  Widget _buildMessageBubble() {
    // For audio messages, render just the audio player without the bubble
    if (_isAudioMessage) {
      return Container(
        margin: EdgeInsets.only(
          top: 15,
          bottom: 8,
          left: widget.isMe ? 8 : 24,
          right: widget.isMe ? 24 : 8,
        ),
        child: _buildAudioMessage(),
      );
    }

    // For shared posts, render directly without bubble wrapper
    if (_isSharedPost) {
      return Container(
        margin: EdgeInsets.only(
          top: 15,
          bottom: 8,
          left: widget.isMe ? 8 : 24,
          right: widget.isMe ? 24 : 8,
        ),
        child: _buildSharedPostContent(),
      );
    }

    // For all other message types, use the bubble container
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(
            top: 15,
            bottom: 8,
            left: widget.isMe ? 8 : 24,
            right: widget.isMe ? 24 : 8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isMe ? Colors.blue : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                blurRadius: 4,
                offset: const Offset(0, 2),
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
                  _messageContent,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              if (_isEdited)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 0.7,
                    child: const Text(
                      "Edited",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Avatar with subtle animation
        Positioned(
          top: 0,
          right: widget.isMe ? 0 : null,
          left: widget.isMe ? null : 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: CircleAvatar(
              radius: 12.5,
              backgroundColor: Colors.black,
              backgroundImage: _avatarImage,
              child:
                  !_hasAnyAvatar
                      ? const Icon(Icons.person, size: 12, color: Colors.white)
                      : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioMessage() {
    final audioUrl = _messageContent;
    final messageId = _messageId;
    final isMe = widget.isMe;
    final duration =
        widget.message['duration_seconds'] != null
            ? Duration(seconds: widget.message['duration_seconds'] as int)
            : null;

    return AudioMessage(
      url: audioUrl,
      messageId: messageId,
      isMe: isMe,
      duration: duration,
    );
  }

  Widget _buildImageContent(String? imageUrl) {
    if (_isPlaceholder) {
      // Show loading state for image upload
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading image...',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width * 0.2,
        maxHeight: 200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => widget.onTapImage(widget.message),
          child: CachedNetworkImage(
            imageUrl: imageUrl ?? '',
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[900]!,
                  highlightColor: Colors.grey[800]!,
                  child: Container(color: Colors.grey[900]),
                ),
            errorWidget:
                (context, url, error) =>
                    const Icon(Icons.error, color: Colors.red),
          ),
        ),
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
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
              maxHeight: 200,
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade800,
              highlightColor: Colors.grey.shade700,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading image...',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                child: Text('$progressPercent%'),
              ),
            ],
          ),
        ],
      );
    });
  }

  // Helper method to check if a message is a shared post
  bool _isSharedPostMessage(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> &&
          decoded['type'] == 'shared_post';
    } catch (e) {
      return false;
    }
  }

  // Build shared post content widget
  Widget _buildSharedPostContent() {
    if (_sharedPostData == null) {
      return Text(
        'Shared post (error loading)',
        style: TextStyle(color: Colors.white, fontSize: 16),
      );
    }

    final postData = _sharedPostData;
    final content = postData['content']?.toString() ?? '';
    final imageUrl = postData['image_url']?.toString();
    final authorNickname =
        postData['author_nickname']?.toString() ??
        postData['author_username']?.toString() ??
        'Yapper';
    final authorAvatar = postData['author_avatar']?.toString();

    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _navigateToPost(postData['post_id']?.toString()),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        height:
            hasImage
                ? 500
                : null, // Fixed height for image posts, dynamic for text posts
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: hasImage ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Post image with profile overlay (if image exists)
            if (hasImage)
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        height: double.infinity,
                        width: double.infinity,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey[800],
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey[600]!,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: Icon(Icons.error, color: Colors.grey[600]),
                            ),
                      ),
                    ),
                    // Profile overlay on top of image
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image:
                                    authorAvatar != null &&
                                            authorAvatar.isNotEmpty
                                        ? DecorationImage(
                                          image: NetworkImage(authorAvatar),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  authorAvatar == null || authorAvatar.isEmpty
                                      ? Icon(
                                        Icons.person,
                                        size: 12,
                                        color: Colors.white,
                                      )
                                      : null,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                authorNickname,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Post header for non-image posts
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[800],
                      backgroundImage:
                          authorAvatar != null && authorAvatar.isNotEmpty
                              ? NetworkImage(authorAvatar)
                              : null,
                      child:
                          authorAvatar == null || authorAvatar.isEmpty
                              ? Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey[600],
                              )
                              : null,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authorNickname,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Post content
            if (content.isNotEmpty)
              hasImage
                  ? Expanded(
                    flex: 1,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        content,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  : Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      content,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),

            // Post interaction buttons
            _buildPostInteractionButtons(),
          ],
        ),
      ),
    );
  }

  // Build post interaction buttons
  Widget _buildPostInteractionButtons() {
    if (_sharedPostData == null) return SizedBox.shrink();

    try {
      // Create a PostModel from the shared post data
      final postData = _sharedPostData;
      final postModel = PostModel(
        id: postData['post_id']?.toString() ?? '',
        userId: postData['author_id']?.toString() ?? '',
        content: postData['content']?.toString() ?? '',
        postType: 'text', // Default to text, could be enhanced
        imageUrl: postData['image_url']?.toString(),
        username: postData['author_username']?.toString(),
        nickname: postData['author_nickname']?.toString(),
        avatar: postData['author_avatar']?.toString(),
        createdAt:
            DateTime.tryParse(postData['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.now(),
        metadata:
            postData['video_url'] != null
                ? {'video_url': postData['video_url']}
                : {},
      );

      // Get or create PostsFeedController
      PostsFeedController controller;
      try {
        controller = Get.find<PostsFeedController>();
      } catch (e) {
        controller = PostsFeedController();
        Get.put(controller);
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: PostInteractionButtons(
          post: postModel,
          controller: controller,
          glassy: false, // Use solid buttons for better visibility in chat
        ),
      );
    } catch (e) {
      debugPrint('Error building post interaction buttons: $e');
      return SizedBox.shrink();
    }
  }

  // Navigate to the original post
  void _navigateToPost(String? postId) {
    if (postId != null && postId.isNotEmpty) {
      try {
        // Navigate to home with post ID as argument to scroll to specific post
        Get.toNamed('/home', arguments: {'scrollToPostId': postId});
      } catch (e) {
        debugPrint('Error navigating to post: $e');
        // Fallback to just going to home
        Get.toNamed('/home');
      }
    }
  }
}

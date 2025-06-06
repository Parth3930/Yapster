import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/controllers/group_controller.dart';
import 'package:yapster/app/modules/chat/services/chat_message_service.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/models/group_model.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';

class EnhancedShareDialog extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onShareComplete;

  const EnhancedShareDialog({
    super.key,
    required this.post,
    this.onShareComplete,
  });

  @override
  State<EnhancedShareDialog> createState() => _EnhancedShareDialogState();
}

class _EnhancedShareDialogState extends State<EnhancedShareDialog> {
  late PageController pageController;
  final RxInt currentPage = 0.obs;
  final RxBool showGroups = false.obs;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChatController chatController = Get.find<ChatController>();

    // Get or create GroupController
    GroupController groupController;
    try {
      groupController = Get.find<GroupController>();
    } catch (e) {
      groupController = GroupController();
      Get.put(groupController);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.transparent.withValues(alpha: 0.7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Send to',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // Toggle between chats and groups
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Obx(
                    () => GestureDetector(
                      onTap: () => showGroups.value = false,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              !showGroups.value
                                  ? Colors.blue
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Chats',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  !showGroups.value
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(
                    () => GestureDetector(
                      onTap: () => showGroups.value = true,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              showGroups.value
                                  ? Colors.blue
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Groups',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  showGroups.value
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content area (chats or groups)
          Expanded(
            child: Obx(() {
              if (showGroups.value) {
                // Show groups
                if (groupController.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.red[300]!,
                      ),
                    ),
                  );
                }

                if (groupController.groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          color: Colors.grey[600],
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No groups',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a group to share posts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Show groups grid
                final totalPages = (groupController.groups.length / 8).ceil();
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: totalPages,
                          onPageChanged: (page) => currentPage.value = page,
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * 8;
                            final endIndex = (startIndex + 8).clamp(
                              0,
                              groupController.groups.length,
                            );
                            final pageGroups = groupController.groups.sublist(
                              startIndex,
                              endIndex,
                            );

                            return GridView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: 0.8,
                                  ),
                              itemCount: pageGroups.length,
                              itemBuilder: (context, index) {
                                final group = pageGroups[index];
                                return _buildGroupTile(group);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    // Page indicators for groups
                    if (totalPages > 1)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(totalPages, (index) {
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    currentPage.value == index
                                        ? Colors.white
                                        : Colors.grey[600],
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                );
              } else {
                // Show chats
                if (chatController.isLoadingChats.value) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.red[300]!,
                      ),
                    ),
                  );
                }

                if (chatController.recentChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[600],
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No recent chats',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start a conversation to share posts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final totalPages =
                    (chatController.recentChats.length / 8).ceil();

                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: totalPages,
                          onPageChanged: (page) => currentPage.value = page,
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * 8;
                            final endIndex = (startIndex + 8).clamp(
                              0,
                              chatController.recentChats.length,
                            );
                            final pageChats = chatController.recentChats
                                .sublist(startIndex, endIndex);

                            return GridView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: 0.8,
                                  ),
                              itemCount: pageChats.length,
                              itemBuilder: (context, index) {
                                final chat = pageChats[index];
                                return _buildUserTile(chat);
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    // Page indicators
                    if (totalPages > 1)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Obx(
                          () => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(totalPages, (index) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      currentPage.value == index
                                          ? Colors.white
                                          : Colors.grey[600],
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                );
              }
            }),
          ),

          // Social media sharing options
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.blue,
                  onTap: () => _handleMoreShare(),
                ),
                _buildSocialButton(
                  icon: Icons.content_copy,
                  label: 'Copy',
                  color: Colors.grey,
                  onTap: () => _handleCopyLink(),
                ),
                _buildSocialButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Color(0xFF25D366),
                  onTap: () => _handleWhatsAppShare(),
                ),
                _buildSocialButton(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  color: Color(0xFFE4405F),
                  onTap: () => _handleInstagramShare(),
                ),
                _buildSocialButton(
                  icon: Icons.camera,
                  label: 'Snapchat',
                  color: Color(0xFFFFFC00),
                  onTap: () => _handleSnapchatShare(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> chat) {
    final username = chat['other_username'] ?? 'User';
    final userId = chat['other_id'] ?? '';
    final avatar = chat['other_avatar'] ?? '';
    final googleAvatar = chat['other_google_avatar'] ?? '';

    // Determine which avatar to show
    String? displayAvatar;
    if (avatar == 'skiped' || avatar.isEmpty) {
      displayAvatar = googleAvatar.isNotEmpty ? googleAvatar : null;
    } else {
      displayAvatar = avatar.isNotEmpty ? avatar : null;
    }

    return GestureDetector(
      onTap: () => _shareWithUser(userId, username),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage:
                  displayAvatar != null ? NetworkImage(displayAvatar) : null,
              child:
                  displayAvatar == null
                      ? Icon(Icons.person, color: Colors.grey[600], size: 30)
                      : null,
            ),
          ),
          SizedBox(height: 8),
          Text(
            username,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    IconData? icon,
    String? assetPath,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? Colors.grey[800],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child:
                icon != null
                    ? Icon(
                      icon,
                      color: label == 'Snapchat' ? Colors.black : Colors.white,
                      size: 24,
                    )
                    : assetPath != null
                    ? ClipOval(
                      child: Image.asset(
                        assetPath,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 24,
                          );
                        },
                      ),
                    )
                    : Icon(Icons.share, color: Colors.white, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Share post with specific user
  Future<void> _shareWithUser(String userId, String username) async {
    try {
      // Close the share dialog
      Get.back();

      // Ensure ChatMessageService is available
      ChatMessageService chatMessageService;
      try {
        chatMessageService = Get.find<ChatMessageService>();
      } catch (e) {
        debugPrint('ChatMessageService not found, registering it now');
        chatMessageService = ChatMessageService();
        Get.put(chatMessageService);
      }

      // Get the chat controller
      ChatController chatController;
      try {
        chatController = Get.find<ChatController>();
      } catch (e) {
        debugPrint('ChatController not found, registering it now');
        chatController = ChatController();
        Get.put(chatController);
      }

      // Create or get existing chat
      final supabaseService = Get.find<SupabaseService>();
      final currentUserId = supabaseService.client.auth.currentUser?.id;

      if (currentUserId == null) {
        Get.snackbar(
          'Error',
          'You need to be logged in to share posts',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Get or create chat ID
      final chatId = await supabaseService.client.rpc(
        'user_chat_connect',
        params: {'user_one': currentUserId, 'user_two': userId},
      );

      if (chatId != null && chatId is String && chatId.isNotEmpty) {
        // Create share message with post data for in-app display
        final shareMessage = {
          'type': 'shared_post',
          'post_id': widget.post.id,
          'author_id': widget.post.userId,
          'content': widget.post.content,
          'image_url': widget.post.imageUrl,
          'video_url': widget.post.metadata['video_url'],
          'author_username': widget.post.username,
          'author_nickname': widget.post.nickname,
          'author_avatar': widget.post.avatar,
          'created_at': widget.post.createdAt.toIso8601String(),
        };

        // Convert to JSON string for storage
        final shareMessageJson = jsonEncode(shareMessage);

        // Ensure the chat message service is initialized
        if (!chatMessageService.isInitialized.value) {
          await chatMessageService.initialize(
            messagesList: chatController.messages,
            chatsList: chatController.recentChats,
            uploadProgress: chatController.localUploadProgress,
          );
        }

        // Send the message
        await chatController.sendChatMessage(chatId, shareMessageJson);

        // Increment share count only when actually shared to someone
        try {
          final postsFeedController = Get.find<PostsFeedController>();
          await postsFeedController.updatePostEngagement(
            widget.post.id,
            'shares',
            1,
          );
        } catch (e) {
          debugPrint('Error updating share count: $e');
        }

        // Call completion callback
        if (widget.onShareComplete != null) {
          widget.onShareComplete!();
        }
      } else {
        throw Exception('Failed to create or get chat');
      }
    } catch (e) {
      debugPrint('Error sharing post: $e');
      Get.snackbar(
        'Error',
        'Failed to share post. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _handleMoreShare() {
    Get.back();
    // Implement more share options
    Get.snackbar('Share', 'More sharing options coming soon');
  }

  void _handleCopyLink() {
    Get.back();
    // Implement copy link functionality
    Get.snackbar('Copied', 'Post link copied to clipboard');
  }

  void _handleWhatsAppShare() {
    Get.back();
    // Implement WhatsApp share
    Get.snackbar('WhatsApp', 'WhatsApp sharing coming soon');
  }

  void _handleInstagramShare() {
    Get.back();
    // Implement Instagram share
    Get.snackbar('Instagram', 'Instagram sharing coming soon');
  }

  void _handleSnapchatShare() {
    Get.back();
    // Implement Snapchat share
    Get.snackbar('Snapchat', 'Snapchat sharing coming soon');
  }

  // Share post with specific group
  Future<void> _shareWithGroup(String groupId, String groupName) async {
    try {
      // Close the share dialog
      Get.back();

      // Get the group controller
      GroupController groupController;
      try {
        groupController = Get.find<GroupController>();
      } catch (e) {
        debugPrint('GroupController not found, registering it now');
        groupController = GroupController();
        Get.put(groupController);
      }

      // Create share message with post data for in-app display
      final shareMessage = {
        'type': 'shared_post',
        'post_id': widget.post.id,
        'author_id': widget.post.userId,
        'content': widget.post.content,
        'image_url': widget.post.imageUrl,
        'video_url': widget.post.metadata['video_url'],
        'author_username': widget.post.username,
        'author_nickname': widget.post.nickname,
        'author_avatar': widget.post.avatar,
        'created_at': widget.post.createdAt.toIso8601String(),
      };

      // Convert to JSON string for storage
      final shareMessageJson = jsonEncode(shareMessage);

      // Send the message to group
      await groupController.sendGroupMessage(
        groupId: groupId,
        content: shareMessageJson,
        messageType: 'shared_post',
      );

      // Increment share count only when actually shared to someone
      try {
        final postsFeedController = Get.find<PostsFeedController>();
        await postsFeedController.updatePostEngagement(
          widget.post.id,
          'shares',
          1,
        );
      } catch (e) {
        debugPrint('Error updating share count: $e');
      }

      // Call completion callback
      if (widget.onShareComplete != null) {
        widget.onShareComplete!();
      }

      // Success notification removed as requested
    } catch (e) {
      debugPrint('Error sharing post to group: $e');
      Get.snackbar(
        'Error',
        'Failed to share post to group. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildGroupTile(GroupModel group) {
    return GestureDetector(
      onTap: () => _shareWithGroup(group.id, group.name),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.black,
              backgroundImage:
                  group.iconUrl != null && group.iconUrl!.isNotEmpty
                      ? NetworkImage(group.iconUrl!)
                      : null,
              child:
                  group.iconUrl == null || group.iconUrl!.isEmpty
                      ? Text(
                        'YAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
          ),
          SizedBox(height: 8),
          Text(
            group.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

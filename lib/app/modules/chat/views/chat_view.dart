import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../controllers/chat_controller.dart';

class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.recentChats.isEmpty) {
        controller.fetchUsersRecentChats();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "YapChat",
              style: TextStyle(
                color: Colors.white,
                fontFamily: GoogleFonts.dongle().fontFamily,
                fontSize: 38,
              ),
            ),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFf171717),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Image.asset(
                      "assets/icons/add_friend.png",
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFf171717),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  width: 36,
                  height: 36,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search for Yappers',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF171717),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Pull to refresh for chat list
          Expanded(
            child: Obx(() {
              // Show loading indicator when loading and no cached data
              if (controller.isLoadingChats.value &&
                  controller.recentChats.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              // Show search results if search is active
              if (controller.searchQuery.isNotEmpty) {
                return _buildSearchResults();
              }

              // Show RefreshIndicator for pull-to-refresh with chat list
              return RefreshIndicator(
                onRefresh: () async {
                  debugPrint('Manual refresh triggered');
                  await controller.fetchUsersRecentChats();
                },
                child: _buildRecentChats(),
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }

  Widget _buildSearchResults() {
    if (controller.searchResults.isEmpty) {
      return const Center(child: Text("No users found"));
    }

    return ListView.builder(
      itemCount: controller.searchResults.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final user = controller.searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildRecentChats() {
    debugPrint('Building recent chats: ${controller.recentChats.length} items');

    if (controller.isLoadingChats.value && controller.recentChats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.recentChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No chats yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Search for users to start a conversation",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controller.fetchUsersRecentChats(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(Get.context!).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("Refresh"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Get.toNamed('/explore'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(Get.context!).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("Find people to chat with"),
            ),
          ],
        ),
      );
    }

    final currentUserId = controller.supabaseService.currentUser.value?.id;

    return ListView.builder(
      itemCount: controller.recentChats.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final chat = controller.recentChats[index];

        // Create a temporary provider just for avatar display
        final tempProvider = AccountDataProvider();

        // Properly handle avatars with prioritization of Google avatar when regular avatar is missing
        String? profileAvatar = chat['other_avatar'];
        String? googleAvatar = chat['other_google_avatar'];

        if (profileAvatar == null ||
            profileAvatar.isEmpty ||
            profileAvatar == "skiped") {
          tempProvider.googleAvatar.value = googleAvatar ?? '';
        } else {
          tempProvider.avatar.value = profileAvatar;
        }

        // Check if this user sent the last message
        final bool didUserSendLastMessage =
            chat['last_sender_id'] == currentUserId;

        // Get the unread count
        final int unreadCount = chat['unread_count'] ?? 0;

        // Format message preview with sent/received prefix
        final String messagePreview;
        if (chat['last_message'] == null ||
            chat['last_message'].toString().isEmpty) {
          messagePreview = "No messages yet - tap to start chatting";
        } else if (chat['last_message'].toString().length > 15) {
          // For long messages, just show a generic indication instead of the content
          messagePreview =
              didUserSendLastMessage
                  ? "You sent a message"
                  : "You received a message";
        } else {
          // For short messages, show the content with prefix
          messagePreview =
              didUserSendLastMessage
                  ? "Sent: ${chat['last_message']}"
                  : "Received: ${chat['last_message']}";
        }

        return ListTile(
          leading: GestureDetector(
            onTap:
                () => Get.toNamed(
                  '/profile',
                  arguments: {'userId': chat['other_id']},
                ),
            child: AvatarUtils.getAvatarWidget(null, tempProvider, radius: 24),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chat['other_username'] ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // Show unread indicator if messages are unread
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  messagePreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        didUserSendLastMessage
                            ? Colors.grey
                            : Colors.grey.shade700,
                    fontWeight:
                        !didUserSendLastMessage && unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                  ),
                ),
              ),
              if (chat['last_message_time'] != null)
                Text(
                  _formatTimestamp(chat['last_message_time']),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          onTap:
              () => controller.openChat(
                chat['other_user_id'],
                chat['other_username'] ?? 'User',
              ),
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId =
        user['user_id'] ?? user['follower_id'] ?? user['following_id'];
    final username = user['username'] ?? 'User';
    final userSource = user['source'];

    // Create a temporary provider just for avatar display
    final tempProvider = AccountDataProvider();

    // Properly handle avatars with prioritization of Google avatar when regular avatar is missing
    String? profileAvatar = user['avatar'];
    String? googleAvatar = user['google_avatar'];

    if (profileAvatar == null ||
        profileAvatar.isEmpty ||
        profileAvatar == "skiped") {
      tempProvider.googleAvatar.value = googleAvatar ?? '';
    } else {
      tempProvider.avatar.value = profileAvatar;
    }

    return ListTile(
      leading: GestureDetector(
        onTap: () => Get.toNamed('/profile', arguments: {'userId': userId}),
        child: AvatarUtils.getAvatarWidget(null, tempProvider, radius: 24),
      ),
      title: Row(
        children: [
          Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (userSource != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: userSource == 'following' ? Colors.blue : Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                userSource == 'following' ? 'Following' : 'Follower',
                style: TextStyle(
                  fontSize: 10,
                  color: userSource == 'following' ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(user['nickname'] ?? ''),
      onTap: () => controller.openChat(userId, username),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final messageTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(messageTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }
}

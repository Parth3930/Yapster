import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import '../controllers/chat_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatDetailView extends GetView<ChatController> {
  const ChatDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    // Get arguments passed to this route
    final args = Get.arguments as Map<String, dynamic>;
    final String chatId = args['chat_id'] as String;
    final String otherUserId = args['other_user_id'] as String;
    final String username = args['username'] as String;
    
    // Load messages if not already loaded
    if (controller.selectedChatId.value != chatId) {
      controller.selectedChatId.value = chatId;
      controller.loadMessages(chatId);
    }
    
    // Mark messages as read when chat is opened
    controller.markMessagesAsRead(chatId);
    
    return Scaffold(
      backgroundColor: Colors.black, // Set black background
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Lock icon for encryption
          IconButton(
            icon: const Icon(Icons.lock, color: Colors.white),
            onPressed: () => _showEncryptionDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat countdown timer - shows how long until messages expire
          Obx(() => _buildChatTimerBanner()),
          
          // Messages list
          Expanded(
            child: Obx(() {
              if (controller.isSendingMessage.value && controller.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              
              return _buildMessagesList();
            }),
          ),
          
          // Message input
          _buildMessageInput(chatId),
        ],
      ),
    );
  }
  
  // Show encryption information dialog
  void _showEncryptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  "End-to-End Encrypted",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Your messages are secured with end-to-end encryption. This means only you and the recipient can read them. No one else, not even Yapster, can access your private conversations.",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Encryption is active on this chat",
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: const Text("GOT IT"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildChatTimerBanner() {
    // Check if user has already dismissed the banner
    if (controller.hasUserDismissedExpiryBanner.value) {
      return const SizedBox.shrink(); // Don't show banner if dismissed
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.amber.withOpacity(0.2),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Messages will disappear after 24 hours',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => controller.dismissExpiryBanner(),
            child: const Icon(Icons.check_circle_outline, color: Colors.amber, size: 16),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
        ],
      ),
    );
  }
  
  Widget _buildMessagesList() {
    if (controller.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
    // Get arguments to determine the other user
    final args = Get.arguments as Map<String, dynamic>;
    final String otherUserId = args['other_user_id'] as String;
    
    // Always operate on a new list to force UI refresh
    final sortedMessages = List<Map<String, dynamic>>.from(controller.messages)
      ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 8),
      itemCount: sortedMessages.length,
      reverse: true, // Show messages from bottom up
      itemBuilder: (context, index) {
        final message = sortedMessages[index];
        final isMe = message['sender_id'] == currentUserId;
        
        return _buildMessageBubble(message, isMe, otherUserId);
      },
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, String otherUserId) {
    final SupabaseService supabaseService = Get.find<SupabaseService>();
    final currentUser = supabaseService.currentUser.value;
    final AccountDataProvider accountDataProvider = Get.find<AccountDataProvider>();
    
    // Get the appropriate avatar URL
    String? avatarUrl;
    
    if (isMe && currentUser != null) {
      // This is the current user's message - use their avatar
      avatarUrl = accountDataProvider.avatar.value.isNotEmpty ? 
                 accountDataProvider.avatar.value : 
                 accountDataProvider.googleAvatar.value;
    } else {
      // For other user's avatar, look in the following or followers list
      final followingMatch = accountDataProvider.following
          .firstWhereOrNull((f) => f['following_id'] == otherUserId);
          
      final followerMatch = accountDataProvider.followers
          .firstWhereOrNull((f) => f['follower_id'] == otherUserId);
      
      if (followingMatch != null) {
        avatarUrl = followingMatch['avatar'] ?? followingMatch['google_avatar'];
      } else if (followerMatch != null) {
        avatarUrl = followerMatch['avatar'] ?? followerMatch['google_avatar'];
      }
    }
    
    // Check if message is read
    final bool isRead = message['is_read'] == true;
    
    // Only show read status on sent messages
    final bool shouldShowStatus = isMe;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Dismissible(
        key: Key(message['id'] ?? DateTime.now().toString()),
        // Only show background when message is from the current user
        background: shouldShowStatus ? Container(
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
        ) : Container(color: Colors.transparent),
        // Swipe from right to left (Instagram style)
        direction: shouldShowStatus ? DismissDirection.endToStart : DismissDirection.none,
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
                left: isMe ? 8 : 24, // Add more space on left for other's avatar
                right: isMe ? 24 : 8, // Add more space on right for user's avatar
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                    ? Colors.blue 
                    : Colors.grey.shade800, // Darker background for received messages
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxWidth: Get.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message['content'] ?? '',
                    style: const TextStyle(
                      color: Colors.white, // Always white text
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Avatar in top right/left corner
            Positioned(
              top: 0,
              right: isMe ? 0 : null,
              left: isMe ? null : 0,
              child: CircleAvatar(
                radius: 12.5, // 25px diameter
                backgroundColor: Colors.black,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                    : const AssetImage('assets/images/default_avatar.png'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageInput(String chatId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Obx(() {
        final isLoading = controller.isSendingMessage.value;
        
        return TextField(
          controller: controller.messageController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Send Yap',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            fillColor: Colors.black,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade800),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade800),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            // Add send button as suffix icon
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Material(
                color: Colors.blue, // Never disabled, always blue
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    // Only send if there's text and not already sending
                    if (controller.messageController.text.trim().isNotEmpty && !isLoading) {
                      // Don't close keyboard to allow continuous typing
                      controller.sendMessage(chatId, controller.messageController.text.trim());
                    }
                  },
                  splashColor: Colors.blue.shade700,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ),
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
        );
      }),
    );
  }
  
  String _formatExpirationTime(String? expiresAt) {
    if (expiresAt == null) return '';
    
    try {
      final expirationTime = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = expirationTime.difference(now);
      
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      
      if (hours > 0) {
        return 'Expires in ${hours}h ${minutes}m';
      } else if (minutes > 0) {
        return 'Expires in ${minutes}m';
      } else {
        return 'Expiring soon';
      }
    } catch (e) {
      return 'Expiring soon';
    }
  }
} 
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import '../controllers/chat_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:yapster/app/routes/app_pages.dart';

// Lifecycle observer to detect when app resumes from background
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  
  _AppLifecycleObserver({required this.onResume});
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App lifecycle: resumed');
      onResume();
    }
  }
}

class ChatDetailView extends GetView<ChatController> {
  const ChatDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    // Get arguments passed to this route
    final args = Get.arguments as Map<String, dynamic>;
    final String chatId = args['chat_id'] as String;
    final String otherUserId = args['other_user_id'] as String;
    final String username = args['username'] as String;
    
    // Create the lifecycle observer
    final lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        debugPrint('App resumed - refreshing messages');
        // Force refresh messages from server when app resumes
        controller.loadMessages(chatId);
        // Make sure we immediately mark messages as read
        controller.markMessagesAsRead(chatId);
      },
    );
    
    // Register app lifecycle observer to detect app resuming from background
    WidgetsBinding.instance.addObserver(lifecycleObserver);
    
    // Use a simpler approach - let the controller handle cleanup
    // The controller is already a WidgetsBindingObserver and will handle
    // subscriptions and app lifecycle events automatically
    
    // Fetch profile for other user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOtherUserProfile(otherUserId);
      
      // Only trigger read status when the messages list actually changes
      // Use a debounced approach to avoid excessive updates
      DateTime? lastMessageUpdate;
      ever(controller.messages, (_) {
        final now = DateTime.now();
        // Skip if last update was within 5 seconds
        if (lastMessageUpdate != null && 
            now.difference(lastMessageUpdate!).inSeconds < 5) {
          return;
        }
        
        lastMessageUpdate = now;
        debugPrint('Message list changed - checking for unread messages');
        controller.markMessagesAsRead(chatId);
      });
    });
    
    // Load messages if not already loaded
    if (controller.selectedChatId.value != chatId) {
      controller.selectedChatId.value = chatId;
      controller.loadMessages(chatId);
    }
    
    // IMPROVED: Enhanced read status marking
    // Initial mark as read when chat is opened
    controller.markMessagesAsRead(chatId);
    
    // Set up periodic check to mark messages as read (for when new messages arrive)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This ensures we mark messages as read after the view is fully built
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.markMessagesAsRead(chatId);
      });
      
      // Set up a timer to periodically mark messages as read, but at a reasonable interval
      // This will continue until the app is closed or navigated away
      Timer.periodic(const Duration(seconds: 30), (timer) {
        // Check if we're still on the chat detail route
        if (Get.currentRoute.contains(Routes.CHAT_DETAIL)) {
          controller.markMessagesAsRead(chatId);
        } else {
          // Cancel the timer if we've navigated away
          timer.cancel();
        }
      });
    });
    
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
  
  // Fetch profile data for the other user
  Future<void> _fetchOtherUserProfile(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      debugPrint('Fetching chat profile data for user: $userId');
      
      // Query the profiles table for this user
      final response = await supabaseService.client
          .from('profiles')
          .select('*')
          .eq('user_id', userId)
          .single();
      
      if (response != null) {
        debugPrint('Chat user profile found: $response');
        // Store this in account provider for access in message bubbles
        final accountProvider = Get.find<AccountDataProvider>();
        
        // Create a new follow entry for this user if not already in lists
        final isInFollowing = accountProvider.following
            .any((user) => user['following_id'] == userId);
        final isInFollowers = accountProvider.followers
            .any((user) => user['follower_id'] == userId);
            
        if (!isInFollowing && !isInFollowers) {
          debugPrint('Adding chat user to temporary following list');
          
          // Get avatar and ensure it's a valid URL
          final String? avatar = response['avatar'];
          final String? googleAvatar = response['google_avatar'];
          
          // Don't pass invalid URLs to the UI
          final validAvatar = (avatar != null && 
                               avatar != "skiped" && 
                               avatar != "null" && 
                               avatar.contains("://")) ? avatar : null;
          
          // Temporarily add to following list for avatar display
          accountProvider.following.add({
            'following_id': userId,
            'username': response['username'],
            'avatar': validAvatar,
            'google_avatar': googleAvatar,
            'nickname': response['nickname'],
          });
          
          // Force UI update to show the new avatar
          Get.forceAppUpdate();
        }
      }
    } catch (e) {
      debugPrint('Error fetching chat user profile: $e');
    }
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
                  child: const Text("GOT IT", style: TextStyle(color: Colors.white),),
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
    
    // Variables to hold avatar info
    String? regularAvatar;
    String? googleAvatar;
    
    if (isMe && currentUser != null) {
      // Current user's message - use current user's avatar
      regularAvatar = accountDataProvider.avatar.value;
      googleAvatar = accountDataProvider.googleAvatar.value;
    } else {
      // First check the following list
      final followingMatch = accountDataProvider.following
          .firstWhereOrNull((f) => f['following_id'] == otherUserId);
          
      // Then check the followers list
      final followerMatch = accountDataProvider.followers
          .firstWhereOrNull((f) => f['follower_id'] == otherUserId);
      
      if (followingMatch != null) {
        regularAvatar = followingMatch['avatar'];
        googleAvatar = followingMatch['google_avatar'];
        debugPrint('Found other user in following list - avatar: $regularAvatar, google: $googleAvatar');
      } else if (followerMatch != null) {
        regularAvatar = followerMatch['avatar'];
        googleAvatar = followerMatch['google_avatar'];
        debugPrint('Found other user in followers list - avatar: $regularAvatar, google: $googleAvatar');
      } else {
        // If not found in lists, try to get directly from database (async, will update on next build)
        _getChatUserProfile(otherUserId).then((profile) {
          if (profile != null) {
            debugPrint('Got profile directly: avatar=${profile['avatar']}, google=${profile['google_avatar']}');
          }
        });
      }
    }
    
    // Debug avatar info
    debugPrint('Message bubble avatar info:');
    debugPrint('Regular avatar: $regularAvatar');
    debugPrint('Google avatar: $googleAvatar');
    
    // FIXED: More robust URL validation
    // Check if regular avatar is valid (not null, not empty, not "skiped", and has a valid URL scheme)
    final bool hasRegularAvatar = regularAvatar != null && 
                          regularAvatar.isNotEmpty && 
                          regularAvatar != "skiped" &&
                          regularAvatar != "null" &&
                          regularAvatar.contains("://") &&
                          Uri.tryParse(regularAvatar)?.hasScheme == true;
                           
    // Check if Google avatar is valid (not null, not empty, and has a valid URL scheme)
    final bool hasGoogleAvatar = googleAvatar != null && 
                          googleAvatar.isNotEmpty &&
                          googleAvatar != "null" &&
                          googleAvatar.contains("://") &&
                          Uri.tryParse(googleAvatar)?.hasScheme == true;
    
    debugPrint('Has regular avatar: $hasRegularAvatar');
    debugPrint('Has Google avatar: $hasGoogleAvatar');
    
    // Check if message is read
    final bool isRead = message['is_read'] == true;
    
    // Only show read status on sent messages
    final bool shouldShowStatus = isMe;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Dismissible(
        key: Key(message['message_id'] ?? DateTime.now().toString()),
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
                left: isMe ? 8 : 24,
                right: isMe ? 24 : 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                    ? Colors.blue 
                    : Colors.grey.shade800,
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
            
            // Avatar in top right/left corner - FIXED to handle invalid URLs
            Positioned(
              top: 0,
              right: isMe ? 0 : null,
              left: isMe ? null : 0,
              child: CircleAvatar(
                radius: 12.5, // 25px diameter
                backgroundColor: Colors.black,
                backgroundImage: hasRegularAvatar
                    ? CachedNetworkImageProvider(regularAvatar!)
                    : hasGoogleAvatar
                        ? CachedNetworkImageProvider(googleAvatar!)
                        : null,
                child: (!hasRegularAvatar && !hasGoogleAvatar)
                    ? const Icon(Icons.person, size: 12, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to get a user profile directly from DB
  Future<Map<String, dynamic>?> _getChatUserProfile(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      
      // Query the profiles table for this user
      final response = await supabaseService.client
          .from('profiles')
          .select('*')
          .eq('user_id', userId)
          .single();
      
      if (response != null) {
        // Add to account provider for next render
        final accountProvider = Get.find<AccountDataProvider>();
        
        // Check if we need to add to following list
        final isInFollowing = accountProvider.following
            .any((user) => user['following_id'] == userId);
        final isInFollowers = accountProvider.followers
            .any((user) => user['follower_id'] == userId);
            
        if (!isInFollowing && !isInFollowers) {
          // Process avatar URLs
          final String? avatar = response['avatar'];
          final String? googleAvatar = response['google_avatar'];
          
          // Sanitize avatar URL to prevent errors
          final validAvatar = (avatar != null && 
                               avatar != "skiped" && 
                               avatar != "null" && 
                               avatar.contains("://")) ? avatar : null;
          
          // Add to following list for access in message bubbles with valid avatar
          accountProvider.following.add({
            'following_id': userId,
            'username': response['username'],
            'avatar': validAvatar,
            'google_avatar': googleAvatar,
            'nickname': response['nickname'],
          });
          
          // Trigger rebuild
          Get.forceAppUpdate();
        }
        
        return response;
      }
    } catch (e) {
      debugPrint('Error getting chat user profile: $e');
    }
    return null;
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
} 
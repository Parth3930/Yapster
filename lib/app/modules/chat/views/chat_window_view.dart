import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import '../controllers/chat_controller.dart';
import 'dart:async';
import 'package:yapster/app/routes/app_pages.dart';
import 'components/message_input.dart';
import 'components/chat_timer_banner.dart';
import 'components/editing_message_banner.dart';
import 'components/messages_list.dart';
import 'components/encryption_dialog.dart';

// Lifecycle observer to detect when app resumes from background
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback onPause;

  _AppLifecycleObserver({required this.onResume, required this.onPause});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('App lifecycle: resumed');
      onResume();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('App lifecycle: paused');
      onPause();
    }
  }
}

// Observer for keyboard visibility changes
class _KeyboardVisibilityObserver extends WidgetsBindingObserver {
  final VoidCallback onHide;
  final VoidCallback onShow;
  bool _wasVisible = false;

  _KeyboardVisibilityObserver({required this.onHide, required this.onShow});

  @override
  void didChangeMetrics() {
    final keyboardVisible = View.of(Get.context!).viewInsets.bottom > 0;
    if (keyboardVisible && !_wasVisible) {
      onShow();
    } else if (!keyboardVisible && _wasVisible) {
      onHide();
    }
    _wasVisible = keyboardVisible;
  }
}

class ChatWindowView extends GetView<ChatController> {
  const ChatWindowView({super.key});

  // Add the missing RxBool for keyboard visibility
  static final RxBool isKeyboardVisible = false.obs;

  // Cache for user profiles to avoid repeated fetches
  static final Map<String, Map<String, dynamic>> _userProfileCache = {};

  // Track if we've already initialized this chat
  static String? _currentChatId;
  static bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    // Get arguments passed to this route - add a null check
    final args = Get.arguments as Map<String, dynamic>?;

    // Make sure we have arguments
    if (args == null) {
      // Handle missing arguments case
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        Get.snackbar('Error', 'Chat Windows not available');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Safely access required arguments with null checks
    final String? chatId = args['chatId'] as String?;
    final String? otherUserId = args['otherUserId'] as String?;
    final String? username = args['username'] as String?;

    // Validate required arguments
    if (chatId == null || otherUserId == null || username == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        Get.snackbar('Error', 'Missing required chat information');
        debugPrint(
          'Missing arguments: chatId=$chatId, otherUserId=$otherUserId, username=$username',
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // CRITICAL FIX: Clear messages IMMEDIATELY when building the widget to prevent flicker
    // This happens synchronously before any UI is rendered
    if (controller.selectedChatId.value != chatId) {
      controller.messages.clear();
      controller.selectedChatId.value = chatId;
    }

    // Only initialize once per chat or when chat changes
    final bool needsInitialization =
        _currentChatId != chatId || !_isInitialized;

    if (needsInitialization) {
      _currentChatId = chatId;
      _isInitialized = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeChat(chatId, otherUserId, username);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black, // Set black background
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Reset initialization when leaving chat
            _isInitialized = false;
            _currentChatId = null;

            // Ensure we refresh the chat list when returning
            try {
              final controller = Get.find<ChatController>();
              // Force clear any loading state
              controller.isLoading.value = false;
              // Trigger background refresh of chats when returning
              controller.preloadRecentChats();
            } catch (e) {
              // Error refreshing chats on back
            }

            Get.back();
          },
        ),
        title: Obx(() {
          final latestMessage = _getLatestMessagePreview();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (latestMessage.isNotEmpty)
                Text(
                  latestMessage,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          );
        }),
        actions: [
          // Lock icon for encryption
          IconButton(
            icon: const Icon(Icons.lock, color: Colors.white),
            onPressed: () => EncryptionDialog.show(context),
          ),
        ],
      ),
      body: KeyboardDismissOnTap(
        child: Column(
          children: [
            // Chat countdown timer - shows how long until messages expire
            ChatTimerBanner(),

            // Messages list
            Expanded(
              child: Obx(() {
                if (controller.isSendingMessage.value &&
                    controller.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Pass the correct otherUserId to MessagesList
                return MessagesList();
              }),
            ),

            // Edit message banner - shows when editing a message
            MessageInput.isEditingMessage.value
                ? const EditingMessageBanner()
                : const SizedBox.shrink(),

            // Message input
            MessageInput(chatId: chatId),
          ],
        ),
      ),
    );
  }

  // Get latest message preview for the app bar subtitle
  String _getLatestMessagePreview() {
    if (controller.messages.isEmpty) {
      return '';
    }

    final latestMessage = controller.messages.last;
    final currentUserId = SupabaseService.to.currentUser.value?.id;
    final isMe = latestMessage.senderId == currentUserId;

    String content = latestMessage.content;

    // Check if it's a shared post by message type or content
    bool isSharedPost =
        latestMessage.messageType == 'shared_post' ||
        content.contains('"type":"shared_post"') ||
        content.contains('"type": "shared_post"') ||
        content.contains('shard_post'); // Handle typo in data

    if (isSharedPost) {
      content = isMe ? 'Sent a post' : 'Received a post';
    } else if (content.startsWith('http') &&
        (content.contains('.jpg') ||
            content.contains('.jpeg') ||
            content.contains('.png') ||
            content.contains('.gif'))) {
      content = isMe ? 'You sent a photo' : 'Sent a photo';
    } else if (content.length > 30) {
      content = '${content.substring(0, 30)}...';
    }

    return isMe ? 'You: $content' : content;
  }

  // Optimized initialization method - minimal setup for instant loading
  void _initializeChat(String chatId, String otherUserId, String username) {
    // CRITICAL FIX: Use optimized method to clear messages and set chat ID
    controller.clearMessagesForNewChat(chatId);

    // Create a final focus node
    final inputFocusNode = FocusNode();
    Get.put(inputFocusNode, tag: 'input_focus_node');

    // Handle special loading case
    if (chatId == 'loading') {
      _handleLoadingChat(otherUserId, username);
      return;
    }

    // Do heavy initialization in background
    _setupInBackground(chatId, otherUserId);
  }

  // Handle the loading chat case where we need to create the chat
  void _handleLoadingChat(String otherUserId, String username) async {
    final args = Get.arguments as Map<String, dynamic>?;
    final userOne = args?['userOne'] as String?;
    final userTwo = args?['userTwo'] as String?;

    if (userOne != null && userTwo != null) {
      try {
        final supabaseService = Get.find<SupabaseService>();
        final chatId = await supabaseService.client.rpc(
          'user_chat_connect',
          params: {'user_one': userOne, 'user_two': userTwo},
        );

        if (chatId != null && (chatId is String) && chatId.isNotEmpty) {
          // Clear messages again before setting new chat ID
          controller.messages.clear();
          // Update the selected chat ID with the real one
          controller.selectedChatId.value = chatId;
          // Continue with normal initialization
          _setupInBackground(chatId, otherUserId);
        }
      } catch (e) {
        // If we can't create the chat, show an error and go back
        Get.back();
        Get.snackbar('Error', 'Unable to start chat. Please try again.');
      }
    }
  }

  // Setup heavy operations in background for better performance
  void _setupInBackground(String chatId, String otherUserId) async {
    // Set up lifecycle observers
    _setupLifecycleObservers(chatId);

    // Set up keyboard observers
    _setupKeyboardObservers();

    // Set up cleanup
    _setupCleanup();

    // Fetch user profile in background
    _fetchOtherUserProfileCached(otherUserId);

    // Load messages in background
    _loadMessagesOnce(chatId);
  }

  // Track if messages have been marked as read for this chat
  static final Set<String> _chatsMarkedAsRead = <String>{};

  // Load messages once when chat is opened - optimized for speed
  void _loadMessagesOnce(String chatId) async {
    try {
      // Ensure messages are cleared before loading new ones
      controller.messages.clear();

      // Load messages directly without showing cached ones first to avoid confusion
      await controller.preloadMessages(chatId);

      // Mark as read only if we haven't done so for this chat
      if (!_chatsMarkedAsRead.contains(chatId)) {
        await controller.markMessagesAsRead(chatId);
        _chatsMarkedAsRead.add(chatId);
      }
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        Get.snackbar('Error', 'Failed to load messages. Please try again.');
      }
    }
  }

  // Set up lifecycle observers
  void _setupLifecycleObservers(String chatId) {
    final lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        // Only sync when app resumes (not full reload)
        controller.syncMessagesWithDatabase(chatId);
      },
      onPause: () {
        // App paused - preparing for background
      },
    );

    WidgetsBinding.instance.addObserver(lifecycleObserver);
  }

  // Set up keyboard observers
  void _setupKeyboardObservers() {
    final MediaQueryData mq = MediaQuery.of(Get.context!);
    isKeyboardVisible.value = mq.viewInsets.bottom > 0;
    Get.put(isKeyboardVisible, tag: 'keyboard_visibility', permanent: true);

    final observer = _KeyboardVisibilityObserver(
      onHide: () {
        if (Get.context != null) {
          FocusScope.of(Get.context!).unfocus();
        }
        isKeyboardVisible.value = false;
      },
      onShow: () {
        isKeyboardVisible.value = true;
      },
    );
    WidgetsBinding.instance.addObserver(observer);
  }

  // Set up cleanup
  void _setupCleanup() {
    final routeObs = RxString(Get.currentRoute);

    ever(routeObs, (route) {
      if (Get.previousRoute == Routes.CHAT_WINDOW &&
          Get.currentRoute != Routes.CHAT_WINDOW) {
        // Reset initialization flags
        _isInitialized = false;
        _currentChatId = null;

        // Clean up focus node
        if (Get.isRegistered<FocusNode>(tag: 'input_focus_node')) {
          Get.delete<FocusNode>(tag: 'input_focus_node');
        }
      }
      routeObs.value = Get.currentRoute;
    });

    routeObs.value = Get.currentRoute;
  }

  // Cached profile fetching to avoid repeated database calls
  Future<void> _fetchOtherUserProfileCached(String userId) async {
    // Check cache first
    if (_userProfileCache.containsKey(userId)) {
      debugPrint('Using cached profile for user: $userId');
      _addUserToFollowingList(_userProfileCache[userId]!, userId);
      return;
    }

    try {
      final supabaseService = Get.find<SupabaseService>();
      debugPrint('Fetching chat profile data for user: $userId');

      final response =
          await supabaseService.client
              .from('profiles')
              .select('*')
              .eq('user_id', userId)
              .single();

      debugPrint('Chat user profile found: $response');

      // Cache the response
      _userProfileCache[userId] = response;

      // Add to following list
      _addUserToFollowingList(response, userId);
    } catch (e) {
      debugPrint('Error fetching chat user profile: $e');
    }
  }

  // Helper method to add user to following list
  void _addUserToFollowingList(Map<String, dynamic> response, String userId) {
    final accountProvider = Get.find<AccountDataProvider>();

    final isInFollowing = accountProvider.following.any(
      (user) => user['following_id'] == userId,
    );
    final isInFollowers = accountProvider.followers.any(
      (user) => user['follower_id'] == userId,
    );

    if (!isInFollowing && !isInFollowers) {
      debugPrint('Adding chat user to temporary following list');

      final String? avatar = response['avatar'];
      final String? googleAvatar = response['google_avatar'];

      debugPrint(
        'Adding chat user with avatar: $avatar, google_avatar: $googleAvatar',
      );

      accountProvider.following.add({
        'following_id': userId,
        'username': response['username'],
        'avatar': avatar,
        'google_avatar': googleAvatar,
        'nickname': response['nickname'],
      });

      Get.forceAppUpdate();
    }
  }
}

// Enhanced debouncer class
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void call(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

// Custom widget for keyboard dismissal on tap
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnTap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}

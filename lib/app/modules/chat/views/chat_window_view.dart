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
    final keyboardVisible =
        WidgetsBinding.instance.window.viewInsets.bottom > 0;
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

    // Create a final focus node in the build method
    final inputFocusNode = FocusNode();

    // Dispose focus node when screen is disposed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.put(inputFocusNode, tag: 'input_focus_node');
    });

    // Create a lifecycle observer with both resume and pause handlers
    final lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        debugPrint('App resumed - refreshing messages and reconnecting');
        // Force refresh messages from server when app resumes
        controller.loadMessages(chatId);
        // Make sure we immediately mark messages as read
        controller.markMessagesAsRead(chatId);
      },
      onPause: () {
        debugPrint('App paused - preparing for background');
        // We could add any cleanup needed when app goes to background
      },
    );

    // Register app lifecycle observer to detect app resuming from background
    WidgetsBinding.instance.addObserver(lifecycleObserver);

    // Add a listener for keyboard visibility changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Listen for keyboard visibility changes
      final MediaQueryData mq = MediaQuery.of(context);
      isKeyboardVisible.value = mq.viewInsets.bottom > 0;

      // Register for global access
      Get.put(isKeyboardVisible, tag: 'keyboard_visibility', permanent: true);

      // Add a listener for keyboard visibility to disable focus when keyboard closes
      final observer = _KeyboardVisibilityObserver(
        onHide: () {
          // Clear focus when keyboard closes - safely check if context is still valid
          if (Get.context != null) {
            FocusScope.of(Get.context!).unfocus();
          }
          isKeyboardVisible.value = false;
          debugPrint('Keyboard hidden, cleared focus');
        },
        onShow: () {
          isKeyboardVisible.value = true;
          debugPrint('Keyboard shown');
        },
      );
      WidgetsBinding.instance.addObserver(observer);

      // Create a debouncer for the read status updates
      final readStatusDebouncer = Debouncer(milliseconds: 500);

      // Use a debounced listener to avoid recursive calls
      ever(controller.messages, (_) {
        try {
          // Use the debouncer to avoid triggering updates too frequently
          readStatusDebouncer.call(() {
            // Only mark messages as read, don't recursively load messages
            controller.markMessagesAsRead(chatId);
            debugPrint('Messages updated - marked as read (debounced)');
          });
        } catch (e) {
          debugPrint('Error marking messages as read: $e');
        }
      });
    });

    // Fetch profile for other user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOtherUserProfile(otherUserId);
    });

    // Set the selected chat ID and load messages
    controller.selectedChatId.value = chatId;
    // Initial load of messages
    try {
      controller.loadMessages(chatId);
    } catch (e) {
      debugPrint('Error loading messages initially: $e');
      // Show error to user
      Get.snackbar('Error', 'Failed to load messages. Please try again.');
    }

    // Make sure to properly reset when the view is closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clean up observers on page close using route observer
      final routeObs = RxString(Get.currentRoute);

      ever(routeObs, (route) {
        if (Get.previousRoute == Routes.CHAT_WINDOW &&
            Get.currentRoute != Routes.CHAT_WINDOW) {
          debugPrint('Leaving chat Window - cleaning up observers');
          WidgetsBinding.instance.removeObserver(lifecycleObserver);

          // Clean up focus node on pop
          if (Get.isRegistered<FocusNode>(tag: 'input_focus_node')) {
            Get.delete<FocusNode>(tag: 'input_focus_node');
          }
        }

        // Update route value
        routeObs.value = Get.currentRoute;
      });

      // Initial route value
      routeObs.value = Get.currentRoute;
    });

    // Initial mark as read when chat is opened
    try {
      controller.markMessagesAsRead(chatId);
    } catch (e) {
      debugPrint('Error marking messages as read initially: $e');
    }

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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

  // Fetch profile data for the other user
  Future<void> _fetchOtherUserProfile(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      debugPrint('Fetching chat profile data for user: $userId');

      // Query the profiles table for this user
      final response =
          await supabaseService.client
              .from('profiles')
              .select('*')
              .eq('user_id', userId)
              .single();

      debugPrint('Chat user profile found: $response');
      // Store this in account provider for access in message bubbles
      final accountProvider = Get.find<AccountDataProvider>();

      // Create a new follow entry for this user if not already in lists
      final isInFollowing = accountProvider.following.any(
        (user) => user['following_id'] == userId,
      );
      final isInFollowers = accountProvider.followers.any(
        (user) => user['follower_id'] == userId,
      );

      if (!isInFollowing && !isInFollowers) {
        debugPrint('Adding chat user to temporary following list');

        // Process avatar URLs
        final String? avatar = response['avatar'];
        final String? googleAvatar = response['google_avatar'];

        // Log avatar values for debugging
        debugPrint(
          'Adding chat user with avatar: $avatar, google_avatar: $googleAvatar',
        );

        // Store both avatars without validation - let the display logic handle fallback
        accountProvider.following.add({
          'following_id': userId,
          'username': response['username'],
          'avatar': avatar, // Store original value, even if "skiped"
          'google_avatar': googleAvatar,
          'nickname': response['nickname'],
        });

        // Force UI update to show the new avatar
        Get.forceAppUpdate();
      }
    } catch (e) {
      debugPrint('Error fetching chat user profile: $e');
    }
  }

  // Fetch profile data for the other user
}

// Add a debouncer class to prevent frequent calls
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

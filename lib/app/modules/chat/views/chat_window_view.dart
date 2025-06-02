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

    // Only initialize once per chat or when chat changes
    final bool needsInitialization =
        _currentChatId != chatId || !_isInitialized;

    if (needsInitialization) {
      debugPrint('Initializing chat: $chatId');
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
            Get.back();
          },
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

  // Consolidated initialization method
  void _initializeChat(String chatId, String otherUserId, String username) {
    // Create a final focus node
    final inputFocusNode = FocusNode();
    Get.put(inputFocusNode, tag: 'input_focus_node');

    // Set up lifecycle observers only once
    _setupLifecycleObservers(chatId);

    // Set up keyboard observers only once
    _setupKeyboardObservers();

    // Set up message observers with debouncing
    _setupMessageObservers(chatId);

    // Set up cleanup
    _setupCleanup();

    // Fetch user profile (with caching)
    _fetchOtherUserProfileCached(otherUserId);

    // Set the selected chat ID and load messages ONCE
    controller.selectedChatId.value = chatId;

    // Initial load of messages - only do this once per chat
    _loadMessagesOnce(chatId);
  }

  // Load messages only once and mark as read
  void _loadMessagesOnce(String chatId) {
    try {
      debugPrint('Initial load of messages for chat: $chatId');
      // Use preloadMessages for better caching performance
      controller.preloadMessages(chatId).then((_) {
        // Mark messages as read after loading
        controller.markMessagesAsRead(chatId);
      });
    } catch (e) {
      debugPrint('Error loading messages initially: $e');
      Get.snackbar('Error', 'Failed to load messages. Please try again.');
    }
  }

  // Set up lifecycle observers
  void _setupLifecycleObservers(String chatId) {
    final lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        debugPrint('App resumed - syncing messages');
        // Only sync when app resumes (not full reload)
        controller.syncMessagesWithDatabase(chatId);
        controller.markMessagesAsRead(chatId);
      },
      onPause: () {
        debugPrint('App paused - preparing for background');
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
        debugPrint('Keyboard hidden, cleared focus');
      },
      onShow: () {
        isKeyboardVisible.value = true;
        debugPrint('Keyboard shown');
      },
    );
    WidgetsBinding.instance.addObserver(observer);
  }

  // Set up message observers with heavy debouncing
  void _setupMessageObservers(String chatId) {
    // Use longer debounce to prevent excessive calls
    final readStatusDebouncer = Debouncer(
      milliseconds: 2000,
    ); // Increased to 2 seconds

    // Track the last message count to avoid unnecessary updates
    int lastMessageCount = 0;

    ever(controller.messages, (messages) {
      try {
        // Only mark as read if message count actually changed
        if (messages.length != lastMessageCount) {
          lastMessageCount = messages.length;

          readStatusDebouncer.call(() {
            debugPrint('Messages count changed - marking as read (debounced)');
            controller.markMessagesAsRead(chatId);
          });
        }
      } catch (e) {
        debugPrint('Error in message observer: $e');
      }
    });
  }

  // Set up cleanup
  void _setupCleanup() {
    final routeObs = RxString(Get.currentRoute);

    ever(routeObs, (route) {
      if (Get.previousRoute == Routes.CHAT_WINDOW &&
          Get.currentRoute != Routes.CHAT_WINDOW) {
        debugPrint('Leaving chat Window - cleaning up');

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

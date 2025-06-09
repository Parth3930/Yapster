import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/group_model.dart';
import '../controllers/group_controller.dart';
import '../controllers/chat_controller.dart';
import 'dart:async';
import 'components/message_input.dart';
import 'components/chat_timer_banner.dart';
import 'components/editing_message_banner.dart';
import 'components/messages_list.dart';
import 'components/encryption_dialog.dart';

class GroupChatWindowView extends StatefulWidget {
  const GroupChatWindowView({super.key});

  @override
  State<GroupChatWindowView> createState() => _GroupChatWindowViewState();
}

class _GroupChatWindowViewState extends State<GroupChatWindowView>
    with WidgetsBindingObserver {
  late final GroupController controller;
  late final ChatController chatController;
  late final AccountDataProvider accountProvider;

  // Lifecycle management
  bool _isInitialized = false;
  String? _currentGroupId;

  // Debouncer for message loading
  final Debouncer _messageDebouncer = Debouncer(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    // Get or create controllers
    try {
      controller = Get.find<GroupController>();
    } catch (e) {
      controller = GroupController();
      Get.put(controller);
    }

    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      chatController = ChatController();
      Get.put(chatController);
    }

    accountProvider = Get.find<AccountDataProvider>();

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize chat after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGroupChat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageDebouncer.dispose();

    // Clean up focus node
    try {
      final focusNode = Get.find<FocusNode>(tag: 'input_focus_node');
      focusNode.dispose();
      Get.delete<FocusNode>(tag: 'input_focus_node');
    } catch (e) {
      // Focus node not found, ignore
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _currentGroupId != null) {
      // Reload messages when app resumes
      _messageDebouncer.call(() {
        controller.loadGroupMessages(_currentGroupId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;

    if (args == null || args is! Map<String, dynamic>) {
      return _buildErrorScaffold(
        'Group data unavailable - no arguments passed',
      );
    }

    final String groupId = args['groupId']?.toString() ?? '';
    final String groupName = args['groupName']?.toString() ?? 'Group Chat';
    final Map<String, dynamic>? groupData = args['groupData'];

    if (groupId.isEmpty) {
      return _buildErrorScaffold('Invalid group ID - empty or null');
    }

    // CRITICAL FIX: Clear group messages IMMEDIATELY when building the widget to prevent flicker
    // This happens synchronously before any UI is rendered
    if (controller.selectedGroupId.value != groupId) {
      controller.currentGroupMessages.clear();
      controller.selectedGroupId.value = groupId;
    }

    // If we have group data, ensure it's in the controller
    if (groupData != null) {
      try {
        final groupModel = GroupModel.fromJson(groupData);
        // Add to controller if not already there
        if (controller.getGroupById(groupId) == null) {
          controller.groups.add(groupModel);
        }
      } catch (e) {
        // Error parsing group data
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Reset initialization when leaving group chat
            _isInitialized = false;
            _currentGroupId = null;
            Get.back();
          },
        ),
        title: Obx(() {
          final latestMessage = _getLatestGroupMessagePreview();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
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
          // Group settings icon
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showGroupSettings(),
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
                if (chatController.isSendingMessage.value &&
                    chatController.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return MessagesList();
              }),
            ),

            // Edit message banner - shows when editing a message
            MessageInput.isEditingMessage.value
                ? const EditingMessageBanner()
                : const SizedBox.shrink(),

            // Message input
            MessageInput(chatId: groupId),
          ],
        ),
      ),
    );
  }

  // Get latest group message preview for the app bar subtitle
  String _getLatestGroupMessagePreview() {
    if (controller.currentGroupMessages.isEmpty) {
      return '';
    }

    final latestMessage = controller.currentGroupMessages.last;
    final currentUserId = SupabaseService.to.currentUser.value?.id;
    final isMe = latestMessage.senderId == currentUserId;

    String content = latestMessage.content;

    // Handle different message types
    if (content.startsWith('http') &&
        (content.contains('.jpg') ||
            content.contains('.jpeg') ||
            content.contains('.png') ||
            content.contains('.gif'))) {
      content = isMe ? 'You sent a photo' : 'Someone sent a photo';
    } else if (content.length > 30) {
      content = '${content.substring(0, 30)}...';
    }

    return isMe ? 'You: $content' : content;
  }

  void _initializeGroupChat() {
    final args = Get.arguments;
    if (args == null || args is! Map<String, dynamic>) return;

    final String groupId = args['groupId'] ?? '';
    if (groupId.isEmpty) return;

    // Only initialize once per group
    if (_isInitialized && _currentGroupId == groupId) return;

    _isInitialized = true;
    _currentGroupId = groupId;

    // CRITICAL FIX: Clear messages immediately to prevent showing previous group messages
    controller.currentGroupMessages.clear();

    // Create focus node for input
    final inputFocusNode = FocusNode();
    Get.put(inputFocusNode, tag: 'input_focus_node');

    // Set selected chat ID immediately for instant UI
    chatController.selectedChatId.value = groupId;
    controller.selectedGroupId.value = groupId;

    // Load messages in background for better performance
    Future.microtask(() => controller.loadGroupMessages(groupId));
  }

  void _showGroupSettings() {
    // Implement group settings dialog
    Get.snackbar(
      'Group Settings',
      'Group settings coming soon',
      backgroundColor: Colors.grey[800],
      colorText: Colors.white,
    );
  }

  Widget _buildErrorScaffold(String errorMessage) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Group Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
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

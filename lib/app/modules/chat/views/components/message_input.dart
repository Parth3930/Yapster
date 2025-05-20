import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/chat_controller.dart';

class MessageInput extends StatelessWidget {
  final String chatId;

  const MessageInput({Key? key, required this.chatId}) : super(key: key);

  // Static variables for message editing
  static final RxBool isEditingMessage = false.obs;
  static final Rx<Map<String, dynamic>?> messageBeingEdited =
      Rx<Map<String, dynamic>?>(null);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChatController>();

    // Track typing state with debounce to prevent flickering
    final isTyping = RxBool(false);
    final isSending = RxBool(false);
    final FocusNode inputFocusNode = FocusNode();
    Timer? debounceTimer;

    // Set up listener for typing detection with debounce
    controller.messageController.addListener(() {
      // Skip updates during sending to prevent stutter
      if (isSending.value) return;

      // Cancel any pending timer
      debounceTimer?.cancel();

      // Create new timer for state change
      debounceTimer = Timer(const Duration(milliseconds: 100), () {
        final hasText = controller.messageController.text.isNotEmpty;
        // Only update if state actually changed
        if (isTyping.value != hasText) {
          isTyping.value = hasText;
        }
      });
    });

    // Handle message sending with smooth animation
    void handleSendMessage() {
      if (controller.messageController.text.trim().isEmpty || isSending.value) {
        return; // Don't send empty messages or during sending
      }

      // Set sending flag to prevent UI updates
      isSending.value = true;

      // Store the message text before clearing
      final messageText = controller.messageController.text.trim();

      // Clear debounce timer if any
      debounceTimer?.cancel();

      // Check if we're editing a message
      if (isEditingMessage.value && messageBeingEdited.value != null) {
        final messageId = messageBeingEdited.value!['message_id'];

        // Update the message
        controller.updateMessage(chatId, messageId, messageText);

        // Clear edit state
        messageBeingEdited.value = null;
        isEditingMessage.value = false;

        // Clear the text field and reset UI
        controller.messageController.clear();

        // Reset sending state after a brief delay
        Future.delayed(const Duration(milliseconds: 300), () {
          isSending.value = false;
          isTyping.value = false;
        });

        return;
      }

      // Wait for animation to complete before clearing input
      Future.delayed(const Duration(milliseconds: 50), () {
        // Send the message but don't update UI yet
        controller.sendChatMessage(chatId, messageText);

        // Clear text after a short delay to avoid flickering the UI
        Future.delayed(const Duration(milliseconds: 200), () {
          // Finally reset sending state after everything is done
          isSending.value = false;

          // Check again if text is empty (it should be, but just to be safe)
          final hasText = controller.messageController.text.isNotEmpty;
          if (isTyping.value != hasText) {
            isTyping.value = hasText;
          }
        });
      });
    }

    // Helper function for handling camera press
    void handleCameraPress() {
      try {
        // Check if we have valid chat ID
        if (chatId.isEmpty) {
          debugPrint('Invalid chat ID when trying to access camera');
          Get.snackbar('Error', 'Could not send photo: chat details missing');
          return;
        }

        // Use a try-catch to prevent potential crashes
        _handleCameraPress(chatId);
      } catch (e) {
        debugPrint('Error accessing camera: $e');
        Get.snackbar('Error', 'Could not access the camera');
      }
    }

    // Use the keyboard visibility package
    return KeyboardVisibilityBuilder(
      builder: (context, isKeyboardVisible) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Obx(() {
            // Only use isSendingMessage for actual network state, not UI
            final showMediaButtons =
                !isTyping.value && !isSending.value && !isEditingMessage.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                color:
                    isEditingMessage.value
                        ? Colors.blue.withOpacity(0.1)
                        : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(30),
                border:
                    isEditingMessage.value
                        ? Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        )
                        : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Media buttons (camera, etc.) - only visible when not typing
                  AnimatedOpacity(
                    opacity: showMediaButtons ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutQuart,
                      width: showMediaButtons ? 45 : 0,
                      padding: const EdgeInsets.only(left: 8.0),
                      child:
                          showMediaButtons
                              ? Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0060FF),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  onPressed: handleCameraPress,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                ),
                              )
                              : null,
                    ),
                  ),

                  // Text input field
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: controller.messageController,
                        focusNode: inputFocusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              isEditingMessage.value
                                  ? 'Edit message...'
                                  : 'Send Yap',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => handleSendMessage(),
                        enabled:
                            !isSending.value, // Disable during send animation
                      ),
                    ),
                  ),

                  // Right side - either send button or media buttons
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeOutQuart,
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child:
                        isTyping.value ||
                                isSending.value ||
                                isEditingMessage.value
                            ? _buildSendButton(
                              isSending.value,
                              handleSendMessage,
                            ) // Send button when typing or editing
                            : _buildMediaButtons(), // Media buttons otherwise
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // Build send button widget
  Widget _buildSendButton(bool isSending, VoidCallback onSend) {
    return Container(
      key: const ValueKey('send_button'),
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.cyan,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSending ? null : onSend,
          splashColor: Colors.cyan.withOpacity(0.3),
          highlightColor: Colors.cyan.withOpacity(0.2),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: AnimatedOpacity(
              opacity: isSending ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  // Build media buttons row (image, sticker, voice)
  Widget _buildMediaButtons() {
    return Container(
      key: const ValueKey('media_buttons'),
      margin: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image button
          IconButton(
            icon: Image.asset(
              'assets/icons/picture.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            onPressed: () => _handleImagePress(chatId),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: EdgeInsets.zero,
          ),
          // Sticker button
          IconButton(
            icon: Image.asset(
              'assets/icons/sticker_icon.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            onPressed: () => _handleStickerPress(chatId),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: EdgeInsets.zero,
          ),
          // Voice button
          IconButton(
            icon: Image.asset(
              'assets/icons/voice.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            onPressed: () => _handleVoicePress(chatId),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // Handle camera button press with safer context handling
  void _handleCameraPress(String chatId) async {
    try {
      final controller = Get.find<ChatController>();

      // Make sure we have a valid chat ID
      if (chatId.isEmpty) {
        Get.snackbar('Error', 'Could not send image: Invalid chat');
        return;
      }

      // Store the context reference since we'll use it after async operations
      final BuildContext? currentContext = Get.context;
      if (currentContext == null) {
        debugPrint('Error: Context is null when trying to access camera');
        return;
      }

      // Use a safer approach to avoid context issues
      final navigator = Navigator.of(currentContext);

      // Use controller method with better error handling
      final picker = ImagePicker();
      try {
        final image = await picker.pickImage(source: ImageSource.camera);

        // Only proceed if we got an image and are still in the same context
        if (image != null && navigator.mounted) {
          // Copy the chatId to ensure we're using the correct value
          final String safeChatId = chatId;
          controller.uploadAndSendImage(safeChatId, image);
        }
      } catch (e) {
        debugPrint('Camera error: $e');
        if (navigator.mounted) {
          Get.snackbar('Error', 'Could not access camera: ${e.toString()}');
        }
      }
    } catch (e) {
      debugPrint('Camera function error: $e');
      Get.snackbar('Error', 'Problem with camera functionality');
    }
  }

  // Handle image selection with safer context handling
  void _handleImagePress(String chatId) async {
    try {
      final controller = Get.find<ChatController>();

      // Make sure we have a valid chat ID
      if (chatId.isEmpty) {
        Get.snackbar('Error', 'Could not send image: Invalid chat');
        return;
      }

      // Store the context reference since we'll use it after async operations
      final BuildContext? currentContext = Get.context;
      if (currentContext == null) {
        debugPrint('Error: Context is null when trying to access gallery');
        return;
      }

      // Use a safer approach to avoid context issues
      final navigator = Navigator.of(currentContext);

      // Use controller method with error handling
      final picker = ImagePicker();
      try {
        final image = await picker.pickImage(source: ImageSource.gallery);

        // Only proceed if we got an image and are still in the same context
        if (image != null && navigator.mounted) {
          // Copy the chatId to ensure we're using the correct value
          final String safeChatId = chatId;
          controller.uploadAndSendImage(safeChatId, image);
        }
      } catch (e) {
        debugPrint('Gallery error: $e');
        if (navigator.mounted) {
          Get.snackbar('Error', 'Could not select image: ${e.toString()}');
        }
      }
    } catch (e) {
      debugPrint('Gallery function error: $e');
      Get.snackbar('Error', 'Problem accessing gallery');
    }
  }

  // Handle sticker press
  void _handleStickerPress(String chatId) {
    Get.snackbar(
      'Yap Stickers',
      'Stickers will be coming soon!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.grey.shade900,
      borderRadius: 20,
      margin: const EdgeInsets.all(16),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.emoji_emotions, color: Colors.amber),
    );
  }

  // Handle voice recording
  void _handleVoicePress(String chatId) {
    final controller = Get.find<ChatController>();
    // Use controller method
    controller.sendVoiceMessage(chatId);
  }

  // Cancel editing message
  static void cancelEditMessage() {
    final controller = Get.find<ChatController>();

    // Clear the message being edited
    messageBeingEdited.value = null;
    isEditingMessage.value = false;

    // Clear the text field
    controller.messageController.clear();

    // Update UI
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

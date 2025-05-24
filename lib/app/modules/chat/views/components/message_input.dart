import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/modules/chat/controllers/audio_controller.dart';
import '../../controllers/chat_controller.dart';
import 'audio_recorder.dart';

class MessageInput extends StatefulWidget {
  final String chatId;
  const MessageInput({super.key, required this.chatId});

  // Static variables for message editing
  static final RxBool isEditingMessage = false.obs;
  static final Rx<Map<String, dynamic>?> messageBeingEdited =
      Rx<Map<String, dynamic>?>(null);

  static void cancelEditMessage() {
    final controller = Get.find<ChatController>();
    messageBeingEdited.value = null;
    isEditingMessage.value = false;
    controller.messageController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late final ChatController controller;
  late final AudioMessageController audioController;
  late final TextEditingController textController;
  late final FocusNode inputFocusNode;

  final RxBool isTyping = false.obs;
  final RxBool isSending = false.obs;
  Timer? debounceTimer;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ChatController>();
    // Create audio controller for recording functionality
    audioController = Get.put(
      AudioMessageController(),
      tag: 'recording_${widget.chatId}',
    );
    textController = controller.messageController;
    inputFocusNode = FocusNode();

    // Listen for text changes with debounce
    textController.addListener(() {
      if (isSending.value) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 100), () {
        final hasText = textController.text.isNotEmpty;
        if (isTyping.value != hasText) {
          isTyping.value = hasText;
        }
      });
    });
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    inputFocusNode.dispose();
    // Clean up audio controller
    Get.delete<AudioMessageController>(tag: 'recording_${widget.chatId}');
    super.dispose();
  }

  void handleSendMessage() {
    final text = textController.text.trim();
    if (text.isEmpty || isSending.value) return;

    isSending.value = true;
    debounceTimer?.cancel();

    if (MessageInput.isEditingMessage.value &&
        MessageInput.messageBeingEdited.value != null) {
      final messageId = MessageInput.messageBeingEdited.value!['message_id'];
      controller.updateMessage(widget.chatId, messageId, text);

      MessageInput.messageBeingEdited.value = null;
      MessageInput.isEditingMessage.value = false;
      textController.clear();

      Future.delayed(const Duration(milliseconds: 200), () {
        isSending.value = false;
        isTyping.value = false;
      });
      return;
    }

    Future.delayed(const Duration(milliseconds: 50), () async {
      await controller.sendMessageUnified(
        chatId: widget.chatId,
        text: text,
        messageController: textController,
      );
      Future.delayed(const Duration(milliseconds: 200), () {
        isSending.value = false;
        final hasText = textController.text.isNotEmpty;
        if (isTyping.value != hasText) {
          isTyping.value = hasText;
        }
      });
    });
    textController.clear();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (widget.chatId.isEmpty) {
      Get.snackbar('Error', 'Could not send image: Invalid chat');
      return;
    }
    try {
      final currentContext = Get.context;
      if (currentContext == null) {
        debugPrint('Context is null, cannot pick image');
        return;
      }
      final navigator = Navigator.of(currentContext);
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null && navigator.mounted) {
        await controller.sendMessageUnified(
          chatId: widget.chatId,
          image: image,
        );
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      Get.snackbar(
        'Error',
        source == ImageSource.camera
            ? 'Could not access camera: $e'
            : 'Could not select image: $e',
      );
    }
  }

  void handleCameraPress() => _pickImage(ImageSource.camera);
  void handleGalleryPress() => _pickImage(ImageSource.gallery);

  void handleStickerPress() {
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

  void handleVoicePress() async {
    // Only start recording if we're not already recording
    if (!audioController.isRecording.value) {
      final success = await audioController.startRecording();
      if (!success) {
        Get.snackbar('Error', 'Could not start recording');
      }
    }
  }

  void handleStopRecording(String audioPath) async {
    // Use the provided audioPath directly instead of calling stopRecording again
    if (audioPath.isNotEmpty) {
      // Get the current recording duration
      final duration = audioController.recordingDuration.value;
      // Upload and send the audio using the chat controller
      await controller.sendMessageUnified(
        chatId: widget.chatId,
        audioPath: audioPath,
        audioDuration: duration,
      );
    }
  }

  void handleCancelRecording() async {
    await audioController.cancelRecording();
  }

  Widget _buildSendButton() {
    return Obx(() {
      return Container(
        key: const ValueKey('send_button'),
        margin: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.cyan,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isSending.value ? null : handleSendMessage,
            splashColor: Colors.cyan,
            highlightColor: Colors.cyan,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: AnimatedOpacity(
                opacity: isSending.value ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMediaButtons() {
    return Container(
      key: const ValueKey('media_buttons'),
      margin: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Image.asset(
              'assets/icons/picture.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            onPressed: handleGalleryPress,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Image.asset(
              'assets/icons/sticker_icon.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            onPressed: handleStickerPress,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Image.asset(
              'assets/icons/voice.png',
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            onPressed: handleVoicePress,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityBuilder(
      builder: (context, isKeyboardVisible) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                blurRadius: 4,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Obx(() {
            if (audioController.isRecording.value) {
              return AudioRecorder(
                onStopRecording: handleStopRecording,
                onCancelRecording: handleCancelRecording,
                chatId: widget.chatId,
              );
            }

            final showMediaButtons =
                !isTyping.value &&
                !isSending.value &&
                !MessageInput.isEditingMessage.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                color:
                    MessageInput.isEditingMessage.value
                        ? Colors.blue
                        : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(30),
                border:
                    MessageInput.isEditingMessage.value
                        ? Border.all(color: Colors.blue, width: 1)
                        : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: textController,
                        focusNode: inputFocusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              MessageInput.isEditingMessage.value
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
                        enabled: !isSending.value,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeOutQuart,
                    transitionBuilder:
                        (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                    child:
                        (isTyping.value ||
                                isSending.value ||
                                MessageInput.isEditingMessage.value)
                            ? _buildSendButton()
                            : _buildMediaButtons(),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

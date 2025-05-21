import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/modles/message_model.dart';
import 'chat_controller_messages.dart';
import 'chat_controller_search.dart';
import 'chat_controller_services.dart';

/// Controller for chat functionality
class ChatController extends GetxController
    with ChatControllerMessages, ChatControllerSearch, ChatControllerServices {
  // Core services
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  // State variables
  final RxBool isLoading = false.obs;
  final RxBool isSendingMessage = false.obs;
  final RxBool isInitialized = false.obs;

  List<MessageModel> get sortedMessages =>
      List.from(messages)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Active conversation state
  late RxList<MessageModel> messages = <MessageModel>[].obs;
  // Message input control
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final RxBool showEmojiPicker = false.obs;
  final RxBool isRecording = false.obs;

  // Pagination
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreMessages = true.obs;
  final int messagesPerPage = 20;

  // Added properties needed by views
  final RxString selectedChatId = ''.obs;
  final RxBool hasUserDismissedExpiryBanner = false.obs;
  final RxMap<String, double> localUploadProgress = <String, double>{}.obs;
  final RxSet<String> messagesToAnimate =
      <String>{}.obs; // Track messages that need animation

  // Recent chats functionality
  final RxList<Map<String, dynamic>> recentChats = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingChats = false.obs;

  // Search functionality
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;

  // Expose supabase service for views
  SupabaseService get supabaseService => _supabaseService;

  @override
  void onInit() {
    super.onInit();
    initializeServices();
    searchController.addListener(handleSearchInputChanged);
  }

  @override
  void onClose() {
    messageController.dispose();
    messageFocusNode.dispose();
    searchController.dispose();
    super.onClose();
  }

  // Method to call when message bubble animation completes
  void onMessageAnimationComplete(String messageId) {
    messagesToAnimate.remove(messageId);
  }
}

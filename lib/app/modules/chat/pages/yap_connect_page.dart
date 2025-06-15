import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/chat_controller.dart';
import 'create_group_page.dart';
import '../bindings/create_group_binding.dart';

class YapConnectPageController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final ChatController chatController = Get.find<ChatController>();
  final TextEditingController searchController = TextEditingController();
  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  // Cache for preloaded data
  final RxList<Map<String, dynamic>> cachedChats = <Map<String, dynamic>>[].obs;
  final RxBool isPreloading = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Initialize animation controller for smooth entrance
    animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Preload data immediately
    _preloadData();

    // Add listener to search controller
    searchController.addListener(() {
      chatController.searchUsers(searchController.text);
    });

    // Listen to changes in recent chats to update cached data
    ever(chatController.recentChats, (List<Map<String, dynamic>> chats) {
      if (chats.isNotEmpty && cachedChats.isEmpty) {
        cachedChats.value = List.from(chats);
        _preloadAvatars();
      }
    });
  }

  void _preloadData() {
    // Start animation immediately
    animationController.forward();

    // Use cached data if available
    if (chatController.recentChats.isNotEmpty) {
      cachedChats.value = List.from(chatController.recentChats);
      // Preload avatars in background
      _preloadAvatars();
    } else {
      // If no cached data, trigger a quick load
      isPreloading.value = true;
      chatController.preloadRecentChats().then((_) {
        if (chatController.recentChats.isNotEmpty) {
          cachedChats.value = List.from(chatController.recentChats);
          _preloadAvatars();
        }
        isPreloading.value = false;
      });
    }
  }

  void _preloadAvatars() {
    if (cachedChats.isEmpty) return;

    // Preload avatars for all recent chats asynchronously
    Future.microtask(() async {
      final avatarUrls = <String>{};

      for (final chat in cachedChats) {
        // Use the proper keys from the chat data structure
        String? avatar = chat['other_avatar'];
        String? googleAvatar = chat['other_google_avatar'];

        // Add effective avatar URL (use Set to avoid duplicates)
        if (avatar != null &&
            avatar != "skiped" &&
            avatar.isNotEmpty &&
            AvatarUtils.isValidUrl(avatar)) {
          avatarUrls.add(avatar);
        } else if (googleAvatar != null &&
            googleAvatar != "skiped" &&
            googleAvatar.isNotEmpty &&
            AvatarUtils.isValidUrl(googleAvatar)) {
          avatarUrls.add(googleAvatar);
        }
      }

      // Preload all avatar images in parallel
      final preloadFutures =
          avatarUrls.map((url) {
            if (Get.context != null) {
              return precacheImage(
                CachedNetworkImageProvider(url),
                Get.context!,
              );
            }
            return Future.value();
          }).toList();

      try {
        await Future.wait(preloadFutures, eagerError: false);
        debugPrint('Preloaded ${avatarUrls.length} avatars for YapConnect');
      } catch (e) {
        debugPrint('Error preloading avatars: $e');
      }
    });
  }

  @override
  void onClose() {
    animationController.dispose();
    searchController.dispose();
    super.onClose();
  }
}

class YapConnectPage extends GetView<YapConnectPageController> {
  const YapConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "YapConnect",
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.dongle().fontFamily,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: controller.fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: controller.fadeAnimation,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: TextField(
                    controller: controller.searchController,
                    decoration: InputDecoration(
                      hintText: 'Search yappers',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF171717),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                // Create Group Box
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Get.to(
                        () => const CreateGroupPage(),
                        binding: CreateGroupBinding(),
                        transition: Transition.rightToLeftWithFade,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101010),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Blue circle with icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xff7900FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group_add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Create Group text
                          const Text(
                            'Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // add a text named suggested from left 10
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text(
                      'Suggested',
                      style: TextStyle(
                        color: Color(0xFFE5E5E5),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: GoogleFonts.roboto().fontFamily,
                      ),
                    ),
                  ),
                ),

                // Recent Chat People List
                Expanded(child: _buildChatsList()),
              ],
            ),
          );
        },
      ),
      floatingActionButton: BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildChatsList() {
    return Obx(() {
      // Use cached data first, then fall back to reactive data
      final chatsToShow =
          controller.cachedChats.isNotEmpty
              ? controller.cachedChats
              : controller.chatController.recentChats;

      if (chatsToShow.isEmpty) {
        return controller.isPreloading.value
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : const Center(
              child: Text(
                'No recent chats',
                style: TextStyle(color: Colors.grey),
              ),
            );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chatsToShow.length,
        itemBuilder: (context, index) {
          final chat = chatsToShow[index];
          return _buildPersonTile(chat);
        },
      );
    });
  }

  Widget _buildPersonTile(Map<String, dynamic> chat) {
    // Use the proper keys from the chat data structure
    final otherUserId = chat['other_id'] ?? '';
    final otherUserName = chat['other_username'] ?? 'Unknown User';
    final otherUserAvatar = chat['other_avatar'];
    final otherUserGoogleAvatar = chat['other_google_avatar'];

    // Use Google avatar if regular avatar is "skiped"
    String? effectiveAvatar = otherUserAvatar;
    if (otherUserAvatar == "skiped" ||
        otherUserAvatar == null ||
        otherUserAvatar.isEmpty) {
      effectiveAvatar = otherUserGoogleAvatar;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      leading: _buildOptimizedAvatar(effectiveAvatar, otherUserName),
      title: Text(
        otherUserName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        "@${chat['username']}",
        style: const TextStyle(color: Colors.grey, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        // Navigate to chat with this user
        Get.toNamed(
          '/chat-window',
          arguments: {
            'recipientId': otherUserId,
            'recipientName': otherUserName,
            'recipientAvatar': effectiveAvatar,
          },
        );
      },
    );
  }

  Widget _buildOptimizedAvatar(String? avatarUrl, String userName) {
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl != "skiped" &&
        AvatarUtils.isValidUrl(avatarUrl)) {
      return CircleAvatar(
        radius: 20,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Text(
                  AvatarUtils.getInitials(userName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            errorWidget:
                (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: Text(
                    AvatarUtils.getInitials(userName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            memCacheWidth: 96,
            memCacheHeight: 96,
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 24,
        child: Text(
          AvatarUtils.getInitials(userName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }
}

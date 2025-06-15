import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_controller.dart';
import 'group_controller.dart';

class CreateGroupController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final ChatController chatController = Get.find<ChatController>();
  final GroupController groupController = Get.find<GroupController>();
  final TextEditingController searchController = TextEditingController();
  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  // Selected users for the group
  final RxList<Map<String, dynamic>> selectedUsers =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredUsers =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCreatingGroup = false.obs;

  // Maximum group members
  static const int maxMembers = 20;

  @override
  void onInit() {
    super.onInit();

    // Initialize animation controller
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

    // Start animation
    animationController.forward();

    // Load users from recent chats
    _loadUsers();

    // Add search listener
    searchController.addListener(_filterUsers);
  }

  void _loadUsers() {
    isLoading.value = true;

    // Get unique users from recent chats
    final users = <String, Map<String, dynamic>>{};

    for (final chat in chatController.recentChats) {
      final otherUserId = chat['other_id'];
      final otherUserName = chat['other_username'];
      final otherUserAvatar = chat['other_avatar'];
      final otherUserGoogleAvatar = chat['other_google_avatar'];

      if (otherUserId != null && otherUserName != null) {
        users[otherUserId] = {
          'id': otherUserId,
          'username': otherUserName,
          'avatar': otherUserAvatar,
          'google_avatar': otherUserGoogleAvatar,
        };
      }
    }

    allUsers.value = users.values.toList();
    filteredUsers.value = List.from(allUsers);
    isLoading.value = false;
  }

  void _filterUsers() {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      filteredUsers.value = List.from(allUsers);
    } else {
      filteredUsers.value =
          allUsers.where((user) {
            final username = user['username']?.toString().toLowerCase() ?? '';
            return username.contains(query);
          }).toList();
    }
  }

  void toggleUserSelection(Map<String, dynamic> user) {
    final userId = user['id'];
    final existingIndex = selectedUsers.indexWhere((u) => u['id'] == userId);

    if (existingIndex >= 0) {
      // Remove user
      selectedUsers.removeAt(existingIndex);
    } else {
      // Add user if not at max capacity
      if (selectedUsers.length < maxMembers) {
        selectedUsers.add(user);
      } else {
        Get.snackbar(
          'Limit Reached',
          'You can only add up to $maxMembers members',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  bool isUserSelected(String userId) {
    return selectedUsers.any((user) => user['id'] == userId);
  }

  Future<void> createGroup() async {
    if (selectedUsers.isEmpty) {
      Get.snackbar(
        'No Members Selected',
        'Please select at least one member to create a group',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isCreatingGroup.value = true;

      // Extract member IDs
      final memberIds =
          selectedUsers.map((user) => user['id'] as String).toList();

      // Create group using GroupController
      final groupId = await groupController.createGroup(
        name: 'Group Chat', // Default name, can be customized later
        memberIds: memberIds,
        description: 'Created with ${selectedUsers.length} members',
      );

      if (groupId != null) {
        Get.snackbar(
          'Success',
          'Group created successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Navigate back to chat view
        Get.back();

        // Optionally navigate to the new group chat
        // Get.toNamed('/group-chat', arguments: {'groupId': groupId});
      } else {
        Get.snackbar(
          'Error',
          'Failed to create group. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error creating group: $e');
      Get.snackbar(
        'Error',
        'An error occurred while creating the group',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isCreatingGroup.value = false;
    }
  }

  @override
  void onClose() {
    animationController.dispose();
    searchController.dispose();
    super.onClose();
  }
}

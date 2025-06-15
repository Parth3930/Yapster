import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/create_group_controller.dart';

class CreateGroupPage extends GetView<CreateGroupController> {
  const CreateGroupPage({super.key});

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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "New Group",
              style: TextStyle(
                color: Colors.white,
                fontFamily: GoogleFonts.dongle().fontFamily,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Member count - moved closer to title
            Transform.translate(
              offset: const Offset(0, -8),
              child: Obx(
                () => Text(
                  '${controller.selectedUsers.length} to ${CreateGroupController.maxMembers} members',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Obx(
            () => TextButton(
              onPressed:
                  controller.isCreatingGroup.value
                      ? null
                      : (controller.selectedUsers.isNotEmpty
                          ? controller.createGroup
                          : null),
              child:
                  controller.isCreatingGroup.value
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                      : Text(
                        'Create',
                        style: TextStyle(
                          color:
                              controller.selectedUsers.isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
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
                      hintText: 'Search users',
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

                // Users list
                Expanded(child: _buildUsersList()),
              ],
            ),
          );
        },
      ),
      floatingActionButton: BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildUsersList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        );
      }

      if (controller.filteredUsers.isEmpty) {
        return const Center(
          child: Text('No users found', style: TextStyle(color: Colors.grey)),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.filteredUsers.length,
        itemBuilder: (context, index) {
          final user = controller.filteredUsers[index];
          return _buildUserTile(user);
        },
      );
    });
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id'] ?? '';
    final userName = user['username'] ?? 'Unknown User';
    final userAvatar = user['avatar'];
    final userGoogleAvatar = user['google_avatar'];

    // Use Google avatar if regular avatar is "skiped"
    String? effectiveAvatar = userAvatar;
    if (userAvatar == "skiped" || userAvatar == null || userAvatar.isEmpty) {
      effectiveAvatar = userGoogleAvatar;
    }

    return Obx(
      () => ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        leading: _buildOptimizedAvatar(effectiveAvatar, userName),
        title: Text(
          userName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  controller.isUserSelected(userId) ? Colors.blue : Colors.grey,
              width: 2,
            ),
            color:
                controller.isUserSelected(userId)
                    ? Colors.blue
                    : Colors.transparent,
          ),
          child:
              controller.isUserSelected(userId)
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
        ),
        onTap: () => controller.toggleUserSelection(user),
      ),
    );
  }

  Widget _buildOptimizedAvatar(String? avatarUrl, String userName) {
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl != "skiped" &&
        AvatarUtils.isValidUrl(avatarUrl)) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[800],
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Container(
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
        backgroundColor: Colors.grey[800],
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

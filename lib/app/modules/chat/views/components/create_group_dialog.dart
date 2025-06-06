import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/modules/chat/controllers/group_controller.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';

class CreateGroupDialog extends StatefulWidget {
  final String? currentChatUserId;
  final String? currentChatUsername;

  const CreateGroupDialog({
    super.key,
    this.currentChatUserId,
    this.currentChatUsername,
  });

  static void show({
    required BuildContext context,
    String? currentChatUserId,
    String? currentChatUsername,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CreateGroupDialog(
            currentChatUserId: currentChatUserId,
            currentChatUsername: currentChatUsername,
          ),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final RxList<String> selectedUserIds = <String>[].obs;
  final RxBool isCreating = false.obs;
  final RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredUsers =
      <Map<String, dynamic>>[].obs;

  late final GroupController groupController;
  late final AccountDataProvider accountProvider;

  @override
  void initState() {
    super.initState();

    // Get or create controllers
    try {
      groupController = Get.find<GroupController>();
    } catch (e) {
      groupController = GroupController();
      Get.put(groupController);
    }

    accountProvider = Get.find<AccountDataProvider>();

    // Add current chat user if provided
    if (widget.currentChatUserId != null) {
      selectedUserIds.add(widget.currentChatUserId!);
    }

    // Load all available users
    _loadAllUsers();

    // Set up search listener
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Load all available users from multiple sources
  void _loadAllUsers() {
    final Set<String> addedUserIds = {};
    final List<Map<String, dynamic>> users = [];

    // Get chat controller for recent chats
    try {
      final chatController = Get.find<ChatController>();

      // Add users from recent chats
      for (final chat in chatController.recentChats) {
        final userId = chat['other_user_id'] ?? chat['other_id'];
        final username = chat['other_username'] ?? chat['username'];
        final nickname = chat['other_nickname'] ?? chat['nickname'];

        // Handle avatar with 'skiped' fallback to google_avatar
        String? avatar;
        final otherAvatar = chat['other_avatar'] ?? chat['avatar'];
        final otherGoogleAvatar =
            chat['other_google_avatar'] ?? chat['google_avatar'];

        if (otherAvatar == 'skiped' ||
            otherAvatar == null ||
            otherAvatar.isEmpty) {
          avatar =
              otherGoogleAvatar?.isNotEmpty == true ? otherGoogleAvatar : null;
        } else {
          avatar = otherAvatar.isNotEmpty ? otherAvatar : null;
        }

        if (userId != null && !addedUserIds.contains(userId)) {
          addedUserIds.add(userId);
          users.add({
            'user_id': userId,
            'username': username ?? 'Unknown',
            'nickname': nickname,
            'avatar': avatar,
            'source': 'recent_chat',
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
    }

    // Add users from following
    for (final user in accountProvider.following) {
      final userId = user['following_id'];
      if (userId != null && !addedUserIds.contains(userId)) {
        addedUserIds.add(userId);

        // Handle avatar with 'skiped' fallback to google_avatar
        String? avatar;
        final userAvatar = user['avatar'];
        final userGoogleAvatar = user['google_avatar'];

        if (userAvatar == 'skiped' ||
            userAvatar == null ||
            userAvatar.isEmpty) {
          avatar =
              userGoogleAvatar?.isNotEmpty == true ? userGoogleAvatar : null;
        } else {
          avatar = userAvatar.isNotEmpty ? userAvatar : null;
        }

        users.add({
          'user_id': userId,
          'username': user['username'] ?? 'Unknown',
          'nickname': user['nickname'],
          'avatar': avatar,
          'source': 'following',
        });
      }
    }

    // Add users from followers
    for (final user in accountProvider.followers) {
      final userId = user['follower_id'];
      if (userId != null && !addedUserIds.contains(userId)) {
        addedUserIds.add(userId);

        // Handle avatar with 'skiped' fallback to google_avatar
        String? avatar;
        final userAvatar = user['avatar'];
        final userGoogleAvatar = user['google_avatar'];

        if (userAvatar == 'skiped' ||
            userAvatar == null ||
            userAvatar.isEmpty) {
          avatar =
              userGoogleAvatar?.isNotEmpty == true ? userGoogleAvatar : null;
        } else {
          avatar = userAvatar.isNotEmpty ? userAvatar : null;
        }

        users.add({
          'user_id': userId,
          'username': user['username'] ?? 'Unknown',
          'nickname': user['nickname'],
          'avatar': avatar,
          'source': 'follower',
        });
      }
    }

    // Sort users: recent chats first, then alphabetically
    users.sort((a, b) {
      if (a['source'] == 'recent_chat' && b['source'] != 'recent_chat') {
        return -1;
      } else if (a['source'] != 'recent_chat' && b['source'] == 'recent_chat') {
        return 1;
      } else {
        final nameA =
            a['nickname']?.isNotEmpty == true ? a['nickname'] : a['username'];
        final nameB =
            b['nickname']?.isNotEmpty == true ? b['nickname'] : b['username'];
        return nameA.toString().toLowerCase().compareTo(
          nameB.toString().toLowerCase(),
        );
      }
    });

    allUsers.value = users;
    filteredUsers.value = users;
  }

  // Filter users based on search query
  void _filterUsers() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      filteredUsers.value = allUsers;
    } else {
      filteredUsers.value =
          allUsers.where((user) {
            final username = user['username']?.toString().toLowerCase() ?? '';
            final nickname = user['nickname']?.toString().toLowerCase() ?? '';
            return username.contains(query) || nickname.contains(query);
          }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Create Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group icon placeholder
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[700]!, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          'YAP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                  // Group name input
                  TextField(
                    controller: _groupNameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Group description input
                  TextField(
                    controller: _groupDescriptionController,
                    style: TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Members section
                  Text(
                    'Add Members',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 12),

                  // Search field styled like the image
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search Yappers',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Selected members count and clear button
                  Obx(
                    () =>
                        selectedUserIds.isNotEmpty
                            ? Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.group,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${selectedUserIds.length} member(s) selected',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Spacer(),
                                  TextButton(
                                    onPressed: () => selectedUserIds.clear(),
                                    child: Text(
                                      'Clear All',
                                      style: TextStyle(
                                        color: Colors.red[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : SizedBox.shrink(),
                  ),

                  // Members list container with fixed height
                  SizedBox(height: 300, child: _buildMembersList()),

                  SizedBox(height: 100), // Extra space for fixed button
                ],
              ),
            ),
          ),

          // Fixed create button at bottom
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                top: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
            ),
            child: Obx(
              () => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      isCreating.value ||
                              _groupNameController.text.trim().isEmpty
                          ? null
                          : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isCreating.value
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Obx(() {
      if (filteredUsers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
              SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No users found'
                    : 'No contacts available',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Try a different search term'
                    : 'Start chatting with people to add them to groups',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          final userId = user['user_id'];
          final username = user['username'] ?? 'Unknown';
          final nickname = user['nickname'];
          final avatar = user['avatar'];
          final source = user['source'];

          // Determine display name
          final displayName =
              nickname?.isNotEmpty == true ? nickname : username;

          // Source indicator color
          Color? sourceColor;
          String? sourceLabel;
          switch (source) {
            case 'recent_chat':
              sourceColor = Colors.green;
              sourceLabel = 'Recent';
              break;
            case 'following':
              sourceColor = Colors.blue;
              sourceLabel = 'Following';
              break;
            case 'follower':
              sourceColor = Colors.orange;
              sourceLabel = 'Follower';
              break;
          }

          return Obx(
            () => Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[800],
                      backgroundImage:
                          avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                      child:
                          avatar == null || avatar.isEmpty
                              ? Icon(Icons.person, color: Colors.grey[600])
                              : null,
                    ),
                    if (selectedUserIds.contains(userId))
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      nickname?.isNotEmpty == true ? '@$username' : username,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    if (sourceLabel != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: sourceColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          sourceLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  if (selectedUserIds.contains(userId)) {
                    selectedUserIds.remove(userId);
                  } else {
                    selectedUserIds.add(userId);
                  }
                },
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter a group name');
      return;
    }

    if (selectedUserIds.isEmpty) {
      Get.snackbar('Error', 'Please select at least one member');
      return;
    }

    isCreating.value = true;

    try {
      final groupId = await groupController.createGroup(
        name: _groupNameController.text.trim(),
        description:
            _groupDescriptionController.text.trim().isEmpty
                ? null
                : _groupDescriptionController.text.trim(),
        memberIds: selectedUserIds.toList(),
      );

      if (groupId != null) {
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Navigate to the group chat
        Get.toNamed(
          '/group-chat',
          arguments: {
            'groupId': groupId,
            'groupName': _groupNameController.text.trim(),
          },
        );

        Get.snackbar(
          'Success',
          'Group created successfully!',
          backgroundColor: Colors.green[800],
          colorText: Colors.white,
        );
      } else {
        Get.snackbar('Error', 'Failed to create group');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to create group: $e');
    } finally {
      isCreating.value = false;
    }
  }
}

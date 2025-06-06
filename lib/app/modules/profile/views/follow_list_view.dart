import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/models/follow_type.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';

class FollowListView extends StatefulWidget {
  final String userId;
  final FollowType type;
  final String title;

  const FollowListView({
    required this.userId,
    required this.type,
    required this.title,
    super.key,
  });

  @override
  State<FollowListView> createState() => _FollowListViewState();
}

class _FollowListViewState extends State<FollowListView> {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  late ExploreController _exploreController;
  late AccountDataProvider _accountDataProvider;

  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final TextEditingController searchController = TextEditingController();

  final int pageSize = 50;
  final RxBool hasMoreData = true.obs;
  final RxBool isLoadingMore = false.obs;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ensure ExploreController exists
    try {
      _exploreController = Get.find<ExploreController>();
    } catch (e) {
      debugPrint('ExploreController not found, initializing: $e');
      _exploreController = Get.put(ExploreController());
    }

    _accountDataProvider = Get.find<AccountDataProvider>();

    // First refresh the current user's following list to ensure accurate following status
    final currentUserId = _supabaseService.currentUser.value?.id;
    if (currentUserId != null) {
      _accountDataProvider.loadFollowing(currentUserId).then((_) {
        debugPrint('Refreshed following data before showing follow list');
      });
    }

    loadUsers();

    // Add scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isLoading.value &&
          !isLoadingMore.value &&
          hasMoreData.value) {
        loadMoreUsers();
      }
    });

    // Add search listener
    searchController.addListener(() {
      searchQuery.value = searchController.text;
      if (searchQuery.isEmpty) {
        // Reset search results
        loadUsers();
      } else {
        // Filter results based on search
        searchUsers();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    try {
      isLoading.value = true;
      users.clear();

      final response = await _supabaseService.client.rpc(
        widget.type == FollowType.followers ? 'get_followers' : 'get_following',
        params: {'p_user_id': widget.userId},
      );

      if (response != null) {
        final List<Map<String, dynamic>> userList =
            List<Map<String, dynamic>>.from(response);
        if (userList.length < pageSize) {
          hasMoreData.value = false;
        } else {
          hasMoreData.value = true;
        }
        users.value = userList.take(pageSize).toList();
        debugPrint('Loaded ${users.length} users');
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreUsers() async {
    try {
      isLoadingMore.value = true;

      final response = await _supabaseService.client.rpc(
        widget.type == FollowType.followers ? 'get_followers' : 'get_following',
        params: {'p_user_id': widget.userId},
      );

      if (response != null) {
        final List<Map<String, dynamic>> allUsers =
            List<Map<String, dynamic>>.from(response);

        // Only add users that aren't already loaded
        final newUsers =
            allUsers
                .where((user) {
                  final id =
                      widget.type == FollowType.followers
                          ? user['follower_id']
                          : user['following_id'];
                  return !users.any((existingUser) {
                    final existingId =
                        widget.type == FollowType.followers
                            ? existingUser['follower_id']
                            : existingUser['following_id'];
                    return existingId == id;
                  });
                })
                .take(pageSize)
                .toList();

        if (newUsers.isEmpty) {
          hasMoreData.value = false;
        } else {
          users.addAll(newUsers);
          debugPrint('Added ${newUsers.length} more users');
        }
      }
    } catch (e) {
      debugPrint('Error loading more users: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  void searchUsers() {
    if (searchQuery.isEmpty) return;

    // Filter users based on search query
    final query = searchQuery.value.toLowerCase();
    isLoading.value = true;

    try {
      _supabaseService.client
          .rpc(
            widget.type == FollowType.followers
                ? 'get_followers'
                : 'get_following',
            params: {'p_user_id': widget.userId},
          )
          .then((response) {
            if (response != null) {
              final List<Map<String, dynamic>> allUsers =
                  List<Map<String, dynamic>>.from(response);

              // Filter by username or nickname
              final filteredUsers =
                  allUsers.where((user) {
                    final username =
                        (user['username'] ?? '').toString().toLowerCase();
                    final nickname =
                        (user['nickname'] ?? '').toString().toLowerCase();
                    return username.contains(query) || nickname.contains(query);
                  }).toList();

              users.value = filteredUsers;
              debugPrint(
                'Found ${filteredUsers.length} users matching "$query"',
              );
            }
            isLoading.value = false;
          });
    } catch (e) {
      debugPrint('Error searching users: $e');
      isLoading.value = false;
    }
  }

  void openUserProfile(Map<String, dynamic> user) {
    final userId =
        widget.type == FollowType.followers
            ? user['follower_id']
            : user['following_id'];

    if (userId != null) {
      // Convert to the user format expected by the explore controller
      final formattedUser = {
        'user_id': userId,
        'username': user['username'],
        'nickname': user['nickname'],
        'avatar': user['avatar'],
        'google_avatar': user['google_avatar'],
      };

      _exploreController.openUserProfile(formattedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the title based on the type of list we're displaying
    final String displayTitle =
        widget.type == FollowType.followers ? widget.title : "Following";

    return Scaffold(
      appBar: CustomAppBar(title: displayTitle),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (users.isEmpty) {
                return Center(
                  child: Text(
                    widget.type == FollowType.followers
                        ? 'No followers yet'
                        : 'Not following anyone yet',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  // Refresh the current user's following data
                  final currentUserId = _supabaseService.currentUser.value?.id;
                  if (currentUserId != null) {
                    await _accountDataProvider.loadFollowing(currentUserId);
                    debugPrint('Refreshed following data on pull');
                  }

                  // Reload the user list
                  await loadUsers();
                  debugPrint('Refreshed user list data on pull');
                },
                color: Color(0xff0060FF),
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: users.length + (hasMoreData.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at the bottom while loading more
                    if (index == users.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final user = users[index];
                    return _buildUserListItem(user);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(60),
        ),
        child: TextField(
          controller: searchController,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            hintText:
                'Search ${widget.type == FollowType.followers ? 'followers' : 'following'}',
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Icon(Icons.search, color: Color(0xFFAAAAAA)),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: Obx(
              () =>
                  searchQuery.isNotEmpty
                      ? IconButton(
                        icon: Icon(Icons.close, color: Color(0xFFAAAAAA)),
                        onPressed: () {
                          searchController.clear();
                        },
                      )
                      : SizedBox.shrink(),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final userId =
        widget.type == FollowType.followers
            ? user['follower_id']
            : user['following_id'];

    final isCurrentUser = userId == _supabaseService.currentUser.value?.id;

    return InkWell(
      onTap: () => openUserProfile(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUserAvatar(user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['nickname'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@${user['username'] ?? ''}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Don't show follow button for current user
            if (!isCurrentUser)
              GetX<ExploreController>(
                init: _exploreController,
                initState: (_) {
                  // Ensure follow state is up to date when item is first shown
                  _exploreController.refreshFollowState(userId);
                },
                builder: (controller) {
                  final bool isFollowing = controller.isFollowingUser(userId);

                  if (widget.type == FollowType.followers) {
                    // If we're already following them, don't show any button
                    if (isFollowing) {
                      return const SizedBox.shrink();
                    }
                    // Only show Follow Back button if we're not already following them
                    return _buildFollowButton(userId, false);
                  }

                  // For Following list, always show Unfollow button since we're viewing following list
                  return _buildUnfollowButton(userId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> user) {
    // Check if user has regular avatar - make sure to handle "skiped" value
    final String? avatarUrl = user['avatar'];
    final bool hasSkippedAvatar = avatarUrl == "skiped" || avatarUrl == "null";

    final bool hasRegularAvatar =
        avatarUrl != null && avatarUrl.isNotEmpty && !hasSkippedAvatar;

    // Check if user has Google avatar
    final String? googleAvatarUrl = user['google_avatar'];
    final bool hasGoogleAvatar =
        googleAvatarUrl != null &&
        googleAvatarUrl.isNotEmpty &&
        googleAvatarUrl != "null";

    // If regular avatar is skipped but Google avatar exists, use Google avatar
    final bool shouldUseGoogleAvatar =
        (hasSkippedAvatar || !hasRegularAvatar) && hasGoogleAvatar;

    // Select the URL to use
    final String? imageUrl =
        hasRegularAvatar
            ? avatarUrl
            : (shouldUseGoogleAvatar ? googleAvatarUrl : null);

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[800],
      child:
          imageUrl != null
              ? CachedNetworkImage(
                imageUrl: imageUrl,
                imageBuilder:
                    (context, imageProvider) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                placeholder:
                    (context, url) => Container(
                      color: Colors.transparent,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading avatar from URL: $url - $error');
                  return const Icon(Icons.person, color: Colors.white);
                },
              )
              : const Icon(Icons.person, color: Colors.white),
    );
  }

  Widget _buildFollowButton(String userId, bool isFollowing) {
    final String buttonText =
        widget.type == FollowType.followers ? 'Follow Back' : 'Follow';
    final RxBool isButtonLoading = false.obs;

    return Obx(
      () => ElevatedButton(
        onPressed:
            isButtonLoading.value
                ? null
                : () => _handleFollowAction(userId, isButtonLoading),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff0060FF),
          minimumSize: const Size(90, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child:
            isButtonLoading.value
                ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Text(buttonText, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildUnfollowButton(String userId) {
    final RxBool isButtonLoading = false.obs;

    return Obx(
      () => ElevatedButton(
        onPressed:
            isButtonLoading.value
                ? null
                : () => _handleUnfollowAction(userId, isButtonLoading),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          minimumSize: const Size(90, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child:
            isButtonLoading.value
                ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text('Unfollow', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _handleFollowAction(String userId, RxBool isLoading) async {
    isLoading.value = true;
    try {
      await _exploreController.toggleFollowUser(userId);
      await _exploreController.refreshFollowState(userId);

      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId != null) {
        await _accountDataProvider.loadFollowing(currentUserId);
        await _exploreController.verifyDatabaseCounts(currentUserId, userId);
      }

      // Refresh the list
      await loadUsers();
    } catch (e) {
      debugPrint('Error following user: $e');
      Get.snackbar('Error', 'Failed to follow user');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handleUnfollowAction(String userId, RxBool isLoading) async {
    isLoading.value = true;
    try {
      await _exploreController.toggleFollowUser(userId);
      await _exploreController.refreshFollowState(userId);

      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId != null) {
        await _accountDataProvider.loadFollowing(currentUserId);
        await _exploreController.verifyDatabaseCounts(currentUserId, userId);
      }

      // Refresh the list and ensure UI is updated
      await loadUsers();
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      Get.snackbar('Error', 'Failed to unfollow user');
    } finally {
      isLoading.value = false;
    }
  }
}

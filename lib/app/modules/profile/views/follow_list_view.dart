import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/models/follow_type.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

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
    
    loadUsers();
    
    // Add scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200 &&
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
        final List<Map<String, dynamic>> userList = List<Map<String, dynamic>>.from(response);
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
        final List<Map<String, dynamic>> allUsers = List<Map<String, dynamic>>.from(response);
        
        // Only add users that aren't already loaded
        final newUsers = allUsers.where((user) {
          final id = widget.type == FollowType.followers 
              ? user['follower_id'] 
              : user['following_id'];
          return !users.any((existingUser) {
            final existingId = widget.type == FollowType.followers 
                ? existingUser['follower_id'] 
                : existingUser['following_id'];
            return existingId == id;
          });
        }).take(pageSize).toList();
        
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
      _supabaseService.client.rpc(
        widget.type == FollowType.followers ? 'get_followers' : 'get_following',
        params: {'p_user_id': widget.userId},
      ).then((response) {
        if (response != null) {
          final List<Map<String, dynamic>> allUsers = List<Map<String, dynamic>>.from(response);
          
          // Filter by username or nickname
          final filteredUsers = allUsers.where((user) {
            final username = (user['username'] ?? '').toString().toLowerCase();
            final nickname = (user['nickname'] ?? '').toString().toLowerCase();
            return username.contains(query) || nickname.contains(query);
          }).toList();
          
          users.value = filteredUsers;
          debugPrint('Found ${filteredUsers.length} users matching "$query"');
        }
        isLoading.value = false;
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
      isLoading.value = false;
    }
  }
  
  void openUserProfile(Map<String, dynamic> user) {
    final userId = widget.type == FollowType.followers 
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
    final String displayTitle = widget.type == FollowType.followers
        ? widget.title
        : "Following";
        
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
              
              return ListView.builder(
                controller: scrollController,
                itemCount: users.length + (hasMoreData.value ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator at the bottom while loading more
                  if (index == users.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  
                  final user = users[index];
                  return _buildUserListItem(user);
                },
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
            hintText: 'Search ${widget.type == FollowType.followers ? 'followers' : 'following'}',
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Icon(Icons.search, color: Color(0xFFAAAAAA)),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: Obx(() => searchQuery.isNotEmpty
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
    final userId = widget.type == FollowType.followers 
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['nickname'] ?? 'User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@${user['username'] ?? ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Don't show follow button for current user
            if (!isCurrentUser)
              widget.type == FollowType.followers 
                ? Obx(() {
                    final isFollowing = _exploreController.isFollowingUser(userId);
                    return _buildFollowButton(userId, isFollowing);
                  })
                : _buildUnfollowButton(userId),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserAvatar(Map<String, dynamic> user) {
    // Check if user has regular avatar
    final hasRegularAvatar = user['avatar'] != null && 
                           user['avatar'].toString().isNotEmpty && 
                           user['avatar'] != "skiped" &&
                           user['avatar'].toString() != "skiped" &&
                           user['avatar'].toString() != "null";
                           
    // Check if user has Google avatar
    final hasGoogleAvatar = user['google_avatar'] != null && 
                          user['google_avatar'].toString().isNotEmpty &&
                          user['google_avatar'].toString() != "null";
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[300],
      backgroundImage: hasRegularAvatar
          ? CachedNetworkImageProvider(user['avatar'])
          : hasGoogleAvatar
              ? CachedNetworkImageProvider(user['google_avatar'])
              : null,
      child: (!hasRegularAvatar && !hasGoogleAvatar)
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    );
  }
  
  Widget _buildFollowButton(String userId, bool isFollowing) {
    return ElevatedButton(
      onPressed: () async {
        // Get the previous state to determine if we're following or unfollowing
        final wasFollowing = _exploreController.isFollowingUser(userId);
        
        // Show loading indicator using EasyLoading
        EasyLoading.show(status: 'Processing...');
        
        // Toggle follow state
        await _exploreController.toggleFollowUser(userId);
        
        // Close loading indicator
        EasyLoading.dismiss();
        
        // Refresh to update the UI
        setState(() {});
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isFollowing ? Colors.grey[800] : Color(0xff0060FF),
        minimumSize: Size(90, 32),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        isFollowing ? 'Following' : 'Follow',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
  
  Widget _buildUnfollowButton(String userId) {
    return ElevatedButton(
      onPressed: () => _handleUnfollow(userId),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        minimumSize: Size(90, 32),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        'Unfollow',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
  
  void _handleUnfollow(String userId) async {
    try {
      // Show loading indicator using EasyLoading
      EasyLoading.show(status: 'Processing...');
      
      debugPrint('Trying to unfollow user: $userId');
      
      // Direct database delete instead of using RPC function
      final supabaseService = Get.find<SupabaseService>();
      final currentUserId = supabaseService.currentUser.value?.id;
      
      if (currentUserId == null) {
        EasyLoading.dismiss();
        Get.snackbar('Error', 'User not authenticated');
        return;
      }

      // Delete the follows record directly
      final result = await supabaseService.client
        .from('follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', userId);
      
      debugPrint('Delete follows result: $result');
      
      // Verify the unfollow worked
      final checkResponse = await supabaseService.client
        .from('follows')
        .select()
        .eq('follower_id', currentUserId)
        .eq('following_id', userId);
      
      debugPrint('After unfollow check - remaining records: ${(checkResponse as List).length}');
      
      // Get updated following count
      final followingResponse = await supabaseService.client
        .from('follows')
        .select()
        .eq('follower_id', currentUserId);
      
      final int followingCount = (followingResponse as List).length;
      
      // Update profile table with new counts (important!)
      await supabaseService.client
        .from('profiles')
        .update({'following_count': followingCount})
        .eq('user_id', currentUserId);
        
      debugPrint('Updated profile following_count to: $followingCount');
      
      // Close loading dialog
      EasyLoading.dismiss();
      
      // Remove user from the UI list
      users.removeWhere((user) => user['following_id'] == userId);
      
      // Update following count in account provider
      _accountDataProvider.followingCount.value = followingCount;
      
      // Refresh account provider following list
      await _accountDataProvider.loadFollowing(currentUserId);
      
      // If the list is now empty, show the empty state
      if (users.isEmpty) {
        setState(() {});
      }
      
      debugPrint('User unfollowed successfully. New following count: $followingCount');
            
    } catch (e) {
      EasyLoading.dismiss();
      debugPrint('Error handling unfollow: $e');
      Get.snackbar('Error', 'Failed to unfollow user: ${e.toString()}');
    }
  }
} 
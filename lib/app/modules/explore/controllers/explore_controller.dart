import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:yapster/app/modules/profile/views/user_profile_view.dart';
import 'dart:async';
import 'dart:convert';
import 'package:yapster/app/modules/profile/views/follow_list_view.dart';
import 'package:yapster/app/core/models/follow_type.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';

class ExploreController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final StorageService _storageService = Get.find<StorageService>();

  final searchController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recentSearches =
      <Map<String, dynamic>>[].obs;

  // Observable search text to properly work with Obx
  final RxString searchText = ''.obs;

  // The maximum number of recent searches to store
  static const int maxRecentSearches = 5;

  // Cache keys
  static const String searchCacheKey = 'last_search_results';

  // User profile posts data
  final RxList<Map<String, dynamic>> userPosts = <Map<String, dynamic>>[].obs;
  final RxInt selectedPostTypeTab = 0.obs;
  final RxMap<String, dynamic> selectedUserProfile = <String, dynamic>{}.obs;
  final RxBool isLoadingUserProfile = false.obs;

  // Debounce timer for search
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    // Debug: Clear search cache to start fresh
    _storageService.remove(searchCacheKey);

    loadRecentSearches();
    loadCachedSearchResults();

    // Add listener to search text field
    searchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.onClose();
  }

  void _onSearchChanged() {
    // Update the observable search text immediately for UI updates
    searchText.value = searchController.text;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (searchController.text.trim().isNotEmpty) {
        searchUsers(searchController.text.trim());
      } else {
        searchResults.clear();
      }
    });
  }

  Future<void> searchUsers(String query) async {
    try {
      isLoading.value = true;

      if (query.isEmpty) {
        searchResults.clear();
        return;
      }

      debugPrint('Searching for users with query: $query');
      
      // Get current user ID to filter them out from results
      final currentUserId = _supabaseService.currentUser.value?.id;

      // Search for users in Supabase where username contains the query
      // Include google_avatar in the query
      final response = await _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .ilike('username', '%$query%')
          .limit(20);

      // Convert to list and filter out current user
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);
      
      // Remove current user from search results if they appear
      if (currentUserId != null) {
        results = results.where((user) => user['user_id'] != currentUserId).toList();
        debugPrint('Filtered out current user from search results');
      }

      debugPrint('Found ${results.length} users matching query');
      searchResults.value = results;

      // Cache the search results
      cacheSearchResults(query, results);
    } catch (e) {
      debugPrint('Error searching users: $e');
      EasyLoading.showError('Search failed');
    } finally {
      isLoading.value = false;
    }
  }

  // Cache search results in SharedPreferences
  Future<void> cacheSearchResults(
    String query,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      // Cache the search results as a JSON string
      final resultsJson = jsonEncode(results);
      await _storageService.saveString(searchCacheKey, resultsJson);

      debugPrint('Cached search results for query: $query');
    } catch (e) {
      debugPrint('Error caching search results: $e');
    }
  }

  // Load cached search results on init
  void loadCachedSearchResults() {
    try {
      // Get cached results
      final cachedResultsJson = _storageService.getString(searchCacheKey);
      if (cachedResultsJson != null && cachedResultsJson.isNotEmpty) {
        final decodedResults = jsonDecode(cachedResultsJson) as List;
        final results =
            decodedResults
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

        // Update search results only if no active search is happening
        if (searchController.text.isEmpty) {
          searchResults.value = results;
          debugPrint('Loaded ${results.length} cached search results');

          // Debug info about the results
          for (var result in results) {
            debugPrint(
              'Cached result: ${result['username']}, ${result['user_id']}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached search results: $e');
    }
  }

  void loadRecentSearches() {
    try {
      // Force reload from database
      _accountDataProvider.loadSearches().then((_) {
        // After loading from database, update the local list
        recentSearches.value = List<Map<String, dynamic>>.from(
          _accountDataProvider.searches,
        );
        debugPrint(
          'Loaded ${recentSearches.length} recent searches from database',
        );

        // Debug info about recent searches
        for (var search in recentSearches) {
          debugPrint(
            'Recent search: ${search['username']}, ${search['user_id']}',
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> addToRecentSearches(Map<String, dynamic> user) async {
    try {
      // Make sure we have complete user data
      if (!user.containsKey('google_avatar')) {
        // Fetch complete profile data if we don't have google_avatar
        final userData = await _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .eq('user_id', user['user_id'])
          .single();
          
        // Update user with complete data
        user = Map<String, dynamic>.from(userData);
        debugPrint('Updated user data with complete profile including Google avatar');
            }
      
      // Check if user is already in recent searches
      final existingIndex = recentSearches.indexWhere(
        (item) => item['user_id'] == user['user_id'],
      );

      // If user is already in searches, remove it to re-add at the beginning
      if (existingIndex != -1) {
        recentSearches.removeAt(existingIndex);
      }

      // Add the user to the beginning of the list
      recentSearches.insert(0, user);

      // Keep only the max number of recent searches
      if (recentSearches.length > maxRecentSearches) {
        recentSearches.removeLast();
      }

      // Update AccountDataProvider searches
      await _accountDataProvider.updateSearches(recentSearches.toList());
    } catch (e) {
      debugPrint('Error adding to recent searches: $e');
    }
  }

  Future<void> removeFromRecentSearches(Map<String, dynamic> user) async {
    try {
      // Find and remove the user from recent searches
      final existingIndex = recentSearches.indexWhere(
        (item) => item['user_id'] == user['user_id'],
      );

      if (existingIndex != -1) {
        recentSearches.removeAt(existingIndex);

        // Update AccountDataProvider searches
        await _accountDataProvider.updateSearches(recentSearches.toList());
        debugPrint('Removed user from recent searches');
      }
    } catch (e) {
      debugPrint('Error removing from recent searches: $e');
    }
  }

  void clearSearch() {
    searchController.clear();
    searchText.value = '';
    searchResults.clear();
  }

  void openUserProfile(Map<String, dynamic> user) {
    // Add to recent searches
    addToRecentSearches(user);

    // Load user profile data before navigating
    loadUserProfile(user['user_id']).then((_) {
      // Navigate to user profile using the UserProfileView
      Get.to(
        () => UserProfileView(userData: selectedUserProfile, posts: userPosts),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  // Load a user's profile data and posts
  Future<void> loadUserProfile(String userId) async {
    try {
      isLoadingUserProfile.value = true;
      debugPrint('Loading profile for user ID: $userId');
      
      // Force refresh of followers/following data before loading profile
      if (userId == _supabaseService.currentUser.value?.id) {
        // For current user, reload their followers and following
        await _accountDataProvider.loadFollowers(userId);
        await _accountDataProvider.loadFollowing(userId);
      }

      // Update to select proper fields (without follower_count and following_count)
      final userData =
          await _supabaseService.client
              .from('profiles')
              .select(
                'user_id, username, nickname, avatar, bio, user_posts, google_avatar',
              )
              .eq('user_id', userId)
              .single();

      debugPrint('Fetched profile data: $userData');

      // For current user, update the google_avatar if it's empty in DB but available locally
      if (userId == _supabaseService.currentUser.value?.id) {
        if ((userData['google_avatar'] == null || userData['google_avatar'].toString().isEmpty) &&
            _accountDataProvider.googleAvatar.value.isNotEmpty) {
          
          // Update local data
          userData['google_avatar'] = _accountDataProvider.googleAvatar.value;
          debugPrint('Added current user Google avatar: ${_accountDataProvider.googleAvatar.value}');
          
          // Update in database for future use
          await _supabaseService.client.from('profiles').update({
            'google_avatar': _accountDataProvider.googleAvatar.value
          }).eq('user_id', userId);
          
          debugPrint('Updated Google avatar in database');
        }
      }

      // Calculate follower and following counts from follows table
      // For the viewed profile's followers count
      final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);
      
      final int followerCount = (followerResponse as List).length;
      debugPrint('Calculated follower count: $followerCount');
      
      // For the viewed profile's following count
      final followingResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId);
      
      final int followingCount = (followingResponse as List).length;
      debugPrint('Calculated following count: $followingCount');

      // Add follower and following counts to userData
      userData['follower_count'] = followerCount;
      userData['following_count'] = followingCount;

      // Store the user profile data
      selectedUserProfile.value = Map<String, dynamic>.from(userData);

      // Fetch posts directly from posts table
      final postsResponse = await _supabaseService.client
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allPosts =
          List<Map<String, dynamic>>.from(postsResponse);

      // Convert post_type to category for backward compatibility
      for (var post in allPosts) {
        post['category'] = post['post_type'];
      }

      userPosts.value = allPosts;
      debugPrint(
        'Loaded ${allPosts.length} posts for user: ${userData['username']}',
      );
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      // Create minimal default data if profile fetch fails
      selectedUserProfile.value = {
        'user_id': userId,
        'username': 'User',
        'nickname': 'User',
        'avatar': '',
        'google_avatar': '',
        'bio': 'Profile data unavailable',
        'follower_count': 0,
        'following_count': 0,
      };
      userPosts.value = [];
      EasyLoading.showError('Failed to load profile');
    } finally {
      isLoadingUserProfile.value = false;
    }
  }

  // Get filtered posts based on selected tab
  List<Map<String, dynamic>> getFilteredPosts() {
    switch (selectedPostTypeTab.value) {
      case 0: // All
        return userPosts;
      case 1: // Threads
        return userPosts.where((post) => post['post_type'] == 'text').toList();
      case 2: // Images
        return userPosts.where((post) => post['post_type'] == 'image').toList();
      case 3: // GIFs
        return userPosts.where((post) => post['post_type'] == 'gif').toList();
      case 4: // Stickers
        return userPosts
            .where((post) => post['post_type'] == 'sticker')
            .toList();
      default:
        return userPosts;
    }
  }

  // Set which tab is selected
  void setSelectedPostTypeTab(int index) {
    selectedPostTypeTab.value = index;
  }

  // Check if the current user is following the selected user
  bool isFollowingUser(String userId) {
    if (selectedUserProfile.isEmpty || userId.isEmpty) return false;
    
    // First check in the AccountDataProvider for cached state (fast check)
    if (_accountDataProvider.isFollowing(userId)) {
      return true;
    }
    
    // If not found in cache, we need to ensure we have the most up-to-date data
    // This will be handled by refreshFollowState which is called when the view is built
    return false;
  }

  // Refresh the follow state for a specific user - can be called when a view is built to ensure accurate UI
  Future<bool> refreshFollowState(String userId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null || userId.isEmpty) return false;
      
      debugPrint('Refreshing follow state for target user: $userId');
      
      // Check directly in the follows table
      final response = await _supabaseService.client
        .from('follows')
        .select()
        .eq('follower_id', currentUserId)
        .eq('following_id', userId);
      
      final bool isFollowing = response.length > 0;
      
      // If we're following but it's not in our cache, update the cache
      if (isFollowing && !_accountDataProvider.isFollowing(userId)) {
        debugPrint('Found follow relationship in DB that was missing from cache');
        
        final followingData = {
          'following_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        _accountDataProvider.addFollowing(followingData);
      }
      
      debugPrint('Current follow state for $userId: $isFollowing');
      return isFollowing;
    } catch (e) {
      debugPrint('Error checking follow state: $e');
      return false;
    }
  }

  // Call a server-side function to update follower counts (bypasses RLS)
  Future<void> updateFollowerCountServerSide(String targetUserId, int newCount) async {
    try {
      debugPrint('Calling server-side function to update follower count for $targetUserId to $newCount');
      
      // Call a Supabase RPC function that has admin privileges to update the count
      // This bypasses Row-Level Security restrictions
      await _supabaseService.client.rpc(
        'update_follower_count',
        params: {
          'f_count': newCount,
          't_user_id': targetUserId
        }
      );
      
      debugPrint('Server-side follower count update completed');
      
      // Update the local UI state to reflect the new count
      if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == targetUserId) {
        selectedUserProfile['follower_count'] = newCount;
        debugPrint('Updated selectedUserProfile follower count to: $newCount');
      }
      
      // Force UI update
      update();
    } catch (e) {
      debugPrint('Error updating follower count server-side: $e');
      
      // Even if the server-side update fails, we can still update the UI
      // since the follows table has the correct count
      if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == targetUserId) {
        selectedUserProfile['follower_count'] = newCount;
        debugPrint('Updated UI follower count despite server error: $newCount');
      }
    }
  }

  // Follow or unfollow a user
  Future<void> toggleFollowUser(String userId) async {
    if (userId.isEmpty) return;

    try {
      debugPrint('========== FOLLOW/UNFOLLOW START ==========');
      debugPrint('Target userId: $userId');
      
      // Get current state
      final isFollowing = isFollowingUser(userId);
      final currentUserId = _supabaseService.currentUser.value?.id;
      
      if (currentUserId == null) {
        EasyLoading.showError('User not authenticated');
        return;
      }
      
      // Prevent following your own profile
      if (userId == currentUserId) {
        debugPrint('Cannot follow your own profile');
        EasyLoading.showError('You cannot follow your own profile');
        return;
      }
      
      debugPrint('Current user: $currentUserId, currently following: $isFollowing');

      // Show a loading indicator
      EasyLoading.show(status: 'Processing...');

      // Get BEFORE counts for comparison
      final beforeFollowerCount = (await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId)).length;
          
      final beforeFollowingCount = (await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)).length;
          
      debugPrint('BEFORE - Target user followers: $beforeFollowerCount, Current user following: $beforeFollowingCount');

      if (isFollowing) {
        // UNFOLLOW FLOW
        
        // 1. Delete the follow relationship
        await _supabaseService.client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);
        
        debugPrint('Unfollow relationship deleted from database');
        
        // 2. Directly count followers and following in database
        final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);
        
        final followingResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId);
        
        final int followerCount = (followerResponse as List).length;
        final int followingCount = (followingResponse as List).length;
        
        debugPrint('Actual counts in database - Target user followers: $followerCount, Current user following: $followingCount');
        
        // 3. Update current user profile (we have permission for our own profile)
        await _supabaseService.client
          .from('profiles')
          .upsert({
            'user_id': currentUserId,
            'following_count': followingCount
          });
          
        // 4. Update target user's follower count via server-side function
        await updateFollowerCountServerSide(userId, followerCount);
        
        // 5. Update local state
        _accountDataProvider.removeFollowing(userId);
        _accountDataProvider.followingCount.value = followingCount;
        
        // 6. Update UI
        if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
          selectedUserProfile['follower_count'] = followerCount;
          debugPrint('Updated selectedUserProfile follower count to: $followerCount');
        }
      } else {
        // FOLLOW FLOW
        
        // 1. Create the follow relationship
        await _supabaseService.client
          .from('follows')
          .insert({
            'follower_id': currentUserId,
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        
        debugPrint('Follow relationship added to database');
        
        // 2. Directly count followers and following in database
        final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);
        
        final followingResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId);
        
        final int followerCount = (followerResponse as List).length;
        final int followingCount = (followingResponse as List).length;
        
        debugPrint('Actual counts in database - Target user followers: $followerCount, Current user following: $followingCount');
        
        // 3. Update current user profile (we have permission for our own profile)
        await _supabaseService.client
          .from('profiles')
          .upsert({
            'user_id': currentUserId,
            'following_count': followingCount
          });
        
        // 4. Update target user's follower count via server-side function
        await updateFollowerCountServerSide(userId, followerCount);
        
        // 5. Update local state
        final followingData = {
          'following_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        };
        _accountDataProvider.addFollowing(followingData);
        _accountDataProvider.followingCount.value = followingCount;
        
        // 6. Update UI
        if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
          selectedUserProfile['follower_count'] = followerCount;
          debugPrint('Updated selectedUserProfile follower count to: $followerCount');
        }
      }

      // Close loading indicator
      EasyLoading.dismiss();
      
      // Add a delay to make sure database updates are processed
      await Future.delayed(Duration(milliseconds: 500));
      
      // CRITICAL: Directly update both users with verified counts from the follows table
      debugPrint('CRITICAL: Performing direct count update after follow/unfollow action');
      
      // Update current user (the one performing the follow/unfollow)
      await refreshUserFollowData(currentUserId);
      
      // For the target user, just update the UI since we can't update the database directly
      final updatedFollowerCount = (await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId)).length;
          
      if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
        selectedUserProfile['follower_count'] = updatedFollowerCount;
        debugPrint('Final UI update - target user follower count: $updatedFollowerCount');
      }
      
      // Explicitly update the AccountDataProvider to ensure the UI reflects the changes
      _accountDataProvider.followerCount.value = (await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', currentUserId)).length;
          
      _accountDataProvider.followingCount.value = (await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)).length;
      
      debugPrint('CRITICAL: Final follower count: ${_accountDataProvider.followerCount}');
      debugPrint('CRITICAL: Final following count: ${_accountDataProvider.followingCount}');
      
      // Try to update ProfileController if it exists
      try {
        final profileCtrl = Get.find<ProfileController>();
        await profileCtrl.refreshFollowData();  // Use our enhanced method
        debugPrint('CRITICAL: ProfileController refresh completed');
      } catch (e) {
        debugPrint('CRITICAL: ProfileController not found, direct update completed');
      }
      
      // Force UI update one last time
      update();
      debugPrint('========== FOLLOW/UNFOLLOW END ==========');
    } catch (e) {
      debugPrint('Error toggling follow status: $e');
      EasyLoading.showError('Failed to update follow status');
    }
  }

  // Public method to refresh user follow data (replacement for the renamed method)
  Future<void> refreshUserFollowData(String userId) async {
    try {
      debugPrint('CRITICAL: Refreshing follow data for user: $userId');
      
      // DIRECT COUNT: Calculate follower and following counts from follows table
      final List followersList = await _supabaseService.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);
      
      final List followingList = await _supabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      
      final int followerCount = followersList.length;
      final int followingCount = followingList.length;
      
      debugPrint('DIRECT COUNT from follows table - User $userId has $followerCount followers and is following $followingCount users');
      
      // Get current values from profiles table
      final profileData = await _supabaseService.client
          .from('profiles')
          .select('follower_count, following_count')
          .eq('user_id', userId)
          .single();
          
      debugPrint('CURRENT profile data from database for $userId - followers: ${profileData['follower_count']}, following: ${profileData['following_count']}');
      
      // Check for discrepancy
      if (profileData['follower_count'] != followerCount || profileData['following_count'] != followingCount) {
        debugPrint('CRITICAL: Detected count discrepancy for user $userId - Updating database');
        
        // Force update in database with accurate counts using upsert
        // This ensures the record is created if it doesn't exist, or updated if it does
        final response = await _supabaseService.client
          .from('profiles')
          .upsert({
            'user_id': userId,
            'follower_count': followerCount,
            'following_count': followingCount
          });
          
        debugPrint('CRITICAL: Database update complete for user $userId');
        
        // Add a small delay to ensure the update is processed
        await Future.delayed(Duration(milliseconds: 300));
        
        // Verify the update
        final updatedProfile = await _supabaseService.client
          .from('profiles')
          .select('follower_count, following_count')
          .eq('user_id', userId)
          .single();
          
        debugPrint('CRITICAL: VERIFIED profile data for $userId - followers: ${updatedProfile['follower_count']}, following: ${updatedProfile['following_count']}');
        
        // If the update didn't work, try a more direct approach
        if (updatedProfile['follower_count'] != followerCount) {
          debugPrint('CRITICAL: Update verification failed, trying direct SQL update');
          
          // Try a more direct approach to update just the follower count
          await _supabaseService.client.rpc(
            'update_follower_count',
            params: {
              'user_id_param': userId,
              'new_count': followerCount,
            },
          );
          
          debugPrint('CRITICAL: Direct update for follower count attempted');
        }
      }
      
      // Check if this is the current user and update AccountDataProvider directly 
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (userId == currentUserId) {
        // Update AccountDataProvider values directly
        _accountDataProvider.followerCount.value = followerCount;
        _accountDataProvider.followingCount.value = followingCount;
        debugPrint('CRITICAL: Updated AccountDataProvider with follower count: $followerCount, following count: $followingCount');
      }
      
      // Update selectedUserProfile with new counts for UI
      if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
        // Store previous values for logging
        final prevFollowerCount = selectedUserProfile['follower_count'] ?? 0;
        final prevFollowingCount = selectedUserProfile['following_count'] ?? 0;
        
        // Update with new values
        selectedUserProfile['follower_count'] = followerCount;
        selectedUserProfile['following_count'] = followingCount;
        
        debugPrint('CRITICAL: Updated UI state for user $userId');
        debugPrint('  - Followers changed from $prevFollowerCount to $followerCount');
        debugPrint('  - Following changed from $prevFollowingCount to $followingCount');
      }
      
      // Force UI update
      update();
    } catch (e) {
      debugPrint('CRITICAL ERROR refreshing user follow data: $e');
    }
  }

  // Open a list of followers for a user
  void openFollowersList(String userId) {
    debugPrint('Opening followers list for user: $userId');
    
    // Get the nickname to display on the followers page
    String nickname = selectedUserProfile['nickname'] ?? 'User';
    
    // Create the followers page
    Get.to(
      () => FollowListView(
        userId: userId,
        type: FollowType.followers,
        title: '$nickname\'s Followers',
      ),
      transition: Transition.rightToLeft,
    );
  }

  // Open a list of users that a user is following
  void openFollowingList(String userId) {
    debugPrint('Opening following list for user: $userId');
    
    // Get the nickname to display on the following page
    String nickname = selectedUserProfile['nickname'] ?? 'User';
    
    // Create the following page
    Get.to(
      () => FollowListView(
        userId: userId,
        type: FollowType.following,
        title: '$nickname is Following',
      ),
      transition: Transition.rightToLeft,
    );
  }

  // Helper method to verify database counts after update - made public for use by other controllers
  Future<void> verifyDatabaseCounts(String currentUserId, String targetUserId) async {
    try {
      debugPrint('DATABASE VERIFICATION - START');
      
      // Get accurate count from follows table first - these are the TRUE values
      final followingList = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId);
          
      final followerList = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', targetUserId);
          
      final int followingCount = followingList.length;
      final int followerCount = followerList.length;
          
      debugPrint('TRUE COUNT FROM FOLLOWS TABLE:');
      debugPrint('Current user following count: $followingCount');
      debugPrint('Target user follower count: $followerCount');
      
      // Now get the current profile values
      final currentUserProfile = await _supabaseService.client
          .from('profiles')
          .select('follower_count, following_count')
          .eq('user_id', currentUserId)
          .single();
          
      final targetUserProfile = await _supabaseService.client
          .from('profiles')
          .select('follower_count, following_count')
          .eq('user_id', targetUserId)
          .single();
          
      debugPrint('CURRENT PROFILE DATA:');
      debugPrint('Current user ($currentUserId) - followers: ${currentUserProfile['follower_count']}, following: ${currentUserProfile['following_count']}');
      debugPrint('Target user ($targetUserId) - followers: ${targetUserProfile['follower_count']}, following: ${targetUserProfile['following_count']}');
      
      // Fix any discrepancy in current user counts
      if (currentUserProfile['following_count'] != followingCount) {
        debugPrint('Fixing discrepancy in current user following count');
        await _supabaseService.client
          .from('profiles')
          .update({'following_count': followingCount})
          .eq('user_id', currentUserId);
          
        // Wait a bit to ensure the update takes effect
        await Future.delayed(Duration(milliseconds: 300));
          
        // Also update the AccountDataProvider directly
        _accountDataProvider.followingCount.value = followingCount;
        
        // Verify update was successful
        final verifiedCurrentUser = await _supabaseService.client
          .from('profiles')
          .select('following_count')
          .eq('user_id', currentUserId)
          .single();
          
        debugPrint('VERIFIED current user following count: ${verifiedCurrentUser['following_count']}');
      }
      
      // Fix any discrepancy in target user follower count
      if (targetUserProfile['follower_count'] != followerCount) {
        debugPrint('CRITICAL FIX: Updating target user follower count from ${targetUserProfile['follower_count']} to $followerCount');
        
        // Attempt to update the database with correct count
        final response = await _supabaseService.client
          .from('profiles')
          .update({'follower_count': followerCount})
          .eq('user_id', targetUserId);
        
        debugPrint('Database update response: $response');
        
        // Wait a bit to ensure the update takes effect
        await Future.delayed(Duration(milliseconds: 300));
        
        // If this is the current user, update follower count in AccountDataProvider
        if (targetUserId == currentUserId) {
          _accountDataProvider.followerCount.value = followerCount;
        }
        
        // Verify the update was successful
        final verifiedTargetUser = await _supabaseService.client
          .from('profiles')
          .select('follower_count')
          .eq('user_id', targetUserId)
          .single();
          
        debugPrint('VERIFIED target user follower count: ${verifiedTargetUser['follower_count']}');
        
        // If the update didn't work for some reason, force it with a direct upsert
        if (verifiedTargetUser['follower_count'] != followerCount) {
          debugPrint('WARNING: Initial update failed, trying direct upsert');
          
          await _supabaseService.client
            .from('profiles')
            .upsert({
              'user_id': targetUserId,
              'follower_count': followerCount
            });
            
          await Future.delayed(Duration(milliseconds: 300));
          
          final finalCheck = await _supabaseService.client
            .from('profiles')
            .select('follower_count')
            .eq('user_id', targetUserId)
            .single();
            
          debugPrint('FINAL CHECK target user follower count: ${finalCheck['follower_count']}');
        }
        
        // Also update selectedUserProfile if it matches the target user
        if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == targetUserId) {
          debugPrint('Updating selectedUserProfile follower count from ${selectedUserProfile['follower_count']} to $followerCount');
          selectedUserProfile['follower_count'] = followerCount;
        }
      }
      
      // Force UI update to reflect changes
      update();
      
      debugPrint('DATABASE VERIFICATION - COMPLETE');
    } catch (e) {
      debugPrint('Error verifying database counts: $e');
    }
  }
}

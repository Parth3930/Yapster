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

      // Search for users in Supabase where username contains the query
      // Include google_avatar in the query
      final response = await _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .ilike('username', '%$query%')
          .limit(20);

      final List<Map<String, dynamic>> results =
          List<Map<String, dynamic>>.from(response);

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
          
        if (userData != null) {
          // Update user with complete data
          user = Map<String, dynamic>.from(userData);
          debugPrint('Updated user data with complete profile including Google avatar');
        }
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
    
    // Use the new _followingMap in AccountDataProvider for O(1) lookup
    return _accountDataProvider.isFollowing(userId);
  }

  // Follow or unfollow a user
  Future<void> toggleFollowUser(String userId) async {
    if (userId.isEmpty) return;

    try {
      // Get current state
      final isFollowing = isFollowingUser(userId);
      final currentUserId = _supabaseService.currentUser.value?.id;
      
      if (currentUserId == null) {
        EasyLoading.showError('User not authenticated');
        return;
      }

      if (isFollowing) {
        // Manually update the local state for immediate UI feedback
        _accountDataProvider.removeFollowing(userId);
        
        // Update database
        await _supabaseService.client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);
          
        // Update BOTH profiles' counts
        
        // 1. Update current user's following count
        final followingCount = _accountDataProvider.followingCount.value;
        await _supabaseService.client
          .from('profiles')
          .update({'following_count': followingCount})
          .eq('user_id', currentUserId);
        
        // 2. Get and update target user's follower count
        final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);
        
        final int followerCount = (followerResponse as List).length;
        
        await _supabaseService.client
          .from('profiles')
          .update({'follower_count': followerCount})
          .eq('user_id', userId);
          
        // 3. Update the UI if we're looking at this user's profile
        if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
          selectedUserProfile['follower_count'] = followerCount;
        }
          
        debugPrint('Manually unfollowed user: $userId with new follower count: $followerCount');
      } else {
        // Manually update the local state for immediate UI feedback
        final followingData = {
          'following_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        };
        _accountDataProvider.addFollowing(followingData);
        
        // Update database
        await _supabaseService.client
          .from('follows')
          .insert({
            'follower_id': currentUserId,
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        
        // Update BOTH profiles' counts
        
        // 1. Update current user's following count
        final followingCount = _accountDataProvider.followingCount.value;
        await _supabaseService.client
          .from('profiles')
          .update({'following_count': followingCount})
          .eq('user_id', currentUserId);
        
        // 2. Get and update target user's follower count
        final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);
        
        final int followerCount = (followerResponse as List).length;
        
        await _supabaseService.client
          .from('profiles')
          .update({'follower_count': followerCount})
          .eq('user_id', userId);
          
        // 3. Update the UI if we're looking at this user's profile
        if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
          selectedUserProfile['follower_count'] = followerCount;
        }
          
        debugPrint('Manually followed user: $userId with new follower count: $followerCount');
      }

      // Force UI update
      update();
      
      // Refresh user profile data to get updated followers/following counts
      await refreshUserFollowData(userId);
    } catch (e) {
      debugPrint('Error toggling follow status: $e');
      EasyLoading.showError('Failed to update follow status');
    }
  }

  // Refreshes follower and following counts for a user
  Future<void> refreshUserFollowData(String userId) async {
    try {
      debugPrint('Refreshing follow data for user: $userId');
      
      // Calculate follower and following counts from follows table
      // For the viewed profile's followers count
      final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);
      
      final int followerCount = (followerResponse as List).length;
      
      // For the viewed profile's following count
      final followingResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId);
      
      final int followingCount = (followingResponse as List).length;
      
      // Update selectedUserProfile with new counts
      if (selectedUserProfile.isNotEmpty && selectedUserProfile['user_id'] == userId) {
        selectedUserProfile['follower_count'] = followerCount;
        selectedUserProfile['following_count'] = followingCount;
        debugPrint('Updated follower count: $followerCount, following count: $followingCount');
      }
      
      // For current user, also update account data provider
      if (userId == _supabaseService.currentUser.value?.id) {
        _accountDataProvider.followerCount.value = followerCount;
        _accountDataProvider.followingCount.value = followingCount;
        
        // Also refresh follower and following lists
        await _accountDataProvider.loadFollowers(userId);
        await _accountDataProvider.loadFollowing(userId);
      }
    } catch (e) {
      debugPrint('Error refreshing follow data: $e');
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
}

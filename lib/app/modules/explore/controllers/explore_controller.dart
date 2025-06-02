import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'dart:async';
import 'dart:convert';
import 'package:yapster/app/modules/profile/views/follow_list_view.dart';
import 'package:yapster/app/core/models/follow_type.dart';
import 'package:yapster/app/routes/app_pages.dart';

class ExploreController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  AccountDataProvider get _accountDataProvider =>
      Get.find<AccountDataProvider>();
  AccountDataProvider get _accountFunctions => Get.find<AccountDataProvider>();
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

  // Cache for user profiles
  final _profileCache = <String, Map<String, dynamic>>{}.obs;
  final _profileLastFetch = <String, DateTime>{};
  
  // Cache for follow state to reduce database calls
  final _followStateCache = <String, bool>{}.obs;
  final _followStateFetchTime = <String, DateTime>{};
  static const Duration followStateCacheDuration = Duration(minutes: 15);

  // Cache for recent searches with timestamp for expiration checking
  final Map<String, DateTime> _recentSearchesFetchTime = <String, DateTime>{};
  static const Duration searchCacheDuration = Duration(minutes: 30);
  
  // Track if we're on the explore page to prevent unnecessary loading elsewhere
  final RxBool _isOnExplorePage = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    // Add listener to search text field
    searchController.addListener(_onSearchChanged);
  }
  
  // Call this when explore page is opened
  void onExplorePageOpened() {
    _isOnExplorePage.value = true;
    // Only load searches when we're actually on the explore page
    if (_shouldRefreshRecentSearches()) {
      loadRecentSearches();
      debugPrint('Loading recent searches from database (cache expired)');
    } else {
      debugPrint('Using cached recent searches');
    }
  }
  
  // Call this when leaving the explore page
  void onExplorePageClosed() {
    _isOnExplorePage.value = false;
  }
  
  // Check if we need to refresh searches based on cache time
  bool _shouldRefreshRecentSearches() {
    final lastFetch = _recentSearchesFetchTime['recent_searches'];
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > searchCacheDuration;
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
      if (currentUserId == null) return;

      // Search for users in Supabase where username contains the query
      final response = await _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .ilike('username', '%$query%')
          .neq(
            'user_id',
            currentUserId,
          ) // Explicitly exclude current user in query
          .limit(20);

      // Convert to list
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(
        response,
      );
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
    // Only load if we're actually on the explore page
    if (!_isOnExplorePage.value) {
      debugPrint('Skipping loadRecentSearches since not on explore page');
      return;
    }
    
    try {
      // Load from database
      _accountFunctions.loadSearches().then((_) {
        // After loading from database, update the local list
        recentSearches.value = List<Map<String, dynamic>>.from(
          _accountDataProvider.searches,
        );
        
        // Update the timestamp to mark when data was last fetched
        _recentSearchesFetchTime['recent_searches'] = DateTime.now();
        
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
        final userData =
            await _supabaseService.client
                .from('profiles')
                .select('user_id, username, nickname, avatar, google_avatar')
                .eq('user_id', user['user_id'])
                .single();

        // Update user with complete data
        user = Map<String, dynamic>.from(userData);
        debugPrint(
          'Updated user data with complete profile including Google avatar',
        );
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
      await _accountFunctions.updateSearches(recentSearches.toList());
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
        await _accountFunctions.updateSearches(recentSearches.toList());
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
      Get.toNamed("${Routes.PROFILE}/${user['user_id']}");
    });
  }

  // Load a user's profile data and posts
  Future<void> loadUserProfile(String userId) async {
    try {
      isLoadingUserProfile.value = true;
      debugPrint('Loading profile for user ID: $userId');

      // Check if we have a cached profile and it's still valid
      final lastFetch = _profileLastFetch[userId];
      final now = DateTime.now();
      if (lastFetch != null &&
          now.difference(lastFetch) < SupabaseService.profileCacheDuration &&
          _profileCache.containsKey(userId)) {
        debugPrint('Using cached profile data for user: $userId');
        selectedUserProfile.value = Map<String, dynamic>.from(
          _profileCache[userId]!,
        );
        return;
      }

      // If not cached or cache expired, fetch from database
      final List<dynamic> followers = await _supabaseService.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      final List<dynamic> following = await _supabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final int accurateFollowerCount = followers.length;
      final int accurateFollowingCount = following.length;

      debugPrint('Fresh follow counts from database:');
      debugPrint('Followers: $accurateFollowerCount');
      debugPrint('Following: $accurateFollowingCount');

      // Fetch the complete profile data
      final List<dynamic> profileResponse = await _supabaseService.client
          .from('profiles')
          .select('''
            user_id, 
            username, 
            nickname, 
            avatar, 
            bio,  
            google_avatar,
            follower_count,
            following_count
          ''')
          .eq('user_id', userId)
          .limit(1);

      if (profileResponse.isEmpty) {
        debugPrint('User profile not found');
        throw Exception('User profile not found');
      }

      // Initialize with profile data
      var userData = Map<String, dynamic>.from(profileResponse.first);

      // Update with accurate counts if needed
      if (userData['follower_count'] != accurateFollowerCount ||
          userData['following_count'] != accurateFollowingCount) {
        debugPrint('Detected count discrepancy, updating profile...');

        // Update the database with accurate counts
        await _supabaseService.client.from('profiles').upsert({
          'user_id': userId,
          'follower_count': accurateFollowerCount,
          'following_count': accurateFollowingCount,
        });

        // Update the userData map with accurate counts
        userData['follower_count'] = accurateFollowerCount;
        userData['following_count'] = accurateFollowingCount;
      }

      // Ensure required fields have default values
      userData = {
        'user_id': userId,
        'username': userData['username'] ?? 'User',
        'nickname': userData['nickname'] ?? 'User',
        'avatar': userData['avatar'] ?? '',
        'google_avatar': userData['google_avatar'] ?? '',
        'bio': userData['bio'] ?? 'No bio available',
        'follower_count': accurateFollowerCount,
        'following_count': accurateFollowingCount,
        ...userData,
      };

      // Cache the profile data
      _profileCache[userId] = userData;
      _profileLastFetch[userId] = now;

      // Store the processed profile data
      selectedUserProfile.value = userData;

      // Load posts only if needed (you might want to cache these separately)
      await _loadUserPosts(userId);

      // Force UI update
      update();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      selectedUserProfile.value = _getDefaultProfile(userId);
      userPosts.value = [];
      EasyLoading.showError('Failed to load profile data. Please try again.');
    } finally {
      isLoadingUserProfile.value = false;
    }
  }

  Map<String, dynamic> _getDefaultProfile(String userId) {
    return {
      'user_id': userId,
      'username': 'User',
      'nickname': 'User',
      'avatar': '',
      'google_avatar': '',
      'bio': 'Profile data unavailable',
      'follower_count': 0,
      'following_count': 0,
    };
  }

  // Separate method for loading posts
  Future<void> _loadUserPosts(String userId) async {
    try {
      final List<dynamic> postsResponse = await _supabaseService.client
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allPosts =
          postsResponse.map((post) => Map<String, dynamic>.from(post)).toList();

      // Convert post_type to category for backward compatibility
      for (var post in allPosts) {
        post['category'] = post['post_type'];
      }

      userPosts.value = allPosts;
      debugPrint('Loaded ${allPosts.length} posts for user: $userId');
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      userPosts.value = [];
    }
  }

  // Clear cache for a specific user
  void clearProfileCache(String userId) {
    _profileCache.remove(userId);
    _profileLastFetch.remove(userId);
  }

  // Clear entire profile cache
  void clearAllProfileCache() {
    _profileCache.clear();
    _profileLastFetch.clear();
  }

  // Check if the current user is following the selected user
  bool isFollowingUser(String userId) {
    if (userId.isEmpty) return false;

    // First check in the AccountDataProvider for cached state (fast check)
    if (_accountDataProvider.isFollowing(userId)) {
      debugPrint('User $userId found in following cache - already following');
      return true;
    }

    // If not found in cache, we need to ensure we have the most up-to-date data
    // This will be handled by refreshFollowState which is called when the view is built
    debugPrint(
      'User $userId not found in following cache - not following or needs refresh',
    );
    return false;
  }

  // Check if the selected user is following the current user
  Future<bool> isUserFollowingCurrentUser(String userId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null || userId.isEmpty) return false;

      debugPrint(
        'Checking if user $userId is following current user $currentUserId',
      );

      // Check directly in the follows table
      final response = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId)
          .eq('following_id', currentUserId);

      final bool isFollowing = response.isNotEmpty;
      debugPrint('User $userId following current user: $isFollowing');

      return isFollowing;
    } catch (e) {
      debugPrint('Error checking if user is following current user: $e');
      return false;
    }
  }

  // Check if two users are mutually following each other
  Future<bool> areMutualFollowers(String userId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null || userId.isEmpty) return false;

      // Check if current user is following the user
      final isFollowing = await refreshFollowState(userId);

      // Check if the user is following the current user
      final isFollowedBy = await isUserFollowingCurrentUser(userId);

      debugPrint(
        'Mutual follow check: current user following $userId: $isFollowing, $userId following current user: $isFollowedBy',
      );

      return isFollowing && isFollowedBy;
    } catch (e) {
      debugPrint('Error checking mutual followers: $e');
      return false;
    }
  }

  /// Checks if follow state should be refreshed for a user based on cache age
  bool shouldRefreshFollowState(String userId) {
    final lastFetch = _followStateFetchTime[userId];
    final now = DateTime.now();
    
    // Refresh if we haven't fetched before, or if cache is expired
    return lastFetch == null || 
           now.difference(lastFetch) > followStateCacheDuration;
  }
  
  /// Updates the follow state cache timestamp for a user
  void markFollowStateRefreshed(String userId) {
    _followStateFetchTime[userId] = DateTime.now();
    debugPrint('Marked follow state as refreshed for user: $userId');
  }
  
  // Refresh the follow state for a specific user - can be called when a view is built to ensure accurate UI
  Future<bool> refreshFollowState(String userId) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null || userId.isEmpty) return false;

      // If we have a cached follow state and it's not expired, use that
      if (!shouldRefreshFollowState(userId) && _followStateCache.containsKey(userId)) {
        debugPrint('Using cached follow state for user: $userId');
        return _followStateCache[userId] ?? false;
      }

      debugPrint('Refreshing follow state for target user: $userId');

      // Check directly in the follows table
      final response = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);

      final bool isFollowing = response.isNotEmpty;

      // Cache the follow state
      _followStateCache[userId] = isFollowing;
      markFollowStateRefreshed(userId);

      // If we're following but it's not in our cache, update the cache
      if (isFollowing && !_accountDataProvider.isFollowing(userId)) {
        debugPrint(
          'Found follow relationship in DB that was missing from cache',
        );

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
  Future<void> updateFollowerCountServerSide(
    String targetUserId,
    int newCount,
  ) async {
    try {
      debugPrint(
        'Calling server-side function to update follower count for $targetUserId to $newCount',
      );

      // Call a Supabase RPC function that has admin privileges to update the count
      // This bypasses Row-Level Security restrictions
      await _supabaseService.client.rpc(
        'update_follower_count',
        params: {'f_count': newCount, 't_user_id': targetUserId},
      );

      debugPrint('Server-side follower count update completed');

      // Update the local UI state to reflect the new count
      if (selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == targetUserId) {
        selectedUserProfile['follower_count'] = newCount;
        debugPrint('Updated selectedUserProfile follower count to: $newCount');
      }

      // Force UI update
      update();
    } catch (e) {
      debugPrint('Error updating follower count server-side: $e');

      // Even if the server-side update fails, we can still update the UI
      // since the follows table has the correct count
      if (selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == targetUserId) {
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

      debugPrint(
        'Current user: $currentUserId, currently following: $isFollowing',
      );

      // Show a loading indicator
      EasyLoading.show(status: 'Processing...');

      // Get BEFORE counts for comparison
      final beforeFollowerCount =
          (await _supabaseService.client
              .from('follows')
              .select()
              .eq('following_id', userId)).length;

      final beforeFollowingCount =
          (await _supabaseService.client
              .from('follows')
              .select()
              .eq('follower_id', currentUserId)).length;

      debugPrint(
        'BEFORE - Target user followers: $beforeFollowerCount, Current user following: $beforeFollowingCount',
      );

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

        debugPrint(
          'Actual counts in database - Target user followers: $followerCount, Current user following: $followingCount',
        );

        // 3. Update current user profile (we have permission for our own profile)
        await _supabaseService.client.from('profiles').upsert({
          'user_id': currentUserId,
          'following_count': followingCount,
        });

        // 4. Update target user's follower count via server-side function
        await updateFollowerCountServerSide(userId, followerCount);

        // 5. Update local state
        _accountDataProvider.removeFollowing(userId);
        _accountDataProvider.followingCount.value = followingCount;

        // 6. Update UI
        if (selectedUserProfile.isNotEmpty &&
            selectedUserProfile['user_id'] == userId) {
          selectedUserProfile['follower_count'] = followerCount;
          debugPrint(
            'Updated selectedUserProfile follower count to: $followerCount',
          );
        }
      } else {
        // FOLLOW FLOW

        // 1. Create the follow relationship
        await _supabaseService.client.from('follows').insert({
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

        debugPrint(
          'Actual counts in database - Target user followers: $followerCount, Current user following: $followingCount',
        );

        // 3. Update current user profile (we have permission for our own profile)
        await _supabaseService.client.from('profiles').upsert({
          'user_id': currentUserId,
          'following_count': followingCount,
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
        if (selectedUserProfile.isNotEmpty &&
            selectedUserProfile['user_id'] == userId) {
          selectedUserProfile['follower_count'] = followerCount;
          debugPrint(
            'Updated selectedUserProfile follower count to: $followerCount',
          );
        }
      }

      // Close loading indicator
      EasyLoading.dismiss();

      // Add a delay to make sure database updates are processed
      await Future.delayed(Duration(milliseconds: 500));

      // CRITICAL: Directly update both users with verified counts from the follows table
      debugPrint(
        'CRITICAL: Performing direct count update after follow/unfollow action',
      );

      // Update current user (the one performing the follow/unfollow)
      await refreshUserFollowData(currentUserId);

      // For the target user, just update the UI since we can't update the database directly
      final updatedFollowerCount =
          (await _supabaseService.client
              .from('follows')
              .select()
              .eq('following_id', userId)).length;

      if (selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == userId) {
        selectedUserProfile['follower_count'] = updatedFollowerCount;
        debugPrint(
          'Final UI update - target user follower count: $updatedFollowerCount',
        );
      }

      // Explicitly update the AccountDataProvider to ensure the UI reflects the changes
      _accountDataProvider.followerCount.value =
          (await _supabaseService.client
              .from('follows')
              .select()
              .eq('follower_id', currentUserId)).length;

      _accountDataProvider.followingCount.value =
          (await _supabaseService.client
              .from('follows')
              .select()
              .eq('following_id', currentUserId)).length;

      // Try to update ProfileController if it exists
      try {} catch (e) {
        debugPrint(
          'CRITICAL: ProfileController not found, direct update completed',
        );
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

      debugPrint(
        'DIRECT COUNT from follows table - User $userId has $followerCount followers and is following $followingCount users',
      );

      // Get current values from profiles table
      final profileData =
          await _supabaseService.client
              .from('profiles')
              .select('follower_count, following_count')
              .eq('user_id', userId)
              .single();

      debugPrint(
        'CURRENT profile data from database for $userId - followers: ${profileData['follower_count']}, following: ${profileData['following_count']}',
      );

      // Check for discrepancy
      if (profileData['follower_count'] != followerCount ||
          profileData['following_count'] != followingCount) {
        debugPrint(
          'CRITICAL: Detected count discrepancy for user $userId - Updating database',
        );

        // Force update in database with accurate counts using upsert
        // This ensures the record is created if it doesn't exist, or updated if it does
        await _supabaseService.client.from('profiles').upsert({
          'user_id': userId,
          'follower_count': followerCount,
          'following_count': followingCount,
        });

        debugPrint('CRITICAL: Database update complete for user $userId');

        // Add a small delay to ensure the update is processed
        await Future.delayed(Duration(milliseconds: 300));

        // Verify the update
        final updatedProfile =
            await _supabaseService.client
                .from('profiles')
                .select('follower_count, following_count')
                .eq('user_id', userId)
                .single();

        debugPrint(
          'CRITICAL: VERIFIED profile data for $userId - followers: ${updatedProfile['follower_count']}, following: ${updatedProfile['following_count']}',
        );

        // If the update didn't work, try a more direct approach
        if (updatedProfile['follower_count'] != followerCount) {
          debugPrint(
            'CRITICAL: Update verification failed, trying direct SQL update',
          );

          // Try a more direct approach to update just the follower count
          await _supabaseService.client.rpc(
            'update_follower_count',
            params: {'user_id_param': userId, 'new_count': followerCount},
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
        debugPrint(
          'CRITICAL: Updated AccountDataProvider with follower count: $followerCount, following count: $followingCount',
        );
      }

      // Update selectedUserProfile with new counts for UI
      if (selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == userId) {
        // Store previous values for logging
        final prevFollowerCount = selectedUserProfile['follower_count'] ?? 0;
        final prevFollowingCount = selectedUserProfile['following_count'] ?? 0;

        // Update with new values
        selectedUserProfile['follower_count'] = followerCount;
        selectedUserProfile['following_count'] = followingCount;

        debugPrint('CRITICAL: Updated UI state for user $userId');
        debugPrint(
          '  - Followers changed from $prevFollowerCount to $followerCount',
        );
        debugPrint(
          '  - Following changed from $prevFollowingCount to $followingCount',
        );
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
  Future<void> verifyDatabaseCounts(
    String currentUserId,
    String targetUserId,
  ) async {
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
      final currentUserProfile =
          await _supabaseService.client
              .from('profiles')
              .select('follower_count, following_count')
              .eq('user_id', currentUserId)
              .single();

      final targetUserProfile =
          await _supabaseService.client
              .from('profiles')
              .select('follower_count, following_count')
              .eq('user_id', targetUserId)
              .single();

      debugPrint('CURRENT PROFILE DATA:');
      debugPrint(
        'Current user ($currentUserId) - followers: ${currentUserProfile['follower_count']}, following: ${currentUserProfile['following_count']}',
      );
      debugPrint(
        'Target user ($targetUserId) - followers: ${targetUserProfile['follower_count']}, following: ${targetUserProfile['following_count']}',
      );

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
        final verifiedCurrentUser =
            await _supabaseService.client
                .from('profiles')
                .select('following_count')
                .eq('user_id', currentUserId)
                .single();

        debugPrint(
          'VERIFIED current user following count: ${verifiedCurrentUser['following_count']}',
        );
      }

      // Fix any discrepancy in target user follower count
      if (targetUserProfile['follower_count'] != followerCount) {
        debugPrint(
          'CRITICAL FIX: Updating target user follower count from ${targetUserProfile['follower_count']} to $followerCount',
        );

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
        final verifiedTargetUser =
            await _supabaseService.client
                .from('profiles')
                .select('follower_count')
                .eq('user_id', targetUserId)
                .single();

        debugPrint(
          'VERIFIED target user follower count: ${verifiedTargetUser['follower_count']}',
        );

        // If the update didn't work for some reason, force it with a direct upsert
        if (verifiedTargetUser['follower_count'] != followerCount) {
          debugPrint('WARNING: Initial update failed, trying direct upsert');

          await _supabaseService.client.from('profiles').upsert({
            'user_id': targetUserId,
            'follower_count': followerCount,
          });

          await Future.delayed(Duration(milliseconds: 300));

          final finalCheck =
              await _supabaseService.client
                  .from('profiles')
                  .select('follower_count')
                  .eq('user_id', targetUserId)
                  .single();

          debugPrint(
            'FINAL CHECK target user follower count: ${finalCheck['follower_count']}',
          );
        }

        // Also update selectedUserProfile if it matches the target user
        if (selectedUserProfile.isNotEmpty &&
            selectedUserProfile['user_id'] == targetUserId) {
          debugPrint(
            'Updating selectedUserProfile follower count from ${selectedUserProfile['follower_count']} to $followerCount',
          );
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

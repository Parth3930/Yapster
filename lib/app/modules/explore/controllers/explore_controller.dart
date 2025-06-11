import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/models/follow_type.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/modules/profile/views/follow_list_view.dart';

import 'dart:async';
import 'dart:convert';
import 'package:yapster/app/routes/app_pages.dart';

class ExploreController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final StorageService _storageService = Get.find<StorageService>();

  final searchController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recentSearches =
      <Map<String, dynamic>>[].obs;

  // Track loading state for profile to prevent multiple simultaneous loads
  final _isLoadingProfile = false.obs;
  final _currentLoadingUserId = ''.obs;

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

  // Track failed profile loads to prevent infinite retries
  final Set<String> _failedProfileLoads = <String>{};

  // Debounce timer for search
  Timer? _debounce;

  // Cache for user profiles
  final _profileCache = <String, Map<String, dynamic>>{}.obs;
  final _profileLastFetch = <String, DateTime>{};

  // Cache for follow state to reduce database calls
  final _followStateCache = <String, bool>{}.obs;
  final _followStateFetchTime = <String, DateTime>{};
  static const Duration followStateCacheDuration = Duration(minutes: 15);

  // Cache for recent searches
  static const Duration searchCacheDuration = Duration(minutes: 30);

  // Track if we're on the explore page to prevent unnecessary loading elsewhere
  final RxBool _isOnExplorePage = false.obs;

  // account data provider
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();

  @override
  void onInit() {
    super.onInit();
    // Add listener to search text field
    searchController.addListener(_onSearchChanged);
  }

  // Call this when explore page is opened
  void onExplorePageOpened() {
    _isOnExplorePage.value = true;

    // Load any cached searches after the frame is built
    // This prevents setState during build errors
    Future.microtask(() {
      loadCachedSearchResults();
      debugPrint('Loaded cached search results');
    });
  }

  // Call this when leaving the explore page
  void onExplorePageClosed() {
    _isOnExplorePage.value = false;
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

  // Load recent searches from local storage
  void loadCachedSearchResults() {
    try {
      // Get recent searches from local storage
      final recentSearchesJson = _storageService.getString('recent_searches');
      if (recentSearchesJson != null && recentSearchesJson.isNotEmpty) {
        final decodedSearches = jsonDecode(recentSearchesJson) as List;
        recentSearches.clear();
        recentSearches.addAll(List<Map<String, dynamic>>.from(decodedSearches));

        debugPrint(
          'Loaded ${recentSearches.length} recent searches from cache',
        );

        // If there's no active search, show recent searches in results
        if (searchController.text.isEmpty) {
          searchResults.value = List<Map<String, dynamic>>.from(recentSearches);
        }
      } else {
        recentSearches.clear();
        debugPrint('No recent searches found in cache');
      }
    } catch (e) {
      debugPrint('Error loading recent searches from cache: $e');
      recentSearches.clear();
    }
  }

  void loadRecentSearches() {
    // Only load if we're actually on the explore page
    if (!_isOnExplorePage.value) {
      debugPrint('Skipping loadRecentSearches since not on explore page');
      return;
    }

    try {
      // Load from local storage
      loadCachedSearchResults();
      debugPrint('Loaded ${recentSearches.length} recent searches from cache');

      // Debug info about recent searches
      for (var search in recentSearches) {
        debugPrint(
          'Recent search: ${search['username']}, ${search['user_id']}',
        );
      }
    } catch (e) {
      debugPrint('Error loading recent searches from cache: $e');
      recentSearches.clear();
    }
  }

  Future<void> addToRecentSearches(Map<String, dynamic> user) async {
    try {
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

      // Save to local storage
      await _storageService.saveString(
        'recent_searches',
        jsonEncode(recentSearches.toList()),
      );
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

        // Save to local storage
        await _storageService.saveString(
          'recent_searches',
          jsonEncode(recentSearches.toList()),
        );
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

    // Set basic profile data immediately for instant navigation
    final userId = user['user_id'];
    selectedUserProfile.value = {
      'user_id': userId,
      'username': user['username'] ?? '',
      'nickname': user['nickname'] ?? '',
      'avatar': user['avatar'] ?? '',
      'google_avatar': user['google_avatar'] ?? '',
      'bio': '',
      'banner': '',
      'follower_count': 0,
      'following_count': 0,
      'post_count': 0,
      'is_verified': false,
    };

    // Navigate immediately for speed
    Get.toNamed("${Routes.PROFILE}/$userId");

    // Load detailed profile data in background
    loadUserProfile(userId);
  }

  // Creates a default profile with existing values if available
  Map<String, dynamic> _getDefaultProfile(String userId) {
    debugPrint('\n=== _getDefaultProfile START ===');
    debugPrint('🔍 Checking profile for user: $userId');
    debugPrint('🔹 Current profile user: ${selectedUserProfile['user_id']}');
    debugPrint('🔹 Current banner: ${selectedUserProfile['banner']}');

    // If we already have a profile for this user with valid data, return it to prevent flickering
    if (selectedUserProfile.isNotEmpty &&
        selectedUserProfile['user_id'] == userId) {
      debugPrint('✅ Using existing profile for $userId');
      debugPrint('🔹 Existing banner: ${selectedUserProfile['banner']}');
      debugPrint('=== _getDefaultProfile END (existing) ===\n');
      return Map<String, dynamic>.from(selectedUserProfile);
    } else {
      debugPrint('🔄 Creating new default profile for $userId');
      debugPrint('=== _getDefaultProfile END (new) ===\n');
    }

    // Otherwise create a new default profile with existing values if available
    return {
      'user_id': userId,
      'username': selectedUserProfile['username'] ?? '',
      'nickname': selectedUserProfile['nickname'] ?? '',
      'bio': selectedUserProfile['bio'] ?? '',
      'avatar': selectedUserProfile['avatar'],
      'banner': selectedUserProfile['banner'],
      'google_avatar':
          selectedUserProfile['google_avatar'], // CRITICAL FIX: Include google_avatar
      'follower_count': selectedUserProfile['follower_count'] ?? 0,
      'following_count': selectedUserProfile['following_count'] ?? 0,
      'post_count': selectedUserProfile['post_count'] ?? 0,
      'is_verified': selectedUserProfile['is_verified'] ?? false,
      'created_at':
          selectedUserProfile['created_at'] ?? DateTime.now().toIso8601String(),
    };
  }

  // Load a user's profile data and posts
  /// Loads user profile data with instant cache-first strategy
  Future<void> loadUserProfile(String userId) async {
    debugPrint('\n=== loadUserProfile START ===');
    debugPrint('🔍 Requested user: $userId');
    debugPrint('🔹 Current loading user: ${_currentLoadingUserId.value}');
    debugPrint('🔹 Current profile user: ${selectedUserProfile['user_id']}');
    debugPrint('🔹 Current banner: ${selectedUserProfile['banner']}');

    if (userId.isEmpty) {
      debugPrint('❌ Error: Empty userId');
      debugPrint('=== loadUserProfile END (error) ===\n');
      return;
    }

    // Check if this profile has already failed to load
    if (_failedProfileLoads.contains(userId)) {
      debugPrint(
        '❌ Profile load previously failed for user: $userId - skipping retry',
      );
      debugPrint('=== loadUserProfile END (failed before) ===\n');
      return;
    }

    if (_isLoadingProfile.value) {
      debugPrint(
        '⏳ Already loading profile for ${_currentLoadingUserId.value}, requested: $userId',
      );
      debugPrint('=== loadUserProfile END (already loading) ===\n');
      return;
    }

    try {
      debugPrint('🟢 loadUserProfile: Starting load for $userId');
      _isLoadingProfile.value = true;
      _currentLoadingUserId.value = userId;

      debugPrint(
        'ℹ️ Current profile user: ${selectedUserProfile['user_id']}, requested: $userId',
      );
      if (selectedUserProfile['user_id'] != userId) {
        debugPrint('🔄 loadUserProfile: Setting default profile for $userId');
        final defaultProfile = _getDefaultProfile(userId);
        debugPrint('🖼️ Default profile banner: ${defaultProfile['banner']}');
        selectedUserProfile.value = defaultProfile;
      } else {
        debugPrint('ℹ️ Using existing profile for $userId');
      }

      // Load fresh data in the background
      await _loadFreshProfileData(userId, false);
    } catch (e) {
      debugPrint('Error loading fresh profile data: $e');
    } finally {
      _isLoadingProfile.value = false;
      _currentLoadingUserId.value = '';
    }
  }

  // Clear entire profile cache
  void clearAllProfileCache() {
    _profileCache.clear();
    _profileLastFetch.clear();
  }

  /// Fetches follow counts for a user
  Future<Map<String, dynamic>> _fetchFollowCounts(String userId) async {
    try {
      final followerResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);

      final followingResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId);

      final followerCount = followerResponse.length;
      final followingCount = followingResponse.length;

      debugPrint('ExploreController: _fetchFollowCounts for user $userId');
      debugPrint('  - Followers: $followerCount');
      debugPrint('  - Following: $followingCount');

      return {
        'follower_count': followerCount,
        'following_count': followingCount,
      };
    } catch (e) {
      debugPrint('Error fetching follow counts: $e');
      return {'follower_count': 0, 'following_count': 0};
    }
  }

  /// Fetches profile data for a user
  Future<Map<String, dynamic>> _fetchProfileData(String userId) async {
    try {
      final response =
          await _supabaseService.client
              .from('profiles')
              .select()
              .eq('user_id', userId)
              .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching profile data: $e');
      return {};
    }
  }

  /// Fetches post count for a user
  Future<Map<String, dynamic>> _fetchPostCount(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('posts')
          .select()
          .eq('user_id', userId);

      return {'post_count': response.length};
    } catch (e) {
      debugPrint('Error fetching post count: $e');
      return {'post_count': 0};
    }
  }

  /// Compares two profile maps to check if they're effectively equal
  bool _areProfilesEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;

    // Compare only the fields that affect the UI
    final keys = {
      'user_id',
      'username',
      'nickname',
      'bio',
      'avatar',
      'banner',
      'follower_count',
      'following_count',
      'post_count',
      'is_verified',
    };

    for (final key in keys) {
      if (a[key] != b[key]) {
        return false;
      }
    }

    return true;
  }

  /// Loads fresh profile data in the background
  // Add this helper method at the top of the class
  void _logBannerUpdate(String context, Map<String, dynamic> profile) {
    final banner = profile['banner'];
    final bannerType = banner != null ? banner.runtimeType.toString() : 'null';
    debugPrint('\n🖼️ BANNER UPDATE - $context');
    debugPrint('🔹 Banner URL: ${banner ?? 'null'}');
    debugPrint('🔹 Banner type: $bannerType');
    debugPrint('🔹 Profile user: ${profile['user_id']}');
    debugPrint('🔹 Current time: ${DateTime.now().toIso8601String()}');
    debugPrint('----------------------------------------');
  }

  Future<void> _loadFreshProfileData(String userId, bool hasCachedData) async {
    debugPrint('\n=== _loadFreshProfileData START ===');
    debugPrint('🔍 Requested user: $userId');
    debugPrint('🔹 Current loading user: ${_currentLoadingUserId.value}');
    debugPrint('🔹 Current profile user: ${selectedUserProfile['user_id']}');
    debugPrint('🔹 Current banner: ${selectedUserProfile['banner']}');

    if (userId.isEmpty) {
      debugPrint('❌ Error: Empty userId');
      debugPrint('=== _loadFreshProfileData END (error) ===\n');
      return;
    }

    if (_currentLoadingUserId.value != userId) {
      debugPrint(
        '⚠️ Mismatched userId. Current: ${_currentLoadingUserId.value}, Requested: $userId',
      );
      debugPrint('=== _loadFreshProfileData END (mismatch) ===\n');
      return;
    }

    try {
      debugPrint('🔄 _loadFreshProfileData: Fetching fresh data for $userId');
      debugPrint(
        '📊 Current banner before fetch: ${selectedUserProfile['banner']}',
      );

      // Fetch fresh data in parallel
      final results = await Future.wait([
        _fetchFollowCounts(userId),
        _fetchProfileData(userId),
        _fetchPostCount(userId),
      ]);

      final followCounts = results[0];
      final profileData = results[1];
      final postCountData = results[2];

      debugPrint('✅ _loadFreshProfileData: Fetched data for $userId');
      debugPrint('📥 New banner from API: ${profileData['banner']}');
      debugPrint('📥 Avatar from API: ${profileData['avatar']}');
      debugPrint('📥 Google avatar from API: ${profileData['google_avatar']}');

      // Only proceed if we're still loading the same user
      if (_currentLoadingUserId.value != userId) {
        debugPrint(
          '🛑 _loadFreshProfileData: User changed during fetch. Current: ${_currentLoadingUserId.value}, Expected: $userId',
        );
        return;
      }

      // Create a new profile with fresh data, preserving existing values if new ones are null
      // Log current banner state before update
      _logBannerUpdate('BEFORE UPDATE', selectedUserProfile);
      _logBannerUpdate('NEW DATA', profileData);

      // Get banner and avatar, preserving existing if new ones are null
      final banner = profileData['banner'] ?? selectedUserProfile['banner'];
      final avatar = profileData['avatar'] ?? selectedUserProfile['avatar'];

      // Log the decision
      debugPrint('\n🔄 BANNER SELECTION:');
      debugPrint('🔹 New banner available: ${profileData['banner'] != null}');
      debugPrint(
        '🔹 Existing banner available: ${selectedUserProfile['banner'] != null}',
      );
      debugPrint('🔹 Selected banner: ${banner ?? 'null'}');

      debugPrint('\n🔍 Creating updated profile:');
      debugPrint('🔹 New banner from API: ${profileData['banner']}');
      debugPrint(
        '🔹 Current banner in profile: ${selectedUserProfile['banner']}',
      );
      debugPrint('🔹 Will use banner: $banner');

      final updatedProfile = Map<String, dynamic>.from({
        'user_id': userId,
        'avatar': avatar,
        'banner': banner,
        ...profileData, // This will override the above if they exist in profileData
        'follower_count':
            followCounts['follower_count'] ??
            selectedUserProfile['follower_count'] ??
            0,
        'following_count':
            followCounts['following_count'] ??
            selectedUserProfile['following_count'] ??
            0,
        'post_count':
            postCountData['post_count'] ??
            selectedUserProfile['post_count'] ??
            0,
      });

      debugPrint('🔄 Created updated profile:');
      debugPrint('   Banner: ${updatedProfile['banner']}');
      debugPrint('   Avatar: ${updatedProfile['avatar']}');
      debugPrint('   Follower count: ${updatedProfile['follower_count']}');
      debugPrint('   Following count: ${updatedProfile['following_count']}');
      debugPrint('   Post count: ${updatedProfile['post_count']}');

      // Check if profiles are different
      debugPrint('\n🔍 Comparing profiles:');
      final profilesEqual = _areProfilesEqual(
        selectedUserProfile,
        updatedProfile,
      );

      debugPrint('\n🔍 Profile Comparison:');
      debugPrint('🔹 Current banner: ${selectedUserProfile['banner']}');
      debugPrint('🔹 Updated banner: ${updatedProfile['banner']}');
      debugPrint(
        '🔹 Banners match: ${selectedUserProfile['banner'] == updatedProfile['banner']}',
      );

      if (!profilesEqual) {
        debugPrint('\n🔄 Profiles are different, updating...');
        debugPrint('🔹 Old banner: ${selectedUserProfile['banner']}');
        debugPrint('🔹 New banner: ${updatedProfile['banner']}');

        debugPrint('\n💾 Updating profile state...');
        // Log the state before update
        _logBannerUpdate('BEFORE STATE UPDATE', selectedUserProfile);

        // Update the state
        selectedUserProfile.value = updatedProfile;

        // Log the state after update
        _logBannerUpdate('AFTER STATE UPDATE', selectedUserProfile);

        // Update cache
        _profileCache[userId] = updatedProfile;
        _profileLastFetch[userId] = DateTime.now();

        debugPrint('✅ Profile updated successfully');
        debugPrint('🔹 New banner in state: ${selectedUserProfile['banner']}');
      } else {
        debugPrint('\nℹ️ No changes to profile data');
        debugPrint(
          '🔹 Keeping existing banner: ${selectedUserProfile['banner']}',
        );
      }

      debugPrint('=== _loadFreshProfileData END ===\n');
    } catch (e) {
      debugPrint('❌ Error in _loadFreshProfileData: $e');

      // Mark this profile as failed to prevent infinite retries
      _failedProfileLoads.add(userId);
      debugPrint('🚫 Marked profile as failed for user: $userId');

      // Set a minimal profile to prevent UI issues
      selectedUserProfile.value = {
        'user_id': userId,
        'username': 'User',
        'nickname': 'User',
        'bio': '',
        'avatar': null,
        'banner': null,
        'google_avatar': null,
        'follower_count': 0,
        'following_count': 0,
        'post_count': 0,
        'is_verified': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Don't throw, just log the error
    }
  }

  // Check if the current user is following the selected user
  bool isFollowingUser(String userId) {
    if (userId.isEmpty) return false;

    // First check our own follow state cache (most recent)
    if (_followStateCache.containsKey(userId)) {
      final cachedState = _followStateCache[userId] ?? false;
      debugPrint(
        'Following check for $userId: $cachedState (map size: ${_followStateCache.length})',
      );
      return cachedState;
    }

    // Then check in the AccountDataProvider for cached state (fast check)
    if (_accountDataProvider.isFollowing(userId)) {
      debugPrint('User $userId found in following cache - already following');
      // Schedule the cache update for after the current build cycle
      Future.microtask(() {
        _followStateCache[userId] = true;
      });
      return true;
    }

    // If not found in either cache, we need to ensure we have the most up-to-date data
    debugPrint(
      'User $userId not found in following cache - not following or needs refresh',
    );
    // Schedule the cache update for after the current build cycle
    Future.microtask(() {
      _followStateCache[userId] = false;
    });
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

  /// Clear follow state cache for a specific user
  void clearFollowStateCache(String userId) {
    _followStateCache.remove(userId);
    _followStateFetchTime.remove(userId);
    debugPrint('Cleared follow state cache for user: $userId');
  }

  /// Clear all follow state caches
  void clearAllFollowStateCaches() {
    _followStateCache.clear();
    _followStateFetchTime.clear();
    debugPrint('Cleared all follow state caches');
  }

  /// Check if follow state is cached for a user
  bool hasFollowStateCached(String userId) {
    return _followStateCache.containsKey(userId);
  }

  /// Clear failed profile loads to allow retry
  void clearFailedProfileLoads() {
    _failedProfileLoads.clear();
    debugPrint('Cleared failed profile loads cache');
  }

  /// Remove specific user from failed profile loads
  void clearFailedProfileLoad(String userId) {
    _failedProfileLoads.remove(userId);
    debugPrint('Cleared failed profile load for user: $userId');
  }

  /// Update all caches after a follow/unfollow operation
  Future<void> _updateCachesAfterFollowChange(
    String currentUserId,
    String targetUserId,
    bool newFollowState,
  ) async {
    try {
      debugPrint('Updating caches after follow change: $newFollowState');

      // 1. Clear stale caches first
      _accountDataProvider.clearFollowCaches(currentUserId);
      clearFollowStateCache(targetUserId);

      // 2. Update ExploreController's follow state cache
      _followStateCache[targetUserId] = newFollowState;
      _followStateFetchTime[targetUserId] = DateTime.now();

      // 3. Refresh AccountDataProvider's following list to update cache
      await _accountDataProvider.loadFollowing(currentUserId);

      // 4. If we're viewing this user's profile, update the profile cache
      if (selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == targetUserId) {
        await _refreshSelectedUserProfile(targetUserId);
      }

      debugPrint('Cache update completed');
    } catch (e) {
      debugPrint('Error updating caches after follow change: $e');
    }
  }

  /// Refresh the selected user profile data and update cache
  Future<void> _refreshSelectedUserProfile(String userId) async {
    try {
      // Get updated follower count for the target user
      final updatedFollowerCount =
          (await _supabaseService.client
              .from('follows')
              .select()
              .eq('following_id', userId)).length;

      // SMART CACHE UPDATE: Only update if count has changed
      final currentCount = selectedUserProfile['follower_count'] as int? ?? 0;

      if (currentCount != updatedFollowerCount) {
        debugPrint(
          'Follower count changed for $userId: $currentCount -> $updatedFollowerCount',
        );

        // Create a new map to trigger reactive updates
        final updatedProfile = Map<String, dynamic>.from(selectedUserProfile);
        updatedProfile['follower_count'] = updatedFollowerCount;
        selectedUserProfile.value = updatedProfile;

        debugPrint(
          'Updated selectedUserProfile follower count to: $updatedFollowerCount',
        );
      } else {
        debugPrint('Follower count unchanged for $userId: $currentCount');
      }
    } catch (e) {
      debugPrint('Error refreshing selected user profile: $e');
    }
  }

  /// Update cache when profile data changes (called when opening profile page)
  Future<void> updateProfileCache(String userId) async {
    try {
      debugPrint('Checking profile cache for user: $userId');

      // Only load fresh data if we don't have recent profile data
      final hasRecentProfile =
          selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == userId;

      if (!hasRecentProfile) {
        debugPrint('Loading fresh profile data for user: $userId');
        await loadUserProfile(userId);
      } else {
        debugPrint('Using cached profile data for user: $userId');
      }

      // Only update follow state if not recently cached
      if (!hasFollowStateCached(userId) || shouldRefreshFollowState(userId)) {
        debugPrint('Updating follow state cache for user: $userId');
        await refreshFollowState(userId, forceRefresh: false);
      } else {
        debugPrint('Using cached follow state for user: $userId');
      }

      debugPrint('Profile cache check completed for user: $userId');
    } catch (e) {
      debugPrint('Error updating profile cache: $e');
    }
  }

  // Refresh the follow state for a specific user - can be called when a view is built to ensure accurate UI
  Future<bool> refreshFollowState(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null || userId.isEmpty) return false;

      // If we have a cached follow state and it's not expired, use that (unless forced)
      if (!forceRefresh &&
          !shouldRefreshFollowState(userId) &&
          _followStateCache.containsKey(userId)) {
        debugPrint('Using cached follow state for user: $userId');
        return _followStateCache[userId] ?? false;
      }

      // OPTIMIZATION: Only refresh from database if forced or cache is very old
      if (!forceRefresh) {
        // Check if we have any cached state from AccountDataProvider
        final accountProviderState = _accountDataProvider.isFollowing(userId);
        if (accountProviderState) {
          _followStateCache[userId] = true;
          markFollowStateRefreshed(userId);
          debugPrint(
            'Using AccountDataProvider cached state for user: $userId',
          );
          return true;
        }

        // If no cached state and not forced, assume not following
        _followStateCache[userId] = false;
        markFollowStateRefreshed(userId);
        debugPrint(
          'No cached state found, assuming not following user: $userId',
        );
        return false;
      }

      debugPrint('Force refreshing follow state for target user: $userId');

      // Check directly in the follows table (only when forced)
      final response = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);

      final bool isFollowing = response.isNotEmpty;

      // Cache the follow state
      _followStateCache[userId] = isFollowing;
      markFollowStateRefreshed(userId);

      // Sync with AccountDataProvider cache
      if (isFollowing && !_accountDataProvider.isFollowing(userId)) {
        final followingData = {
          'following_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        };
        _accountDataProvider.addFollowing(followingData);
      } else if (!isFollowing && _accountDataProvider.isFollowing(userId)) {
        _accountDataProvider.removeFollowing(userId);
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
        // Create a new map to trigger reactive updates
        final updatedProfile = Map<String, dynamic>.from(selectedUserProfile);
        updatedProfile['follower_count'] = newCount;
        selectedUserProfile.value = updatedProfile;
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
        // Create a new map to trigger reactive updates
        final updatedProfile = Map<String, dynamic>.from(selectedUserProfile);
        updatedProfile['follower_count'] = newCount;
        selectedUserProfile.value = updatedProfile;
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

      // CRITICAL: Always check database state, not cache, for follow operations
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

      // Get ACTUAL current state from database, not cache
      final dbResponse = await _supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);

      final isFollowing = dbResponse.isNotEmpty;
      debugPrint('Database state: currently following $userId: $isFollowing');

      // Show a loading indicator
      EasyLoading.show(status: 'Processing...');

      if (isFollowing) {
        // UNFOLLOW using repository
        await _accountDataProvider.unfollowUser(userId);
        debugPrint('Unfollowed user via repository');
      } else {
        // FOLLOW using repository
        await _accountDataProvider.followUser(userId);
        debugPrint('Followed user via repository');
      }

      // Close loading indicator
      EasyLoading.dismiss();

      // CRITICAL: Update all caches with new state
      await _updateCachesAfterFollowChange(currentUserId, userId, !isFollowing);

      // Refresh the current user's follow data
      await refreshUserFollowData(currentUserId);

      // Update UI for the target user profile
      if (selectedUserProfile.isNotEmpty &&
          selectedUserProfile['user_id'] == userId) {
        // Get updated follower count for the target user
        final updatedFollowerCount =
            (await _supabaseService.client
                .from('follows')
                .select()
                .eq('following_id', userId)).length;

        // Create a new map to trigger reactive updates
        final updatedProfile = Map<String, dynamic>.from(selectedUserProfile);
        updatedProfile['follower_count'] = updatedFollowerCount;
        selectedUserProfile.value = updatedProfile;
        debugPrint(
          'Updated target user follower count to: $updatedFollowerCount',
        );
      }

      // CRITICAL: Force refresh follow state for this user to ensure button updates
      await refreshFollowState(userId, forceRefresh: true);

      // Force UI update
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
            params: {'f_count': followerCount, 't_user_id': userId},
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

        // Update with new values - create new map to trigger reactive updates
        final updatedProfile = Map<String, dynamic>.from(selectedUserProfile);
        updatedProfile['follower_count'] = followerCount;
        updatedProfile['following_count'] = followingCount;
        selectedUserProfile.value = updatedProfile;

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
          // Create a new map to trigger reactive updates
          final updatedProfile = Map<String, dynamic>.from(selectedUserProfile);
          updatedProfile['follower_count'] = followerCount;
          selectedUserProfile.value = updatedProfile;
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

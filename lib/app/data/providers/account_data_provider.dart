import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/db_cache_service.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/startup/preloader/cache_manager.dart';

class AccountDataProvider extends GetxController {
  AccountRepository get _accountRepository => Get.find<AccountRepository>();

  // User data fields
  final RxString username = ''.obs;
  final RxString nickname = ''.obs;
  final RxString bio = ''.obs;
  final RxString avatar = ''.obs;
  final RxString banner = ''.obs;
  final RxString email = ''.obs;
  final RxString googleAvatar = ''.obs;

  // Followers and following data
  final RxList<Map<String, dynamic>> followers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> following = <Map<String, dynamic>>[].obs;
  final RxInt followerCount = 0.obs;
  final RxInt followingCount = 0.obs;

  // Posts data from separate posts table
  final RxList<Map<String, dynamic>> posts = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> userPostData = <String, dynamic>{}.obs;

  // Optimized HashMaps for O(1) lookups
  final RxMap<String, bool> _followersMap = <String, bool>{}.obs;
  final RxMap<String, bool> _followingMap = <String, bool>{}.obs;
  final RxMap<String, Map<String, dynamic>> _postsMap =
      <String, Map<String, dynamic>>{}.obs;

  // Cache times for follow data
  final Map<String, DateTime> _followersFetchTime = {};
  final Map<String, DateTime> _followingFetchTime = {};

  // Cache duration constant - how long to cache follow data
  static const Duration followCacheDuration = Duration(minutes: 15);

  @override
  void onInit() {
    super.onInit();
    // Load banner URL when the provider initializes
    initializeDefaultStructures();
  }

  // Helper getters for easy access
  int get postsCount => userPostData['post_count'] as int? ?? 0;

  // Post type counts (calculated from posts list)
  int get threadsCount =>
      posts.where((post) => post['post_type'] == 'text').length;
  int get imagesCount =>
      posts.where((post) => post['post_type'] == 'image').length;
  int get gifsCount => posts.where((post) => post['post_type'] == 'gif').length;
  int get stickersCount =>
      posts.where((post) => post['post_type'] == 'sticker').length;

  // Get lists of user IDs for followers/following
  List<String> get followerIds =>
      followers.map((f) => f['follower_id'] as String).toList();
  List<String> get followingIds =>
      following.map((f) => f['following_id'] as String).toList();

  // Category-specific post lists
  List<Map<String, dynamic>> get threadsList =>
      posts.where((post) => post['post_type'] == 'text').toList();

  List<Map<String, dynamic>> get imagesList =>
      posts.where((post) => post['post_type'] == 'image').toList();

  List<Map<String, dynamic>> get gifsList =>
      posts.where((post) => post['post_type'] == 'gif').toList();

  List<Map<String, dynamic>> get stickersList =>
      posts.where((post) => post['post_type'] == 'sticker').toList();

  // All posts (already in posts RxList)
  List<Map<String, dynamic>> get allPosts => posts;

  // Fast lookup methods - O(1) operations
  bool isFollower(String userId) {
    final result = _followersMap[userId] ?? false;
    debugPrint(
      'Follower check for $userId: $result (map size: ${_followersMap.length})',
    );
    return result;
  }

  bool isFollowing(String userId) {
    if (userId.isEmpty) return false;

    // Make sure the following map is built (needed after hot restart)
    if (_followingMap.isEmpty && following.isNotEmpty) {
      _rebuildFollowingMap();
      debugPrint(
        'Rebuilt following map after finding it empty. Now has ${_followingMap.length} entries',
      );
    }

    final result = _followingMap[userId] ?? false;
    return result;
  }

  Map<String, dynamic>? getPost(String postId) => _postsMap[postId];

  // Initialize all data structures with default values
  void initializeDefaultStructures() {
    // Initialize lists if empty
    if (followers.isEmpty) {
      followers.value = [];
    }

    if (following.isEmpty) {
      following.value = [];
    }

    if (posts.isEmpty) {
      posts.value = [];
    }

    if (userPostData.isEmpty) {
      userPostData.value = {'post_count': 0};
    }

    // Rebuild HashMaps from primary data structures
    _rebuildFollowersMap();
    _rebuildFollowingMap();
    _rebuildPostsMap();
  }

  // Update entire following list and ensure count accuracy
  void updateFollowing(List<Map<String, dynamic>> newFollowing) {
    following.value = newFollowing;
    followingCount.value = newFollowing.length;
    _rebuildFollowingMap();
    debugPrint('Updated following count to: ${followingCount.value}');
  }

  // Update entire followers list and ensure count accuracy
  void updateFollowers(List<Map<String, dynamic>> newFollowers) {
    followers.value = newFollowers;
    followerCount.value = newFollowers.length;
    _rebuildFollowersMap();
    debugPrint('Updated follower count to: ${followerCount.value}');
  }

  void updatePosts(List<Map<String, dynamic>> newPosts) {
    posts.value = newPosts;
    userPostData.value = {'post_count': newPosts.length};
    _rebuildPostsMap();
  }

  // Update user posts data in memory only
  void updateUserPostData(Map<String, dynamic> newUserPostData) {
    userPostData.value = newUserPostData;
    debugPrint('Updated local user post data (not in database)');
  }

  // Add a follower to the list (usually from realtime updates)
  void addFollower(Map<String, dynamic> follower) {
    if (follower['follower_id'] != null &&
        !isFollower(follower['follower_id'])) {
      followers.add(follower);
      _followersMap[follower['follower_id']] = true;
      followerCount.value = followers.length;
    }
  }

  // Remove a follower from the list (usually from realtime updates)
  void removeFollower(String userId) {
    final index = followers.indexWhere((f) => f['follower_id'] == userId);
    if (index != -1) {
      followers.removeAt(index);
      _followersMap.remove(userId);
      followerCount.value = followers.length;
    }
  }

  // Add a following to the list with count update
  void addFollowing(Map<String, dynamic> followingUser) {
    if (followingUser['following_id'] != null &&
        !isFollowing(followingUser['following_id'])) {
      following.add(followingUser);
      _followingMap[followingUser['following_id']] = true;
      followingCount.value = following.length;
      debugPrint('Added following, new count: ${followingCount.value}');
    }
  }

  // Remove a following from the list with count update
  void removeFollowing(String userId) {
    final index = following.indexWhere((f) => f['following_id'] == userId);
    if (index != -1) {
      following.removeAt(index);
      _followingMap.remove(userId);
      followingCount.value = following.length;
      debugPrint('Removed following, new count: ${followingCount.value}');
    }
  }

  // Verify and sync follow counts with database
  Future<void> verifyFollowCounts(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();

      final followersResponse = await supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);

      final followingResponse = await supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId);

      final int actualFollowerCount = (followersResponse as List).length;
      final int actualFollowingCount = (followingResponse as List).length;

      if (followerCount.value != actualFollowerCount ||
          followingCount.value != actualFollowingCount) {
        debugPrint('Follow count mismatch detected, syncing with database...');
        debugPrint(
          'Followers: Local=${followerCount.value}, Actual=$actualFollowerCount',
        );
        debugPrint(
          'Following: Local=${followingCount.value}, Actual=$actualFollowingCount',
        );

        // Update local counts
        followerCount.value = actualFollowerCount;
        followingCount.value = actualFollowingCount;

        // Update database
        await supabaseService.client.from('profiles').upsert({
          'user_id': userId,
          'follower_count': actualFollowerCount,
          'following_count': actualFollowingCount,
        });

        debugPrint('Follow counts synchronized successfully');
      }
    } catch (e) {
      debugPrint('Error verifying follow counts: $e');
    }
  }

  // Private methods to rebuild HashMaps from primary structures
  void _rebuildFollowersMap() {
    _followersMap.clear();
    for (final follower in followers) {
      if (follower['follower_id'] != null) {
        _followersMap[follower['follower_id']] = true;
      }
    }
  }

  void _rebuildFollowingMap() {
    _followingMap.clear();
    for (final followingUser in following) {
      if (followingUser['following_id'] != null) {
        _followingMap[followingUser['following_id']] = true;
      }
    }
  }

  void _rebuildPostsMap() {
    _postsMap.clear();
    for (final post in posts) {
      if (post['id'] != null) {
        _postsMap[post['id'].toString()] = post;
      }
    }
  }

  /// Clears all user data when signing out
  void clearData() {
    username.value = '';
    nickname.value = '';
    bio.value = '';
    avatar.value = '';
    email.value = '';
    googleAvatar.value = '';
    followers.clear();
    following.clear();
    followerCount.value = 0;
    followingCount.value = 0;
    posts.clear();
    userPostData.value = {'post_count': 0};

    // Reset social data structures to defaults
    initializeDefaultStructures();
  }

  /// Load followers data for the current user with enhanced caching
  Future<void> loadFollowers(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();
      final cacheManager = Get.find<CacheManager>();

      // First try to get from persistent cache
      final cachedFollowers = await cacheManager.getCachedUserFollowers(userId);
      if (cachedFollowers != null) {
        followers.value = cachedFollowers;
        followerCount.value = cachedFollowers.length;
        _rebuildFollowersMap();
        _followersFetchTime[userId] = DateTime.now();
        debugPrint(
          'Loaded ${followers.length} followers for user $userId from persistent cache',
        );
        return;
      }

      // Check if we have recently fetched this data
      final lastFetch = _followersFetchTime[userId];
      final now = DateTime.now();
      if (lastFetch != null &&
          now.difference(lastFetch) < SupabaseService.followCacheDuration &&
          followers.isNotEmpty) {
        debugPrint('Using cached followers data for user $userId');
        return;
      }

      debugPrint('Loading followers for user $userId');

      // Get followers from cache or fetch from API
      final followersList = await dbCacheService.getFollowers(userId, () async {
        // Fetch followers from the database
        final response = await supabaseService.client.rpc(
          'get_followers',
          params: {'p_user_id': userId},
        );

        if (response == null) {
          return _getFallbackFollowers(userId);
        }

        return List<Map<String, dynamic>>.from(response);
      });

      // Update the data
      followers.value = followersList;
      followerCount.value = followersList.length;
      _rebuildFollowersMap();
      _followersFetchTime[userId] = now;

      // Cache the followers for persistent storage
      await cacheManager.cacheUserFollowers(userId, followersList);

      debugPrint('Set follower count to: ${followerCount.value}');
    } catch (e) {
      debugPrint('Error loading followers: $e');
      await _handleFollowerLoadError(userId);
    }
  }

  /// Load following data for the current user with enhanced caching
  Future<void> loadFollowing(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();
      final cacheManager = Get.find<CacheManager>();

      // First try to get from persistent cache
      final cachedFollowing = await cacheManager.getCachedUserFollowing(userId);
      if (cachedFollowing != null) {
        following.value = cachedFollowing;
        followingCount.value = cachedFollowing.length;
        _rebuildFollowingMap();
        _followingFetchTime[userId] = DateTime.now();
        debugPrint(
          'Loaded ${following.length} following for user $userId from persistent cache',
        );
        return;
      }

      // Check if we have recently fetched this data
      final lastFetch = _followingFetchTime[userId];
      final now = DateTime.now();
      if (lastFetch != null &&
          now.difference(lastFetch) < SupabaseService.followCacheDuration &&
          following.isNotEmpty) {
        debugPrint('Using cached following data for user $userId');
        return;
      }

      debugPrint('Loading following for user $userId');

      // Get following from cache or fetch from API
      final followingList = await dbCacheService.getFollowing(userId, () async {
        // Fetch following from the database
        final response = await supabaseService.client.rpc(
          'get_following',
          params: {'p_user_id': userId},
        );

        if (response == null) {
          return _getFallbackFollowing(userId);
        }

        return List<Map<String, dynamic>>.from(response);
      });

      // Update the data
      following.value = followingList;
      followingCount.value = followingList.length;
      _rebuildFollowingMap();
      _followingFetchTime[userId] = now;

      // Cache the following for persistent storage
      await cacheManager.cacheUserFollowing(userId, followingList);

      debugPrint('Set following count to: ${followingCount.value}');
    } catch (e) {
      debugPrint('Error loading following: $e');
      await _handleFollowingLoadError(userId);
    }
  }

  // Helper method to get fallback followers count
  Future<List<Map<String, dynamic>>> _getFallbackFollowers(
    String userId,
  ) async {
    final supabaseService = Get.find<SupabaseService>();
    final countResponse = await supabaseService.client
        .from('follows')
        .select()
        .eq('following_id', userId);

    followers.value = [];
    followerCount.value = (countResponse as List).length;
    debugPrint('Set follower count from fallback: ${followerCount.value}');
    return [];
  }

  // Helper method to get fallback following count
  Future<List<Map<String, dynamic>>> _getFallbackFollowing(
    String userId,
  ) async {
    final supabaseService = Get.find<SupabaseService>();
    final countResponse = await supabaseService.client
        .from('follows')
        .select()
        .eq('follower_id', userId);

    following.value = [];
    followingCount.value = (countResponse as List).length;
    debugPrint('Set following count from fallback: ${followingCount.value}');
    return [];
  }

  // Helper method to handle follower load errors
  Future<void> _handleFollowerLoadError(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final countResponse = await supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);

      followers.value = [];
      followerCount.value = (countResponse as List).length;
      debugPrint(
        'Set follower count from error handler: ${followerCount.value}',
      );
    } catch (fallbackError) {
      debugPrint('Fallback follower count also failed: $fallbackError');
      followers.value = [];
      followerCount.value = 0;
    }
  }

  // Helper method to handle following load errors
  Future<void> _handleFollowingLoadError(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final countResponse = await supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId);

      following.value = [];
      followingCount.value = (countResponse as List).length;
      debugPrint(
        'Set following count from error handler: ${followingCount.value}',
      );
    } catch (fallbackError) {
      debugPrint('Fallback following count also failed: $fallbackError');
      following.value = [];
      followingCount.value = 0;
    }
  }

  // Clear follow caches for a user
  void clearFollowCaches(String userId) {
    _followersFetchTime.remove(userId);
    _followingFetchTime.remove(userId);
  }

  /// Load user posts from the posts table with enhanced caching
  Future<void> loadUserPosts(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();
      final cacheManager = Get.find<CacheManager>();

      // First try to get from persistent cache
      final cachedPosts = await cacheManager.getCachedUserPosts(userId);
      if (cachedPosts != null) {
        posts.value = cachedPosts;
        _rebuildPostsMap();
        userPostData['post_count'] = cachedPosts.length;
        debugPrint(
          'Loaded ${posts.length} posts for user $userId from persistent cache',
        );
        return;
      }

      // Get posts from db cache or fetch from API
      final postsList = await dbCacheService.getUserPosts(userId, () async {
        // Fetch posts from the database
        final response = await supabaseService.client
            .from('posts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      });

      posts.value = postsList;
      _rebuildPostsMap();

      // Update post count in local data structure only
      userPostData.value = {'post_count': postsList.length};
      debugPrint(
        'Updated local post count to ${postsList.length} (not in database)',
      );

      // Cache the posts for persistent storage
      await cacheManager.cacheUserPosts(userId, postsList);

      debugPrint('Loaded ${posts.length} posts for user $userId');
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      posts.value = [];
    }
  }

  /// Fetch user profile data using AccountRepository
  Future<Map<String, dynamic>> fetchUserData() async {
    return await _accountRepository.userRealtimeData();
  }

  /// Add a new post using AccountRepository
  Future<void> addNewPost(
    Map<String, dynamic> postData,
    String category,
  ) async {
    // await _accountRepository.addNewPost(postData, category);
  }

  /// Delete a post using AccountRepository
  Future<void> deletePost(String postId) async {
    // await _accountRepository.deletePost(postId);
  }

  /// Follow a user using AccountRepository
  Future<Map<String, dynamic>> followUser(String targetUserId) async {
    return await _accountRepository.followUser(targetUserId);
  }

  /// Unfollow a user using AccountRepository
  Future<void> unfollowUser(String targetUserId) async {
    await _accountRepository.unfollowUser(targetUserId);
  }

  /// Accept a follow request
  Future<void> acceptFollowRequest(String requesterId) async {
    await _accountRepository.acceptFollowRequest(requesterId);
  }

  /// Reject a follow request
  Future<void> rejectFollowRequest(String requesterId) async {
    await _accountRepository.rejectFollowRequest(requesterId);
  }

  /// Check if there's a pending follow request
  Future<bool> hasFollowRequest(String targetUserId) async {
    return await _accountRepository.hasFollowRequest(targetUserId);
  }

  /// Get list of pending follow requests
  Future<List<Map<String, dynamic>>> getFollowRequests() async {
    return await _accountRepository.getFollowRequests();
  }

  /// Process followers data using AccountRepository
  void processFollowersData(dynamic followersData) {
    _accountRepository.processFollowersData(followersData);
  }

  /// Process following data using AccountRepository
  void processFollowingData(dynamic followingData) {
    _accountRepository.processFollowingData(followingData);
  }

  /// Checks if followers data should be refreshed for a specific user
  bool shouldRefreshFollowers(String userId) {
    final lastFetch = _followersFetchTime[userId];
    final now = DateTime.now();

    // Refresh if we haven't fetched before, or if cache is expired, or if followers list is empty
    return lastFetch == null ||
        now.difference(lastFetch) > SupabaseService.followCacheDuration ||
        followers.isEmpty;
  }

  /// Checks if following data should be refreshed for a specific user
  bool shouldRefreshFollowing(String userId) {
    final lastFetch = _followingFetchTime[userId];
    final now = DateTime.now();

    // Refresh if we haven't fetched before, or if cache is expired, or if following list is empty
    return lastFetch == null ||
        now.difference(lastFetch) > SupabaseService.followCacheDuration ||
        following.isEmpty;
  }

  /// Gets the key used for caching followers data
  String getFollowersFetchKey(String userId) {
    return 'followers_$userId';
  }

  /// Gets the key used for caching following data
  String getFollowingFetchKey(String userId) {
    return 'following_$userId';
  }

  /// Preload user data for app optimization
  Future<void> preloadUserData() async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final userId = supabaseService.currentUser.value?.id;

      if (userId == null) {
        debugPrint(
          'AccountDataProvider: Cannot preload data - user not authenticated',
        );
        return;
      }

      debugPrint('AccountDataProvider: Starting user data preload for $userId');

      // Preload user profile data
      final userData = await fetchUserData();
      if (userData.isNotEmpty) {
        username.value = userData['username'] ?? '';
        nickname.value = userData['nickname'] ?? '';
        bio.value = userData['bio'] ?? '';
        avatar.value = userData['avatar'] ?? '';
        banner.value = userData['banner'] ?? '';
        email.value = userData['email'] ?? '';
        googleAvatar.value = userData['google_avatar'] ?? '';

        // CRITICAL FIX: Force refresh all reactive values to ensure UI updates
        username.refresh();
        nickname.refresh();
        bio.refresh();
        avatar.refresh();
        banner.refresh();
        email.refresh();
        googleAvatar.refresh();

        debugPrint('AccountDataProvider: Profile data preloaded and refreshed');
        debugPrint('  Username: ${username.value}');
        debugPrint('  Nickname: ${nickname.value}');
        debugPrint('  Avatar: ${avatar.value}');
        debugPrint('  Google Avatar: ${googleAvatar.value}');
      }

      // OPTIMIZATION: Only load counts if they're not already cached or very old
      final now = DateTime.now();
      final lastCountsUpdate = _followersFetchTime[userId];

      if (lastCountsUpdate == null ||
          now.difference(lastCountsUpdate) > Duration(minutes: 5)) {
        debugPrint('Loading fresh counts from follows table');
        await _loadCountsFromFollowsTable(userId);
      } else {
        debugPrint('Using cached follower/following counts');
      }

      // Preload followers and following data in parallel
      await Future.wait([
        loadFollowers(userId),
        loadFollowing(userId),
        loadUserPosts(userId),
      ]);

      debugPrint('AccountDataProvider: User data preload completed');
    } catch (e) {
      debugPrint('AccountDataProvider: Error preloading user data: $e');
    }
  }

  /// Updates the followers cache timestamp without fetching new data
  void markFollowersFetched(String userId) {
    _followersFetchTime[userId] = DateTime.now();
  }

  /// Force refresh profile data after updates (like avatar changes)
  Future<void> forceRefreshProfileData() async {
    try {
      debugPrint('AccountDataProvider: Force refreshing profile data');

      // Fetch fresh user data from database
      final userData = await fetchUserData();
      if (userData.isNotEmpty) {
        // Update all user data fields
        username.value = userData['username'] ?? '';
        nickname.value = userData['nickname'] ?? '';
        bio.value = userData['bio'] ?? '';
        avatar.value = userData['avatar'] ?? '';
        banner.value = userData['banner'] ?? '';
        email.value = userData['email'] ?? '';
        googleAvatar.value = userData['google_avatar'] ?? '';

        // Force refresh all reactive values to ensure UI updates
        username.refresh();
        nickname.refresh();
        bio.refresh();
        avatar.refresh();
        banner.refresh();
        email.refresh();
        googleAvatar.refresh();

        debugPrint('AccountDataProvider: Profile data force refreshed');
        debugPrint('  Username: ${username.value}');
        debugPrint('  Nickname: ${nickname.value}');
        debugPrint('  Avatar: ${avatar.value}');
        debugPrint('  Google Avatar: ${googleAvatar.value}');
      }
    } catch (e) {
      debugPrint(
        'AccountDataProvider: Error force refreshing profile data: $e',
      );
    }
  }

  /// Updates the following cache timestamp without fetching new data
  void markFollowingFetched(String userId) {
    _followingFetchTime[userId] = DateTime.now();
  }

  /// Refresh follower and following counts from the accurate source (follows table)
  Future<void> refreshFollowCounts(String userId) async {
    await _loadCountsFromFollowsTable(userId);
  }

  /// Load counts directly from follows table for accurate display
  Future<void> _loadCountsFromFollowsTable(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();

      // Get accurate counts from follows table
      final followerResponse = await supabaseService.client
          .from('follows')
          .select()
          .eq('following_id', userId);

      final followingResponse = await supabaseService.client
          .from('follows')
          .select()
          .eq('follower_id', userId);

      final actualFollowerCount = followerResponse.length;
      final actualFollowingCount = followingResponse.length;

      debugPrint(
        'AccountDataProvider: _loadCountsFromFollowsTable for user $userId',
      );
      debugPrint('  - Actual Followers: $actualFollowerCount');
      debugPrint('  - Actual Following: $actualFollowingCount');

      // SMART CACHE UPDATE: Only update if values have changed
      bool countsChanged = false;

      if (followerCount.value != actualFollowerCount) {
        debugPrint(
          'Follower count changed: ${followerCount.value} -> $actualFollowerCount',
        );
        followerCount.value = actualFollowerCount;
        countsChanged = true;
      }

      if (followingCount.value != actualFollowingCount) {
        debugPrint(
          'Following count changed: ${followingCount.value} -> $actualFollowingCount',
        );
        followingCount.value = actualFollowingCount;
        countsChanged = true;
      }

      if (!countsChanged) {
        debugPrint('Counts unchanged, using cached values');
      }

      // Only update the profiles table if counts actually changed
      if (countsChanged) {
        await supabaseService.client.from('profiles').upsert({
          'user_id': userId,
          'follower_count': actualFollowerCount,
          'following_count': actualFollowingCount,
        });
        debugPrint(
          'AccountDataProvider: Updated profiles table with new counts',
        );
      } else {
        debugPrint(
          'AccountDataProvider: Skipped profiles table update - no changes',
        );
      }
    } catch (e) {
      debugPrint(
        'AccountDataProvider: Error loading counts from follows table: $e',
      );
      // Fallback to profiles table
      await _loadCountsFromProfiles(userId);
    }
  }

  /// Load counts directly from profiles table for immediate display
  Future<void> _loadCountsFromProfiles(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();

      // Get counts from profiles table
      final response =
          await supabaseService.client
              .from('profiles')
              .select('follower_count, following_count')
              .eq('user_id', userId)
              .single();

      final dbFollowerCount = response['follower_count'] as int? ?? 0;
      final dbFollowingCount = response['following_count'] as int? ?? 0;

      debugPrint(
        'AccountDataProvider: _loadCountsFromProfiles for user $userId',
      );
      debugPrint('  - DB Followers: $dbFollowerCount');
      debugPrint('  - DB Following: $dbFollowingCount');

      // Update the reactive counts immediately
      followerCount.value = dbFollowerCount;
      followingCount.value = dbFollowingCount;

      // Also get posts count from posts table
      final postsResponse = await supabaseService.client
          .from('posts')
          .select('id')
          .eq('user_id', userId);

      final dbPostsCount = (postsResponse as List).length;
      userPostData.value = {'post_count': dbPostsCount};

      // Force refresh to ensure UI updates
      followerCount.refresh();
      followingCount.refresh();
      userPostData.refresh();

      debugPrint('AccountDataProvider: Loaded counts from database');
      debugPrint('  Follower count: ${followerCount.value}');
      debugPrint('  Following count: ${followingCount.value}');
      debugPrint('  Posts count: $dbPostsCount');
    } catch (e) {
      debugPrint('AccountDataProvider: Error loading counts from profiles: $e');
      // Set to 0 on error to avoid showing stale data
      followerCount.value = 0;
      followingCount.value = 0;
    }
  }

  /// Increment post count (used when user creates a post optimistically)
  void incrementPostCount() {
    final current = userPostData['post_count'] as int? ?? 0;
    userPostData['post_count'] = current + 1;
    userPostData.refresh();
    debugPrint('AccountDataProvider: incremented post_count to ${current + 1}');
  }

  /// Decrement post count safely (used when a post is deleted)
  void decrementPostCount() {
    final current = userPostData['post_count'] as int? ?? 0;
    final newCount = current > 0 ? current - 1 : 0;
    userPostData['post_count'] = newCount;
    userPostData.refresh();
    debugPrint('AccountDataProvider: decremented post_count to $newCount');
  }

  /// Public helper to refresh follower/following/post counts from database
  Future<void> refreshCounts(String userId) async {
    await _loadCountsFromProfiles(userId);
  }
}

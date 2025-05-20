import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/db_cache_service.dart';

class AccountDataProvider extends GetxController {
  final RxString username = ''.obs;
  final RxString nickname = ''.obs;
  final RxString bio = ''.obs;
  final RxString avatar = ''.obs;
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

  // Recent searches
  final RxList<Map<String, dynamic>> searches = <Map<String, dynamic>>[].obs;

  // Optimized HashMaps for O(1) lookups
  final RxMap<String, bool> _followersMap = <String, bool>{}.obs;
  final RxMap<String, bool> _followingMap = <String, bool>{}.obs;
  final RxMap<String, Map<String, dynamic>> _postsMap =
      <String, Map<String, dynamic>>{}.obs;
  final RxMap<String, Map<String, dynamic>> _searchesMap =
      <String, Map<String, dynamic>>{}.obs;

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
  bool isFollower(String userId) => _followersMap[userId] ?? false;
  bool isFollowing(String userId) => _followingMap[userId] ?? false;
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

    if (searches.isEmpty) {
      searches.value = [];
    }

    // Rebuild HashMaps from primary data structures
    _rebuildFollowersMap();
    _rebuildFollowingMap();
    _rebuildPostsMap();
    _rebuildSearchesMap();
  }

  // Update entire followers list
  void updateFollowers(List<Map<String, dynamic>> newFollowers) {
    followers.value = newFollowers;
    followerCount.value = newFollowers.length;
    _rebuildFollowersMap();
  }

  // Update entire following list
  void updateFollowing(List<Map<String, dynamic>> newFollowing) {
    following.value = newFollowing;
    followingCount.value = newFollowing.length;
    _rebuildFollowingMap();
  }

  void updatePosts(List<Map<String, dynamic>> newPosts) {
    posts.value = newPosts;
    userPostData.value = {'post_count': newPosts.length};
    _rebuildPostsMap();
  }

  // Update user_posts data directly
  void updateUserPostData(Map<String, dynamic> newUserPostData) {
    userPostData.value = newUserPostData;
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

  // Add a following to the list (usually from realtime updates)
  void addFollowing(Map<String, dynamic> followingUser) {
    if (followingUser['following_id'] != null &&
        !isFollowing(followingUser['following_id'])) {
      following.add(followingUser);
      _followingMap[followingUser['following_id']] = true;
      followingCount.value = following.length;
    }
  }

  // Remove a following from the list (usually from realtime updates)
  void removeFollowing(String userId) {
    final index = following.indexWhere((f) => f['following_id'] == userId);
    if (index != -1) {
      following.removeAt(index);
      _followingMap.remove(userId);
      followingCount.value = following.length;
    }
  }

  // Add a new post to the list (local update before database)
  void addPost(Map<String, dynamic> post) {
    if (post['id'] != null) {
      posts.add(post);
      _postsMap[post['id'].toString()] = post;

      // Update the post count
      userPostData['post_count'] =
          (userPostData['post_count'] as int? ?? 0) + 1;
    }
  }

  // Remove a post from the list (local update before database)
  void removePost(String postId) {
    if (_postsMap.containsKey(postId)) {
      posts.removeWhere((post) => post['id'].toString() == postId);
      _postsMap.remove(postId);

      // Update the post count
      userPostData['post_count'] =
          (userPostData['post_count'] as int? ?? 0) - 1;
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

  @override
  void onInit() {
    super.onInit();
    // Initialize default structures
    initializeDefaultStructures();
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
    searches.clear();
    posts.clear();
    userPostData.value = {'post_count': 0};

    // Reset social data structures to defaults
    initializeDefaultStructures();
  }

  /// Load followers data for the current user
  Future<void> loadFollowers(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();

      debugPrint('Loading followers for user $userId');

      // Get followers from cache or fetch from API
      final followersList = await dbCacheService.getFollowers(userId, () async {
        // Fetch followers from the database
        final response = await supabaseService.client.rpc(
          'get_followers',
          params: {'p_user_id': userId},
        );

        if (response == null) {
          // Fallback to direct count
          final countResponse = await supabaseService.client
              .from('follows')
              .select()
              .eq('following_id', userId);

          return [];
        }

        return List<Map<String, dynamic>>.from(response);
      });

      // Update the data
      followers.value = followersList;
      followerCount.value = followersList.length;
      _rebuildFollowersMap();

      debugPrint('Set follower count to: ${followerCount.value}');
    } catch (e) {
      debugPrint('Error loading followers: $e');
      // Try direct count as fallback
      try {
        final supabaseService = Get.find<SupabaseService>();
        final countResponse = await supabaseService.client
            .from('follows')
            .select()
            .eq('following_id', userId);

        final int directFollowerCount = (countResponse as List).length;
        followers.value = [];
        followerCount.value = directFollowerCount;
        debugPrint('Set follower count from fallback: $directFollowerCount');
      } catch (fallbackError) {
        debugPrint('Fallback follower count also failed: $fallbackError');
        followers.value = [];
        followerCount.value = 0;
      }
    }
  }

  /// Load following data for the current user
  Future<void> loadFollowing(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();

      debugPrint('Loading following for user $userId');

      // Get following from cache or fetch from API
      final followingList = await dbCacheService.getFollowing(userId, () async {
        // Fetch following from the database
        final response = await supabaseService.client.rpc(
          'get_following',
          params: {'p_user_id': userId},
        );

        if (response == null) {
          // Fallback to direct count
          final countResponse = await supabaseService.client
              .from('follows')
              .select()
              .eq('follower_id', userId);

          return [];
        }

        return List<Map<String, dynamic>>.from(response);
      });

      // Update the data
      following.value = followingList;
      followingCount.value = followingList.length;
      _rebuildFollowingMap();

      debugPrint('Set following count to: ${followingCount.value}');
    } catch (e) {
      debugPrint('Error loading following: $e');
      // Try direct count as fallback
      try {
        final supabaseService = Get.find<SupabaseService>();
        final countResponse = await supabaseService.client
            .from('follows')
            .select()
            .eq('follower_id', userId);

        final int directFollowingCount = (countResponse as List).length;
        following.value = [];
        followingCount.value = directFollowingCount;
        debugPrint('Set following count from fallback: $directFollowingCount');
      } catch (fallbackError) {
        debugPrint('Fallback following count also failed: $fallbackError');
        following.value = [];
        followingCount.value = 0;
      }
    }
  }

  /// Load user posts from the posts table
  Future<void> loadUserPosts(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();

      // Get posts from cache or fetch from API
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

      // Update post count in user_posts data
      userPostData['post_count'] = postsList.length;

      debugPrint('Loaded ${posts.length} posts for user $userId');
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      posts.value = [];
    }
  }

  /// Load searches from database with caching
  Future<void> loadSearches() async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final dbCacheService = Get.find<DbCacheService>();

      final userId = supabaseService.currentUser.value?.id;
      if (userId == null) return;

      // Try to get profile data from cache or API
      final userData = await dbCacheService.getUserProfile(userId, () async {
        // Fetch from database
        final profile =
            await supabaseService.client
                .from('profiles')
                .select('searches')
                .eq('user_id', userId)
                .single();

        return profile;
      });

      if (userData != null &&
          userData.isNotEmpty &&
          userData['searches'] != null) {
        List<dynamic> searchesList = userData['searches'];
        searches.value = List<Map<String, dynamic>>.from(
          searchesList.map((item) => Map<String, dynamic>.from(item)),
        );
        _rebuildSearchesMap();
        debugPrint('Loaded ${searches.length} recent searches');
      }
    } catch (e) {
      debugPrint('Error loading searches: $e');
      // Initialize with empty list if there's an error
      searches.value = [];
    }
  }

  /// Update searches in memory and database
  Future<void> updateSearches(List<Map<String, dynamic>> newSearches) async {
    try {
      searches.value = List<Map<String, dynamic>>.from(newSearches);
      _rebuildSearchesMap();

      // Update in database
      final supabaseService = Get.find<SupabaseService>();
      final userId = supabaseService.currentUser.value?.id;

      if (userId == null) return;

      await supabaseService.client
          .from('profiles')
          .update({'searches': searches})
          .eq('user_id', userId);

      debugPrint('Updated searches in database');
    } catch (e) {
      debugPrint('Error updating searches: $e');
    }
  }

  /// Check if a user exists in recent searches
  bool hasUserInSearches(String userId) => _searchesMap.containsKey(userId);

  /// Get a user from recent searches by ID
  Map<String, dynamic>? getUserFromSearches(String userId) =>
      _searchesMap[userId];

  /// Rebuild the searches map for O(1) lookups
  void _rebuildSearchesMap() {
    _searchesMap.clear();
    for (final search in searches) {
      if (search['user_id'] != null) {
        _searchesMap[search['user_id'].toString()] = search;
      }
    }
  }

  /// Update the searches map directly
  void updateSearchesMap(Map<String, Map<String, dynamic>> newMap) {
    _searchesMap.clear();
    _searchesMap.addAll(newMap);
  }
}

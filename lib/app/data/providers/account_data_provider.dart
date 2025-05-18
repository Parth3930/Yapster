import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class AccountDataProvider extends GetxController {
  final RxString username = ''.obs;
  final RxString nickname = ''.obs;
  final RxString bio = ''.obs;
  final RxString avatar = ''.obs;
  final RxString email = ''.obs;
  final RxString googleAvatar = ''.obs;

  // Primary data structures
  final RxMap<String, dynamic> followers = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> following = <String, dynamic>{}.obs;

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
  int get followersCount => followers['count'] as int? ?? 0;
  int get followingCount => following['count'] as int? ?? 0;
  int get postsCount => userPostData['post_count'] as int? ?? 0;

  // Post type counts (calculated from posts list)
  int get threadsCount => posts.where((post) => post['post_type'] == 'text').length;
  int get imagesCount => posts.where((post) => post['post_type'] == 'image').length;
  int get gifsCount => posts.where((post) => post['post_type'] == 'gif').length;
  int get stickersCount => posts.where((post) => post['post_type'] == 'sticker').length;

  List<String> get followersList => List<String>.from(followers['users'] ?? []);
  List<String> get followingList => List<String>.from(following['users'] ?? []);

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
  bool isFollower(String username) => _followersMap[username] ?? false;
  bool isFollowing(String username) => _followingMap[username] ?? false;
  Map<String, dynamic>? getPost(String postId) => _postsMap[postId];

  // Initialize all data structures with default values
  void initializeDefaultStructures() {
    // Default followers structure
    if (followers.isEmpty || followers['users'] == null) {
      followers.value = {'count': 0, 'users': <String>[]};
    }

    // Default following structure
    if (following.isEmpty || following['users'] == null) {
      following.value = {'count': 0, 'users': <String>[]};
    }

    // Initialize posts list if empty
    if (posts.isEmpty) {
      posts.value = [];
    }
    
    // Initialize user post data if empty
    if (userPostData.isEmpty) {
      userPostData.value = {'post_count': 0};
    }
    
    // Initialize searches structure if empty
    if (searches.isEmpty) {
      searches.value = [];
    }

    // Rebuild HashMaps from primary data structures
    _rebuildFollowersMap();
    _rebuildFollowingMap();
    _rebuildPostsMap();
    _rebuildSearchesMap();
  }

  // Update methods that keep HashMaps in sync
  void updateFollowers(Map<String, dynamic> newFollowers) {
    followers.value = newFollowers;
    _rebuildFollowersMap();
  }

  void updateFollowing(Map<String, dynamic> newFollowing) {
    following.value = newFollowing;
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

  // Methods to add/remove individual items
  void addFollower(String username) {
    if (!isFollower(username)) {
      final List<String> users = List<String>.from(followers['users'] ?? []);
      users.add(username);
      followers['users'] = users;
      followers['count'] = users.length;
      _followersMap[username] = true;
    }
  }

  void removeFollower(String username) {
    if (isFollower(username)) {
      final List<String> users = List<String>.from(followers['users'] ?? []);
      users.remove(username);
      followers['users'] = users;
      followers['count'] = users.length;
      _followersMap.remove(username);
    }
  }

  void addFollowing(String username) {
    if (!isFollowing(username)) {
      final List<String> users = List<String>.from(following['users'] ?? []);
      users.add(username);
      following['users'] = users;
      following['count'] = users.length;
      _followingMap[username] = true;
    }
  }

  void removeFollowing(String username) {
    if (isFollowing(username)) {
      final List<String> users = List<String>.from(following['users'] ?? []);
      users.remove(username);
      following['users'] = users;
      following['count'] = users.length;
      _followingMap.remove(username);
    }
  }

  // Add a new post to the list (local update before database)
  void addPost(Map<String, dynamic> post) {
    if (post['id'] != null) {
      posts.add(post);
      _postsMap[post['id'].toString()] = post;
      
      // Update the post count
      userPostData['post_count'] = (userPostData['post_count'] as int? ?? 0) + 1;
    }
  }

  // Remove a post from the list (local update before database)
  void removePost(String postId) {
    if (_postsMap.containsKey(postId)) {
      posts.removeWhere((post) => post['id'].toString() == postId);
      _postsMap.remove(postId);
      
      // Update the post count
      userPostData['post_count'] = (userPostData['post_count'] as int? ?? 0) - 1;
    }
  }

  // Private methods to rebuild HashMaps from primary structures
  void _rebuildFollowersMap() {
    _followersMap.clear();
    for (final username in followersList) {
      _followersMap[username] = true;
    }
  }

  void _rebuildFollowingMap() {
    _followingMap.clear();
    for (final username in followingList) {
      _followingMap[username] = true;
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
    searches.clear();
    posts.clear();
    userPostData.value = {'post_count': 0};
    
    // Reset social data structures to defaults
    initializeDefaultStructures();
  }
  
  /// Load user posts from the posts table
  Future<void> loadUserPosts(String userId) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      
      final response = await supabaseService.client
        .from('posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
        
      if (response != null) {
        final postsList = List<Map<String, dynamic>>.from(response);
        posts.value = postsList;
        _rebuildPostsMap();
        
        // Update post count in user_posts data
        userPostData['post_count'] = postsList.length;
        
        debugPrint('Loaded ${posts.length} posts for user $userId');
      }
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      posts.value = [];
    }
  }
  
  /// Load searches from database
  Future<void> loadSearches() async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final userId = supabaseService.currentUser.value?.id;
      
      if (userId == null) return;
      
      final userData = await supabaseService.client
        .from('profiles')
        .select('searches')
        .eq('user_id', userId)
        .single();
        
      if (userData.isNotEmpty && userData['searches'] != null) {
        List<dynamic> searchesList = userData['searches'];
        searches.value = List<Map<String, dynamic>>.from(
          searchesList.map((item) => Map<String, dynamic>.from(item))
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
  Map<String, dynamic>? getUserFromSearches(String userId) => _searchesMap[userId];
  
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

import 'package:get/get.dart';

class AccountDataProvider extends GetxController {
  final RxString username = ''.obs;
  final RxString nickname = ''.obs;
  final RxString about = ''.obs;
  final RxString avatar = ''.obs;
  final RxString email = ''.obs;
  final RxString googleAvatar = ''.obs;
  
  // Primary data structures
  final RxMap<String, dynamic> followers = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> following = <String, dynamic>{}.obs;
  
  // Updated posts structure with categories
  final RxMap<String, dynamic> posts = <String, dynamic>{}.obs;
  
  // Optimized HashMaps for O(1) lookups
  final RxMap<String, bool> _followersMap = <String, bool>{}.obs;
  final RxMap<String, bool> _followingMap = <String, bool>{}.obs;
  final RxMap<String, Map<String, dynamic>> _postsMap = <String, Map<String, dynamic>>{}.obs;
  
  // Helper getters for easy access
  int get followersCount => followers['count'] as int? ?? 0;
  int get followingCount => following['count'] as int? ?? 0;
  int get postsCount {
    int total = 0;
    if (posts['threads'] != null) total += (posts['threads'] as List).length;
    if (posts['images'] != null) total += (posts['images'] as List).length;
    if (posts['gifs'] != null) total += (posts['gifs'] as List).length;
    if (posts['stickers'] != null) total += (posts['stickers'] as List).length;
    return total;
  }
  
  // Category-specific counts
  int get threadsCount => posts['threads'] != null ? (posts['threads'] as List).length : 0;
  int get imagesCount => posts['images'] != null ? (posts['images'] as List).length : 0;
  int get gifsCount => posts['gifs'] != null ? (posts['gifs'] as List).length : 0;
  int get stickersCount => posts['stickers'] != null ? (posts['stickers'] as List).length : 0;
  
  List<String> get followersList => List<String>.from(followers['users'] ?? []);
  List<String> get followingList => List<String>.from(following['users'] ?? []);
  
  // Category-specific post lists
  List<Map<String, dynamic>> get threadsList => List<Map<String, dynamic>>.from(posts['threads'] ?? []);
  List<Map<String, dynamic>> get imagesList => List<Map<String, dynamic>>.from(posts['images'] ?? []);
  List<Map<String, dynamic>> get gifsList => List<Map<String, dynamic>>.from(posts['gifs'] ?? []);
  List<Map<String, dynamic>> get stickersList => List<Map<String, dynamic>>.from(posts['stickers'] ?? []);
  
  // All posts combined
  List<Map<String, dynamic>> get allPosts {
    List<Map<String, dynamic>> allItems = [];
    allItems.addAll(threadsList);
    allItems.addAll(imagesList);
    allItems.addAll(gifsList);
    allItems.addAll(stickersList);
    return allItems;
  }
  
  // Fast lookup methods - O(1) operations
  bool isFollower(String username) => _followersMap[username] ?? false;
  bool isFollowing(String username) => _followingMap[username] ?? false;
  Map<String, dynamic>? getPost(String postId) => _postsMap[postId];
  
  // Initialize all data structures with default values
  void initializeDefaultStructures() {
    // Default followers structure
    if (followers.isEmpty || followers['users'] == null) {
      followers.value = {
        'count': 0,
        'users': <String>[],
      };
    }
    
    // Default following structure
    if (following.isEmpty || following['users'] == null) {
      following.value = {
        'count': 0,
        'users': <String>[],
      };
    }
    
    // Default posts structure with categories
    if (posts.isEmpty) {
      posts.value = {
        'threads': <Map<String, dynamic>>[],
        'images': <Map<String, dynamic>>[],
        'gifs': <Map<String, dynamic>>[],
        'stickers': <Map<String, dynamic>>[],
      };
    } else {
      // Ensure all categories exist
      if (posts['threads'] == null) {
        posts['threads'] = <Map<String, dynamic>>[];
      }
      if (posts['images'] == null) {
        posts['images'] = <Map<String, dynamic>>[];
      }
      if (posts['gifs'] == null) {
        posts['gifs'] = <Map<String, dynamic>>[];
      }
      if (posts['stickers'] == null) {
        posts['stickers'] = <Map<String, dynamic>>[];
      }
      
      // Handle migration from old format if needed
      if (posts['posts'] != null && posts['count'] != null) {
        // Migrate old format posts to new categories (default to threads)
        List<Map<String, dynamic>> oldPosts = List<Map<String, dynamic>>.from(posts['posts']);
        if (oldPosts.isNotEmpty) {
          posts['threads'] = [...posts['threads'], ...oldPosts];
        }
        
        // Remove old format keys
        posts.remove('posts');
        posts.remove('count');
      }
    }
    
    // Rebuild HashMaps from primary data structures
    _rebuildFollowersMap();
    _rebuildFollowingMap();
    _rebuildPostsMap();
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
  
  void updatePosts(Map<String, dynamic> newPosts) {
    posts.value = newPosts;
    _rebuildPostsMap();
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
  
  // Add post to a specific category
  void addPost(Map<String, dynamic> post, String category) {
    if (post['id'] != null && posts[category] != null) {
      final List<Map<String, dynamic>> categoryList = 
          List<Map<String, dynamic>>.from(posts[category] ?? []);
      categoryList.add(post);
      posts[category] = categoryList;
      _postsMap[post['id'].toString()] = post;
    }
  }
  
  // Remove post from any category
  void removePost(String postId) {
    if (_postsMap.containsKey(postId)) {
      // Find and remove from appropriate category
      for (final category in ['threads', 'images', 'gifs', 'stickers']) {
        if (posts[category] != null) {
          final List<Map<String, dynamic>> categoryList = 
              List<Map<String, dynamic>>.from(posts[category]);
          final int oldLength = categoryList.length;
          categoryList.removeWhere((post) => post['id'].toString() == postId);
          
          if (categoryList.length < oldLength) {
            // Post was found and removed from this category
            posts[category] = categoryList;
            break;
          }
        }
      }
      
      _postsMap.remove(postId);
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
    // Add all posts from all categories
    for (final category in ['threads', 'images', 'gifs', 'stickers']) {
      if (posts[category] != null) {
        for (final post in List<Map<String, dynamic>>.from(posts[category])) {
          if (post['id'] != null) {
            _postsMap[post['id'].toString()] = post;
          }
        }
      }
    }
  }
  
  @override
  void onInit() {
    super.onInit();
    // Initialize default structures
    initializeDefaultStructures();
  }
}

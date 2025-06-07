import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'dart:convert';

/// Manages persistent caching for app data to prevent rebuilds and reloads
class CacheManager extends GetxService {
  static const String _tag = 'CacheManager';

  late final StorageService _storageService;

  // Cache keys
  static const String _homeDataKey = 'cached_home_data';
  static const String _profileDataKey = 'cached_profile_data';
  static const String _chatDataKey = 'cached_chat_data';
  static const String _exploreDataKey = 'cached_explore_data';
  static const String _userPostsKey = 'cached_user_posts';
  static const String _userFollowersKey = 'cached_user_followers';
  static const String _userFollowingKey = 'cached_user_following';
  static const String _groupsDataKey = 'cached_groups_data';
  static const String _cacheTimestampKey = 'cache_timestamps';

  // Cache duration settings
  static const Duration _defaultCacheDuration = Duration(hours: 6);
  static const Duration _profileCacheDuration = Duration(hours: 12);
  static const Duration _chatCacheDuration = Duration(minutes: 30);
  static const Duration _exploreCacheDuration = Duration(hours: 2);

  // In-memory cache for faster access
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  @override
  Future<void> onInit() async {
    super.onInit();
    _storageService = Get.find<StorageService>();
    await _loadCacheTimestamps();
    debugPrint('$_tag: Initialized');
  }

  /// Load cache timestamps from storage
  Future<void> _loadCacheTimestamps() async {
    try {
      final timestampsJson = _storageService.getString(_cacheTimestampKey);
      if (timestampsJson != null) {
        final Map<String, dynamic> timestamps = jsonDecode(timestampsJson);
        timestamps.forEach((key, value) {
          _cacheTimestamps[key] = DateTime.parse(value);
        });
      }
    } catch (e) {
      debugPrint('$_tag: Error loading cache timestamps: $e');
    }
  }

  /// Save cache timestamps to storage
  Future<void> _saveCacheTimestamps() async {
    try {
      final Map<String, String> timestamps = {};
      _cacheTimestamps.forEach((key, value) {
        timestamps[key] = value.toIso8601String();
      });
      await _storageService.saveString(
        _cacheTimestampKey,
        jsonEncode(timestamps),
      );
    } catch (e) {
      debugPrint('$_tag: Error saving cache timestamps: $e');
    }
  }

  /// Check if cached data is still valid
  bool _isCacheValid(String key, Duration cacheDuration) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    final now = DateTime.now();
    return now.difference(timestamp) < cacheDuration;
  }

  /// Cache home page data
  Future<void> cacheHomeData(Map<String, dynamic> data) async {
    try {
      _memoryCache[_homeDataKey] = data;
      _cacheTimestamps[_homeDataKey] = DateTime.now();

      await _storageService.saveString(_homeDataKey, jsonEncode(data));
      await _saveCacheTimestamps();

      debugPrint('$_tag: Home data cached');
    } catch (e) {
      debugPrint('$_tag: Error caching home data: $e');
    }
  }

  /// Get cached home data
  Future<Map<String, dynamic>?> getCachedHomeData() async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(_homeDataKey) &&
          _isCacheValid(_homeDataKey, _defaultCacheDuration)) {
        debugPrint('$_tag: Returning home data from memory cache');
        return _memoryCache[_homeDataKey];
      }

      // Check persistent cache
      if (_isCacheValid(_homeDataKey, _defaultCacheDuration)) {
        final cachedJson = _storageService.getString(_homeDataKey);
        if (cachedJson != null) {
          final data = jsonDecode(cachedJson);
          _memoryCache[_homeDataKey] =
              data; // Store in memory for faster access
          debugPrint('$_tag: Returning home data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached home data: $e');
    }
    return null;
  }

  /// Cache profile data
  Future<void> cacheProfileData(Map<String, dynamic> data) async {
    try {
      _memoryCache[_profileDataKey] = data;
      _cacheTimestamps[_profileDataKey] = DateTime.now();

      await _storageService.saveString(_profileDataKey, jsonEncode(data));
      await _saveCacheTimestamps();

      debugPrint('$_tag: Profile data cached');
    } catch (e) {
      debugPrint('$_tag: Error caching profile data: $e');
    }
  }

  /// Get cached profile data
  Future<Map<String, dynamic>?> getCachedProfileData() async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(_profileDataKey) &&
          _isCacheValid(_profileDataKey, _profileCacheDuration)) {
        debugPrint('$_tag: Returning profile data from memory cache');
        return _memoryCache[_profileDataKey];
      }

      // Check persistent cache
      if (_isCacheValid(_profileDataKey, _profileCacheDuration)) {
        final cachedJson = _storageService.getString(_profileDataKey);
        if (cachedJson != null) {
          final data = jsonDecode(cachedJson);
          _memoryCache[_profileDataKey] = data;
          debugPrint('$_tag: Returning profile data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached profile data: $e');
    }
    return null;
  }

  /// Cache chat data
  Future<void> cacheChatData(Map<String, dynamic> data) async {
    try {
      _memoryCache[_chatDataKey] = data;
      _cacheTimestamps[_chatDataKey] = DateTime.now();

      await _storageService.saveString(_chatDataKey, jsonEncode(data));
      await _saveCacheTimestamps();

      debugPrint('$_tag: Chat data cached');
    } catch (e) {
      debugPrint('$_tag: Error caching chat data: $e');
    }
  }

  /// Get cached chat data
  Future<Map<String, dynamic>?> getCachedChatData() async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(_chatDataKey) &&
          _isCacheValid(_chatDataKey, _chatCacheDuration)) {
        debugPrint('$_tag: Returning chat data from memory cache');
        return _memoryCache[_chatDataKey];
      }

      // Check persistent cache
      if (_isCacheValid(_chatDataKey, _chatCacheDuration)) {
        final cachedJson = _storageService.getString(_chatDataKey);
        if (cachedJson != null) {
          final data = jsonDecode(cachedJson);
          _memoryCache[_chatDataKey] = data;
          debugPrint('$_tag: Returning chat data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached chat data: $e');
    }
    return null;
  }

  /// Cache explore data
  Future<void> cacheExploreData(Map<String, dynamic> data) async {
    try {
      _memoryCache[_exploreDataKey] = data;
      _cacheTimestamps[_exploreDataKey] = DateTime.now();

      await _storageService.saveString(_exploreDataKey, jsonEncode(data));
      await _saveCacheTimestamps();

      debugPrint('$_tag: Explore data cached');
    } catch (e) {
      debugPrint('$_tag: Error caching explore data: $e');
    }
  }

  /// Get cached explore data
  Future<Map<String, dynamic>?> getCachedExploreData() async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(_exploreDataKey) &&
          _isCacheValid(_exploreDataKey, _exploreCacheDuration)) {
        debugPrint('$_tag: Returning explore data from memory cache');
        return _memoryCache[_exploreDataKey];
      }

      // Check persistent cache
      if (_isCacheValid(_exploreDataKey, _exploreCacheDuration)) {
        final cachedJson = _storageService.getString(_exploreDataKey);
        if (cachedJson != null) {
          final data = jsonDecode(cachedJson);
          _memoryCache[_exploreDataKey] = data;
          debugPrint('$_tag: Returning explore data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached explore data: $e');
    }
    return null;
  }

  /// Clear specific cache
  Future<void> clearCache(String cacheKey) async {
    try {
      _memoryCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      await _storageService.remove(cacheKey);
      await _saveCacheTimestamps();
      debugPrint('$_tag: Cleared cache for $cacheKey');
    } catch (e) {
      debugPrint('$_tag: Error clearing cache for $cacheKey: $e');
    }
  }

  /// Cache user posts data
  Future<void> cacheUserPosts(
    String userId,
    List<Map<String, dynamic>> posts,
  ) async {
    try {
      final key = '${_userPostsKey}_$userId';
      _memoryCache[key] = posts;
      _cacheTimestamps[key] = DateTime.now();

      await _storageService.saveString(key, jsonEncode(posts));
      await _saveCacheTimestamps();

      debugPrint(
        '$_tag: User posts cached for $userId (${posts.length} posts)',
      );
    } catch (e) {
      debugPrint('$_tag: Error caching user posts: $e');
    }
  }

  /// Get cached user posts
  Future<List<Map<String, dynamic>>?> getCachedUserPosts(String userId) async {
    try {
      final key = '${_userPostsKey}_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(key) &&
          _isCacheValid(key, _defaultCacheDuration)) {
        debugPrint('$_tag: Returning user posts from memory cache');
        return List<Map<String, dynamic>>.from(_memoryCache[key]);
      }

      // Check persistent cache
      if (_isCacheValid(key, _defaultCacheDuration)) {
        final cachedJson = _storageService.getString(key);
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          final data = <Map<String, dynamic>>[];
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                data.add(item);
              } else if (item is Map) {
                final safeMap = <String, dynamic>{};
                item.forEach((key, value) {
                  safeMap[key.toString()] = value;
                });
                data.add(safeMap);
              }
            }
          }
          _memoryCache[key] = data;
          debugPrint('$_tag: Returning user posts from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached user posts: $e');
    }
    return null;
  }

  /// Cache user followers data
  Future<void> cacheUserFollowers(
    String userId,
    List<Map<String, dynamic>> followers,
  ) async {
    try {
      final key = '${_userFollowersKey}_$userId';
      _memoryCache[key] = followers;
      _cacheTimestamps[key] = DateTime.now();

      await _storageService.saveString(key, jsonEncode(followers));
      await _saveCacheTimestamps();

      debugPrint(
        '$_tag: User followers cached for $userId (${followers.length} followers)',
      );
    } catch (e) {
      debugPrint('$_tag: Error caching user followers: $e');
    }
  }

  /// Get cached user followers
  Future<List<Map<String, dynamic>>?> getCachedUserFollowers(
    String userId,
  ) async {
    try {
      final key = '${_userFollowersKey}_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(key) &&
          _isCacheValid(key, _defaultCacheDuration)) {
        debugPrint('$_tag: Returning user followers from memory cache');
        return List<Map<String, dynamic>>.from(_memoryCache[key]);
      }

      // Check persistent cache
      if (_isCacheValid(key, _defaultCacheDuration)) {
        final cachedJson = _storageService.getString(key);
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          final data = <Map<String, dynamic>>[];
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                data.add(item);
              } else if (item is Map) {
                final safeMap = <String, dynamic>{};
                item.forEach((key, value) {
                  safeMap[key.toString()] = value;
                });
                data.add(safeMap);
              }
            }
          }
          _memoryCache[key] = data;
          debugPrint('$_tag: Returning user followers from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached user followers: $e');
    }
    return null;
  }

  /// Cache user following data
  Future<void> cacheUserFollowing(
    String userId,
    List<Map<String, dynamic>> following,
  ) async {
    try {
      final key = '${_userFollowingKey}_$userId';
      _memoryCache[key] = following;
      _cacheTimestamps[key] = DateTime.now();

      await _storageService.saveString(key, jsonEncode(following));
      await _saveCacheTimestamps();

      debugPrint(
        '$_tag: User following cached for $userId (${following.length} following)',
      );
    } catch (e) {
      debugPrint('$_tag: Error caching user following: $e');
    }
  }

  /// Get cached user following
  Future<List<Map<String, dynamic>>?> getCachedUserFollowing(
    String userId,
  ) async {
    try {
      final key = '${_userFollowingKey}_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(key) &&
          _isCacheValid(key, _defaultCacheDuration)) {
        debugPrint('$_tag: Returning user following from memory cache');
        return List<Map<String, dynamic>>.from(_memoryCache[key]);
      }

      // Check persistent cache
      if (_isCacheValid(key, _defaultCacheDuration)) {
        final cachedJson = _storageService.getString(key);
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          final data = <Map<String, dynamic>>[];
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                data.add(item);
              } else if (item is Map) {
                final safeMap = <String, dynamic>{};
                item.forEach((key, value) {
                  safeMap[key.toString()] = value;
                });
                data.add(safeMap);
              }
            }
          }
          _memoryCache[key] = data;
          debugPrint('$_tag: Returning user following from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached user following: $e');
    }
    return null;
  }

  /// Cache groups data
  Future<void> cacheGroupsData(
    String userId,
    List<Map<String, dynamic>> groups,
  ) async {
    try {
      final key = '${_groupsDataKey}_$userId';
      _memoryCache[key] = groups;
      _cacheTimestamps[key] = DateTime.now();

      await _storageService.saveString(key, jsonEncode(groups));
      await _saveCacheTimestamps();

      debugPrint(
        '$_tag: Groups data cached for $userId (${groups.length} groups)',
      );
    } catch (e) {
      debugPrint('$_tag: Error caching groups data: $e');
    }
  }

  /// Get cached groups data
  Future<List<Map<String, dynamic>>?> getCachedGroupsData(String userId) async {
    try {
      final key = '${_groupsDataKey}_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(key) &&
          _isCacheValid(key, _chatCacheDuration)) {
        debugPrint('$_tag: Returning groups data from memory cache');
        return List<Map<String, dynamic>>.from(_memoryCache[key]);
      }

      // Check persistent cache
      if (_isCacheValid(key, _chatCacheDuration)) {
        final cachedJson = _storageService.getString(key);
        if (cachedJson != null) {
          final decoded = jsonDecode(cachedJson);
          final data = <Map<String, dynamic>>[];
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                data.add(item);
              } else if (item is Map) {
                final safeMap = <String, dynamic>{};
                item.forEach((key, value) {
                  safeMap[key.toString()] = value;
                });
                data.add(safeMap);
              }
            }
          }
          _memoryCache[key] = data;
          debugPrint('$_tag: Returning groups data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting cached groups data: $e');
    }
    return null;
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      _memoryCache.clear();
      _cacheTimestamps.clear();

      await _storageService.remove(_homeDataKey);
      await _storageService.remove(_profileDataKey);
      await _storageService.remove(_chatDataKey);
      await _storageService.remove(_exploreDataKey);
      await _storageService.remove(_cacheTimestampKey);

      // Clear user-specific caches (we'll need to clear all variations)
      // For now, we'll clear based on known patterns
      final commonUserIds = ['current']; // Add more if needed
      for (final userId in commonUserIds) {
        await _storageService.remove('${_userPostsKey}_$userId');
        await _storageService.remove('${_userFollowersKey}_$userId');
        await _storageService.remove('${_userFollowingKey}_$userId');
        await _storageService.remove('${_groupsDataKey}_$userId');
      }

      debugPrint('$_tag: All caches cleared');
    } catch (e) {
      debugPrint('$_tag: Error clearing all caches: $e');
    }
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    final now = DateTime.now();
    return {
      'homeCache': {
        'exists':
            _memoryCache.containsKey(_homeDataKey) ||
            _cacheTimestamps.containsKey(_homeDataKey),
        'valid': _isCacheValid(_homeDataKey, _defaultCacheDuration),
        'age':
            _cacheTimestamps[_homeDataKey] != null
                ? now.difference(_cacheTimestamps[_homeDataKey]!).inMinutes
                : null,
      },
      'profileCache': {
        'exists':
            _memoryCache.containsKey(_profileDataKey) ||
            _cacheTimestamps.containsKey(_profileDataKey),
        'valid': _isCacheValid(_profileDataKey, _profileCacheDuration),
        'age':
            _cacheTimestamps[_profileDataKey] != null
                ? now.difference(_cacheTimestamps[_profileDataKey]!).inMinutes
                : null,
      },
      'chatCache': {
        'exists':
            _memoryCache.containsKey(_chatDataKey) ||
            _cacheTimestamps.containsKey(_chatDataKey),
        'valid': _isCacheValid(_chatDataKey, _chatCacheDuration),
        'age':
            _cacheTimestamps[_chatDataKey] != null
                ? now.difference(_cacheTimestamps[_chatDataKey]!).inMinutes
                : null,
      },
      'exploreCache': {
        'exists':
            _memoryCache.containsKey(_exploreDataKey) ||
            _cacheTimestamps.containsKey(_exploreDataKey),
        'valid': _isCacheValid(_exploreDataKey, _exploreCacheDuration),
        'age':
            _cacheTimestamps[_exploreDataKey] != null
                ? now.difference(_cacheTimestamps[_exploreDataKey]!).inMinutes
                : null,
      },
    };
  }
}

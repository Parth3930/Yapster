import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../values/constants.dart';
import 'storage_service.dart';

class DbCacheService extends GetxService {
  static DbCacheService get to => Get.find<DbCacheService>();
  final StorageService _storage = Get.find<StorageService>();
  
  // Cache configuration
  final RxBool isCachingEnabled = true.obs;
  final RxBool isOfflineModeEnabled = false.obs;
  final Map<String, dynamic> _memoryCache = {};
  
  // Cache statistics for monitoring
  final RxInt cacheHits = 0.obs;
  final RxInt cacheMisses = 0.obs;
  final RxInt bytesDownloaded = 0.obs;
  final RxInt bytesSaved = 0.obs;
  
  // Cache expiration times (in minutes)
  final Map<String, int> _expirationTimes = {
    'user_profile': 60,      // Profile data expires in 60 minutes
    'user_posts': 15,        // Posts expire in 15 minutes
    'followers': 30,         // Followers expire in 30 minutes
    'following': 30,         // Following expire in 30 minutes
    'explore_feed': 5,       // Explore feed expires in 5 minutes
    'home_feed': 2,          // Home feed expires in 2 minutes
    'post_comments': 5,      // Comments expire in 5 minutes
    'user_search': 60,       // User search results expire in 60 minutes
  };
  
  // Key prefixes for different data types
  // ignore: constant_identifier_names
  static const String _PROFILE_PREFIX = 'profile_';
  // ignore: constant_identifier_names
  static const String _POSTS_PREFIX = 'posts_';
  // ignore: constant_identifier_names
  static const String _FOLLOWERS_PREFIX = 'followers_';
  // ignore: constant_identifier_names
  static const String _FOLLOWING_PREFIX = 'following_';
  // ignore: constant_identifier_names
  static const String _FEED_PREFIX = 'feed_';
  // ignore: constant_identifier_names
  static const String _COMMENTS_PREFIX = 'comments_';
  // ignore: constant_identifier_names
  static const String _SEARCH_PREFIX = 'search_';
  
  // Initialize service
  Future<DbCacheService> init() async {
    debugPrint('Initializing DbCacheService');
    
    // Load cache settings from storage
    isCachingEnabled.value = _storage.getBool(AppConstants.cachingEnabledKey) ?? true;
    isOfflineModeEnabled.value = _storage.getBool(AppConstants.offlineModeKey) ?? false;
    
    // Load any configuration from storage
    _loadCacheSettings();
    
    // Clear expired cache entries
    await _clearExpiredCache();
    
    debugPrint('DbCacheService initialized: caching=${isCachingEnabled.value}, offline=${isOfflineModeEnabled.value}');
    return this;
  }
  
  // Load cache settings from storage
  void _loadCacheSettings() {
    try {
      // Load expiration times if they exist in storage
      final storedExpirationTimes = _storage.getObject(AppConstants.cacheExpirationTimesKey);
      if (storedExpirationTimes != null) {
        for (final entry in storedExpirationTimes.entries) {
          _expirationTimes[entry.key] = entry.value;
        }
      }
    } catch (e) {
      debugPrint('Error loading cache settings: $e');
    }
  }
  
  // Save cache settings to storage
  Future<void> saveCacheSettings() async {
    try {
      await _storage.saveBool(AppConstants.cachingEnabledKey, isCachingEnabled.value);
      await _storage.saveBool(AppConstants.offlineModeKey, isOfflineModeEnabled.value);
      await _storage.saveObject(AppConstants.cacheExpirationTimesKey, _expirationTimes);
    } catch (e) {
      debugPrint('Error saving cache settings: $e');
    }
  }
  
  // Update cache expiration time for a specific data type
  void setExpirationTime(String dataType, int minutes) {
    _expirationTimes[dataType] = minutes;
    saveCacheSettings();
  }
  
  // Enable or disable caching
  void setCachingEnabled(bool enabled) {
    isCachingEnabled.value = enabled;
    saveCacheSettings();
  }
  
  // Enable or disable offline mode
  void setOfflineModeEnabled(bool enabled) {
    isOfflineModeEnabled.value = enabled;
    saveCacheSettings();
  }
  
  // Clear all cache data
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    
    // Clear disk cache too
    try {
      final cacheDir = await _getCacheDirectory();
      final dir = Directory(cacheDir.path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
      
      // Reset statistics
      cacheHits.value = 0;
      cacheMisses.value = 0;
      bytesDownloaded.value = 0;
      bytesSaved.value = 0;
      
      debugPrint('Cleared all cache data');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
  
  // Clear expired cache entries
  Future<void> _clearExpiredCache() async {
    if (!isCachingEnabled.value) return;
    
    try {
      final cacheDir = await _getCacheDirectory();
      final dir = Directory(cacheDir.path);
      if (!await dir.exists()) return;
      
      await for (final file in dir.list()) {
        if (file is File) {
          try {
            // Read the metadata at the start of the file
            final content = await file.readAsString();
            final metaEnd = content.indexOf('||DATA||');
            
            if (metaEnd != -1) {
              final metaJson = content.substring(0, metaEnd);
              final meta = json.decode(metaJson);
              final expiresAt = DateTime.parse(meta['expiresAt']);
              
              if (DateTime.now().isAfter(expiresAt)) {
                await file.delete();
                debugPrint('Deleted expired cache file: ${file.path}');
              }
            }
          } catch (e) {
            debugPrint('Error processing cache file: ${file.path}, error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing expired cache: $e');
    }
  }
  
  // Get or fetch user profile data
  Future<Map<String, dynamic>?> getUserProfile(
    String userId, 
    Future<Map<String, dynamic>?> Function() fetchFn,
  ) async {
    final result = await _getOrFetch('$_PROFILE_PREFIX$userId', 'user_profile', fetchFn);
    
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }
  
  // Get or fetch user posts
  Future<List<Map<String, dynamic>>> getUserPosts(
    String userId,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) async {
    final result = await _getOrFetch('$_POSTS_PREFIX$userId', 'user_posts', fetchFn);
    
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }
  
  // Get or fetch user followers
  Future<List<Map<String, dynamic>>> getFollowers(
    String userId,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) async {
    final result = await _getOrFetch('$_FOLLOWERS_PREFIX$userId', 'followers', fetchFn);
    
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }
  
  // Get or fetch user following
  Future<List<Map<String, dynamic>>> getFollowing(
    String userId,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) async {
    final result = await _getOrFetch('$_FOLLOWING_PREFIX$userId', 'following', fetchFn);
    
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }
  
  // Get or fetch feed data
  Future<List<Map<String, dynamic>>> getFeed(
    String feedType,
    Map<String, dynamic>? params,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) async {
    final paramHash = params != null ? _hashMap(params) : '';
    final key = '$_FEED_PREFIX${feedType}_$paramHash';
    
    final result = await _getOrFetch(key, '${feedType}_feed', fetchFn);
    
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }
  
  // Get or fetch comments for a post
  Future<List<Map<String, dynamic>>> getComments(
    String postId,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) async {
    final result = await _getOrFetch('$_COMMENTS_PREFIX$postId', 'post_comments', fetchFn);
    
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }
  
  // Get or fetch search results
  Future<List<Map<String, dynamic>>> getSearchResults(
    String query,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) async {
    // Use a sanitized query as part of the cache key
    final sanitizedQuery = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final result = await _getOrFetch('$_SEARCH_PREFIX$sanitizedQuery', 'user_search', fetchFn);
    
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }
  
  // Generic method to get from cache or fetch from network
  Future<dynamic> _getOrFetch(String key, String dataType, Future<dynamic> Function() fetchFn) async {
    if (!isCachingEnabled.value && !isOfflineModeEnabled.value) {
      return await fetchFn();
    }
    
    // First, check memory cache
    if (_memoryCache.containsKey(key)) {
      final cachedItem = _memoryCache[key];
      final DateTime expiresAt = cachedItem['expiresAt'];
      
      // If not expired, return from memory cache
      if (DateTime.now().isBefore(expiresAt)) {
        cacheHits.value++;
        return cachedItem['data'];
      }
    }
    
    // Then, check disk cache
    final cachedData = await _readFromDiskCache(key);
    if (cachedData != null) {
      // Put into memory cache for faster access next time
      _memoryCache[key] = {
        'data': cachedData,
        'expiresAt': _calculateExpiryTime(dataType),
      };
      
      cacheHits.value++;
      bytesSaved.value += _estimateSize(cachedData);
      return cachedData;
    }
    
    // If in offline mode and no cached data, return null or empty list
    if (isOfflineModeEnabled.value) {
      debugPrint('Offline mode: No cached data for $key');
      return dataType.contains('feed') || dataType.contains('list') ? [] : null;
    }
    
    // Fetch fresh data
    try {
      cacheMisses.value++;
      final data = await fetchFn();
      
      // Calculate approximate size
      final dataSize = _estimateSize(data);
      bytesDownloaded.value += dataSize;
      
      // Cache the fetched data both in memory and disk
      if (data != null) {
        _memoryCache[key] = {
          'data': data,
          'expiresAt': _calculateExpiryTime(dataType),
        };
        
        // Write to disk cache
        await _writeToDiskCache(key, data, dataType);
      }
      
      return data;
    } catch (e) {
      debugPrint('Error fetching data for $key: $e');
      // In case of error, try to return cached data even if expired
      final expiredData = await _readFromDiskCache(key, ignoreExpiry: true);
      if (expiredData != null) {
        debugPrint('Returning expired data for $key due to fetch error');
        return expiredData;
      }
      rethrow;
    }
  }
  
  // Calculate expiry time based on data type
  DateTime _calculateExpiryTime(String dataType) {
    final minutes = _expirationTimes[dataType] ?? 15; // Default to 15 minutes
    return DateTime.now().add(Duration(minutes: minutes));
  }
  
  // Read data from disk cache
  Future<dynamic> _readFromDiskCache(String key, {bool ignoreExpiry = false}) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$key.cache');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final metaEnd = content.indexOf('||DATA||');
      
      if (metaEnd == -1) return null;
      
      final metaJson = content.substring(0, metaEnd);
      final dataJson = content.substring(metaEnd + 8); // 8 is the length of ||DATA||
      
      final meta = json.decode(metaJson);
      final expiresAt = DateTime.parse(meta['expiresAt']);
      
      // Check if data is expired, unless we're ignoring expiry
      if (!ignoreExpiry && DateTime.now().isAfter(expiresAt)) {
        return null;
      }
      
      return json.decode(dataJson);
    } catch (e) {
      debugPrint('Error reading from disk cache: $e');
      return null;
    }
  }
  
  // Write data to disk cache
  Future<void> _writeToDiskCache(String key, dynamic data, String dataType) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$key.cache');
      
      // Ensure directory exists
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      // Create metadata
      final meta = {
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': _calculateExpiryTime(dataType).toIso8601String(),
        'dataType': dataType,
        'key': key,
      };
      
      // Combine metadata and data
      final content = '${json.encode(meta)}||DATA||${json.encode(data)}';
      
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Error writing to disk cache: $e');
    }
  }
  
  // Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/yapster_cache');
  }
  
  // Calculate estimated size of data in bytes
  int _estimateSize(dynamic data) {
    if (data == null) return 0;
    final jsonString = json.encode(data);
    return jsonString.length;
  }
  
  // Create a hash of a map for use in cache keys
  String _hashMap(Map<String, dynamic> map) {
    return map.entries
        .map((e) => '${e.key}:${e.value}')
        .join('_')
        .replaceAll(RegExp(r'[^\w]'), '_');
  }
  
  // Reset cache statistics
  void resetStats() {
    cacheHits.value = 0;
    cacheMisses.value = 0;
    bytesDownloaded.value = 0;
    bytesSaved.value = 0;
  }
  
  // Get cache statistics as a map
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheHits': cacheHits.value,
      'cacheMisses': cacheMisses.value,
      'hitRatio': cacheHits.value + cacheMisses.value > 0 
          ? cacheHits.value / (cacheHits.value + cacheMisses.value) 
          : 0.0,
      'bytesDownloaded': bytesDownloaded.value,
      'bytesSaved': bytesSaved.value,
      'bandwidthSavings': bytesDownloaded.value > 0 
          ? bytesSaved.value / (bytesDownloaded.value + bytesSaved.value) * 100 
          : 0.0,
      'cacheSize': _memoryCache.length,
    };
  }
} 
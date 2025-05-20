import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'dart:async';

/// Service for handling search functionality in chats
class ChatSearchService extends GetxService {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final StorageService _storageService = Get.find<StorageService>();

  // User search
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;
  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _searchDebounce?.cancel();
    super.onClose();
  }

  /// Handle search input changes with debounce
  void _onSearchChanged() {
    searchQuery.value = searchController.text;

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (searchQuery.isNotEmpty) {
        searchUsers(searchQuery.value);
      } else {
        searchResults.clear();
      }
    });
  }

  /// Search users by username or nickname
  Future<void> searchUsers(String query) async {
    if (query.isEmpty) return;

    isSearching.value = true;

    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) return;

      // Check if we have this search result cached
      final cacheKey = 'search_${query.toLowerCase()}';
      final cachedSearchResults = _getCachedSearchResults(cacheKey);

      if (cachedSearchResults != null) {
        searchResults.value = cachedSearchResults;
        isSearching.value = false;
        return;
      }

      // Combined search results list
      List<Map<String, dynamic>> results = [];

      // Parallel search for better performance
      final futures = <Future>[];

      // 1. Search all users in database
      final userSearchFuture = _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar, google_avatar')
          .ilike('username', '%$query%')
          .neq('user_id', currentUserId)
          .limit(10)
          .then((usersResponse) {
            if (usersResponse.isNotEmpty) {
              results.addAll(List<Map<String, dynamic>>.from(usersResponse));
            }
          });

      futures.add(userSearchFuture);

      // Process local data in memory for faster results
      // 2. Search in following users
      if (_accountDataProvider.following.isNotEmpty) {
        final followingResults =
            _accountDataProvider.following.where((user) {
              final username =
                  (user['username'] ?? '').toString().toLowerCase();
              final nickname =
                  (user['nickname'] ?? '').toString().toLowerCase();
              final userId = user['following_id'];
              return userId != currentUserId &&
                  (username.contains(query.toLowerCase()) ||
                      nickname.contains(query.toLowerCase()));
            }).toList();

        // Add a type identifier for display purposes
        for (var user in followingResults) {
          user['source'] = 'following';
        }

        results.addAll(followingResults);
      }

      // 3. Search in followers
      if (_accountDataProvider.followers.isNotEmpty) {
        final followerResults =
            _accountDataProvider.followers.where((user) {
              final username =
                  (user['username'] ?? '').toString().toLowerCase();
              final nickname =
                  (user['nickname'] ?? '').toString().toLowerCase();
              final userId = user['follower_id'];
              return userId != currentUserId &&
                  (username.contains(query.toLowerCase()) ||
                      nickname.contains(query.toLowerCase()));
            }).toList();

        // Add a type identifier for display purposes
        for (var user in followerResults) {
          user['source'] = 'follower';
        }

        results.addAll(followerResults);
      }

      // Wait for all search operations to complete
      await Future.wait(futures);

      // Remove duplicates (prefer following/follower entries over regular ones)
      final Map<String, Map<String, dynamic>> uniqueResults = {};

      for (var user in results) {
        final userId =
            user['user_id'] ?? user['follower_id'] ?? user['following_id'];
        if (userId != null) {
          if (!uniqueResults.containsKey(userId) || user['source'] != null) {
            uniqueResults[userId] = user;
          }
        }
      }

      final finalResults = uniqueResults.values.toList();

      // Cache the results for future use
      _cacheSearchResults(cacheKey, finalResults);

      searchResults.value = finalResults;
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      isSearching.value = false;
    }
  }

  /// Cache search results in memory
  void _cacheSearchResults(
    String cacheKey,
    List<Map<String, dynamic>> results,
  ) {
    // Use a simple in-memory cache with a 5 minute TTL
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'results': results,
    };
    _storageService.saveObject(cacheKey, cacheData);
  }

  /// Get cached search results
  List<Map<String, dynamic>>? _getCachedSearchResults(String cacheKey) {
    try {
      final cacheData = _storageService.getObject(cacheKey);

      if (cacheData != null) {
        final timestamp = DateTime.parse(cacheData['timestamp']);
        final now = DateTime.now();

        // Check if cache is still valid (5 minutes)
        if (now.difference(timestamp).inMinutes < 5) {
          return List<Map<String, dynamic>>.from(cacheData['results']);
        }
      }
    } catch (e) {
      debugPrint('Error retrieving cached search results: $e');
    }

    return null;
  }

  /// Clear search and results
  void clearSearch() {
    searchController.clear();
    searchResults.clear();
    searchQuery.value = '';
  }
}

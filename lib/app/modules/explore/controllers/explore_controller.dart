import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:async';
import 'dart:convert';

class ExploreController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider = Get.find<AccountDataProvider>();
  final StorageService _storageService = Get.find<StorageService>();
  
  final searchController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recentSearches = <Map<String, dynamic>>[].obs;
  
  // Observable search text to properly work with Obx
  final RxString searchText = ''.obs;
  
  // The maximum number of recent searches to store
  static const int maxRecentSearches = 5;
  
  // Cache keys
  static const String searchCacheKey = 'last_search_results';
  
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
      final response = await _supabaseService.client
          .from('profiles')
          .select('user_id, username, nickname, avatar')
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
  Future<void> cacheSearchResults(String query, List<Map<String, dynamic>> results) async {
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
        final results = decodedResults
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        
        // Update search results only if no active search is happening
        if (searchController.text.isEmpty) {
          searchResults.value = results;
          debugPrint('Loaded ${results.length} cached search results');
          
          // Debug info about the results
          for (var result in results) {
            debugPrint('Cached result: ${result['username']}, ${result['user_id']}');
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
        recentSearches.value = List<Map<String, dynamic>>.from(_accountDataProvider.searches);
        debugPrint('Loaded ${recentSearches.length} recent searches from database');
        
        // Debug info about recent searches
        for (var search in recentSearches) {
          debugPrint('Recent search: ${search['username']}, ${search['user_id']}');
        }
      });
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }
  
  Future<void> addToRecentSearches(Map<String, dynamic> user) async {
    try {
      // Check if user is already in recent searches
      final existingIndex = recentSearches.indexWhere(
        (item) => item['user_id'] == user['user_id']
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
        (item) => item['user_id'] == user['user_id']
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
    
    // Navigate to user profile (assuming you have a route for that)
    Get.toNamed('/profile/${user['user_id']}');
  }
}
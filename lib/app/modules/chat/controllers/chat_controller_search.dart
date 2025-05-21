import 'dart:async'; // For Timer
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';

mixin ChatControllerSearch {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  Timer? _debounce;

  void handleSearchInputChanged() {
    final controller = Get.find<ChatController>();
    final input = controller.searchController.text.trim();

    // Cancel previous debounce
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      controller.searchQuery.value = input;

      if (input.isNotEmpty) {
        searchUsers(input);
      } else {
        controller.searchResults.clear();
      }
    });
  }

  Future<void> searchUsers(String query) async {
    final controller = Get.find<ChatController>();
    final userId = _supabaseService.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint("User not logged in");
      return;
    }

    try {
      // The RPC call returns the data directly (a List)
      final results = await _supabaseService.client.rpc(
        'search_following_users',
        params: {'user_uuid': userId, 'search_query': query},
      );

      if (results is List) {
        controller.searchResults.assignAll(
          results.cast<Map<String, dynamic>>(),
        );
      } else {
        controller.searchResults.clear();
        debugPrint('Search returned no results or invalid data');
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }
}

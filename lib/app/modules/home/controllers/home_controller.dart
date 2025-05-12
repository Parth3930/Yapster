import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class HomeController extends GetxController {
  final supabaseService = Get.find<SupabaseService>();
  final RxString username = ''.obs;
  static const String _usernameKey = 'cached_username';
  late SharedPreferences _prefs;

  // Lifecycle methods
  @override
  void onInit() async {
    super.onInit();
    _prefs = await SharedPreferences.getInstance();
    _loadCachedUsername();
    
    // Check if user is authenticated
    if (!supabaseService.isAuthenticated.value) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.LOGIN);
      });
    } else {
      // Check if authenticated user has a username and redirect if not
      final hasUsername = await supabaseService.checkUserHasUsername();
      if (!hasUsername) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.ACCOUNT_SETUP);
        });
      } else {
        // Only fetch and cache username if user has one
        if (username.value.isEmpty) {
          try {
            final response = await supabaseService.client
                .from('profiles')
                .select('username')
                .eq('user_id', supabaseService.currentUser.value!.id)
                .single();
            
            if (response['username'] != null) {
              await _cacheUsername(response['username']);
            }
          } catch (e) {
            debugPrint('Error fetching username: $e');
          }
        }
      }
    }

    // Listen for authentication state changes
    ever(supabaseService.isAuthenticated, (isAuthenticated) {
      if (!isAuthenticated) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed(Routes.LOGIN);
        });
      } else {
        // Check if authenticated user has a username
        _checkUserHasUsername();
      }
    });
  }

  // Load cached username
  void _loadCachedUsername() {
    final cachedUsername = _prefs.getString(_usernameKey);
    if (cachedUsername != null) {
      username.value = cachedUsername;
    }
  }

  // Cache username
  Future<void> _cacheUsername(String newUsername) async {
    await _prefs.setString(_usernameKey, newUsername);
    username.value = newUsername;
  }

  // Check if user has a username and redirect if not
  Future<void> _checkUserHasUsername() async {
    final hasUsername = await supabaseService.checkUserHasUsername();
    if (!hasUsername) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.ACCOUNT_SETUP);
      });
    } else {
      // If we don't have a cached username, fetch it from the profiles table
      if (username.value.isEmpty) {
        try {
          final response = await supabaseService.client
              .from('profiles')
              .select('username')
              .eq('user_id', supabaseService.currentUser.value!.id)
              .single();
          
          if (response['username'] != null) {
            await _cacheUsername(response['username']);
          }
        } catch (e) {
          debugPrint('Error fetching username: $e');
        }
      }
    }
  }
}

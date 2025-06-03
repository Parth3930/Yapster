import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

/// Utility class for handling banner-related operations
class BannerUtils {
  /// Picks a banner image from the gallery and returns the selected image file
  static Future<XFile?> pickBannerFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 1000,
      );

      if (image == null) {
        debugPrint('No image selected');
        Get.snackbar(
          'Error',
          'No image selected',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        debugPrint('Banner selected: ${image.path}');
      }

      return image;
    } catch (e) {
      debugPrint('Error picking banner: $e');
      Get.snackbar(
        'Error',
        'Failed to pick banner image',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  static final Map<String, String> _bannerCache = <String, String>{};
  static final Map<String, DateTime> _bannerFetchTime = <String, DateTime>{};
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Gets the local cache directory for storing banner images
  static Future<String> _getBannerCachePath(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/banner_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return '${cacheDir.path}/banner_$userId.jpg';
  }

  /// Gets the banner URL with caching support
  static Future<String> getBannerUrl(String userId, {String? customBanner}) async {
    if (customBanner != null && customBanner.isNotEmpty) {
      return customBanner;
    }
    
    final accountDataProvider = Get.find<AccountDataProvider>();
    final bannerUrl = accountDataProvider.banner.value;
    
    if (bannerUrl.isEmpty) return '';
    
    // Check memory cache first
    if (_bannerCache.containsKey(userId)) {
      final lastFetch = _bannerFetchTime[userId];
      if (lastFetch != null && 
          DateTime.now().difference(lastFetch) < _cacheDuration) {
        debugPrint('Returning banner from memory cache');
        return _bannerCache[userId]!;
      }
    }
    
    // Check file cache
    try {
      final cachedPath = await _getBannerCachePath(userId);
      final file = File(cachedPath);
      
      if (await file.exists()) {
        final lastModified = await file.lastModified();
        if (DateTime.now().difference(lastModified) < _cacheDuration) {
          final cachedUrl = file.uri.toString();
          _bannerCache[userId] = cachedUrl;
          _bannerFetchTime[userId] = DateTime.now();
          debugPrint('Returning banner from file cache: $cachedUrl');
          return cachedUrl;
        }
      }
      
      // If not in cache or cache expired, download and cache
      debugPrint('Downloading banner for user: $userId');
      final response = await Supabase.instance.client.storage
          .from('profiles')
          .download('/$userId/banner');
      
      if (response.isNotEmpty) {
        await file.writeAsBytes(response);
        final fileUrl = file.uri.toString();
        _bannerCache[userId] = fileUrl;
        _bannerFetchTime[userId] = DateTime.now();
        debugPrint('Banner downloaded and cached: $fileUrl');
        return fileUrl;
      }
    } catch (e) {
      debugPrint('Error getting banner URL: $e');
    }
    
    debugPrint('Using fallback banner URL: $bannerUrl');
    return bannerUrl;
  }

  /// Uploads a banner image to Supabase storage and updates the profile
  /// Returns the public URL of the uploaded image or null if upload fails
  static Future<String?> uploadBannerImage(XFile image) async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final userId = supabaseService.currentUser.value?.id;
      
      if (userId == null) return null;

      // Read image bytes
      final imageBytes = await image.readAsBytes();

      // Upload image to Supabase storage
      await supabaseService.client.storage
          .from('profiles')
          .uploadBinary(
            '/$userId/banner',
            imageBytes,
            fileOptions: const FileOptions(upsert: true, cacheControl: '3600'),
          );

      // Get the public URL for the uploaded image
      final imageUrl = supabaseService.client.storage
          .from('profiles')
          .getPublicUrl('/$userId/banner');

      debugPrint('Uploaded banner URL: $imageUrl');
      
      // Update the banner in the profiles table
      await supabaseService.client.from('profiles').upsert({
        'user_id': userId,
        'banner': imageUrl,
      });

      // Update cache status
      supabaseService.profileDataCached.value = true;
      supabaseService.lastProfileFetch = DateTime.now();

      // Update the account data provider
      final accountDataProvider = Get.find<AccountDataProvider>();
      accountDataProvider.banner.value = imageUrl;

      // Update memory cache
      _bannerCache[userId] = imageUrl;
      _bannerFetchTime[userId] = DateTime.now();

      // Cache to file system
      try {
        final cachedPath = await _getBannerCachePath(userId);
        final file = File(cachedPath);
        await file.writeAsBytes(imageBytes);
        debugPrint('Banner cached to: $cachedPath');
      } catch (e) {
        debugPrint('Error caching banner to file: $e');
      }

      return imageUrl;
    } on StorageException catch (e) {
      debugPrint('Storage error uploading banner: $e');
      Get.snackbar(
        'Storage Error',
        'Failed to upload banner to storage',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return null;
    } catch (e) {
      debugPrint('Error uploading banner: $e');
      Get.snackbar(
        'Error',
        'Failed to update profile with new banner',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return null;
    }
  }

  /// Preloads banner images to make them instantly available when needed
  static Future<void> preloadBannerImages(AccountDataProvider provider) async {
    try {
      final bannerUrl = provider.banner.value;
      if (bannerUrl.isNotEmpty) {
        debugPrint('Preloading banner: $bannerUrl');
        // This will cache the image in memory
        await precacheImage(
          CachedNetworkImageProvider(bannerUrl),
          Get.context!,
        );
        debugPrint('Banner preloaded successfully');
      }
    } catch (e) {
      debugPrint('Error preloading banner: $e');
    }
  }

  /// Deletes the current user's banner
  static Future<bool> deleteBanner() async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final userId = supabaseService.currentUser.value?.id;

      if (userId == null) return false;

      // Remove banner from profiles table
      await supabaseService.client
          .from('profiles')
          .update({'banner': null}).eq('user_id', userId);

      // Update the account data provider
      final accountDataProvider = Get.find<AccountDataProvider>();
      accountDataProvider.banner.value = '';

      return true;
    } catch (e) {
      debugPrint('Error deleting banner: $e');
      return false;
    }
  }
}

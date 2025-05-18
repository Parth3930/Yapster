import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Utility class for handling avatar-related operations
/// This centralizes common avatar functionality used across controllers
class AvatarUtils {
  // Cache for avatar URLs to avoid unnecessary network requests
  static final Map<String, ImageProvider> _imageCache = {};

  /// Picks an image from the gallery and returns the selected image file
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        debugPrint('No image selected');
        Get.snackbar(
          'Error',
          'No image selected',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        debugPrint('Image selected: ${image.path}');
      }

      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick image',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  /// Uploads an avatar image to Supabase storage and updates the profile
  /// Returns the public URL of the uploaded image or null if upload fails
  /// Also updates the cache to ensure data consistency
  static Future<String?> uploadAvatarImage(XFile image) async {
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
            "/$userId/avatar",
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get the public URL for the uploaded image
      final imageUrl = supabaseService.client.storage
          .from('profiles')
          .getPublicUrl("/$userId/avatar");

      debugPrint('Uploaded image URL: $imageUrl');
      
      // Clear the cached image if it exists
      _imageCache.remove(imageUrl);

      // Update the avatar in the profiles table
      await supabaseService.client.from('profiles').upsert({
        'user_id': userId,
        'avatar': imageUrl,
      });

      // Update cache status
      supabaseService.profileDataCached.value = true;
      supabaseService.lastProfileFetch = DateTime.now();

      // Update the account data provider
      final accountDataProvider = Get.find<AccountDataProvider>();
      accountDataProvider.avatar.value = imageUrl;

      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      Get.snackbar(
        'Error',
        'Failed to upload image',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return null;
    }
  }

  /// Determines the appropriate avatar image source based on available data
  /// Uses internal memory caching for faster loading
  static ImageProvider? getAvatarImage(
    XFile? selectedImage,
    AccountDataProvider provider,
  ) {
    if (selectedImage != null) {
      return FileImage(File(selectedImage.path));
    } else if (provider.avatar.value.isNotEmpty &&
        provider.avatar.value != "skiped") {
      final url = provider.avatar.value;
      // Use cached image if available
      if (!_imageCache.containsKey(url)) {
        _imageCache[url] = CachedNetworkImageProvider(url);
      }
      return _imageCache[url];
    } else if (provider.googleAvatar.value.isNotEmpty) {
      final url = provider.googleAvatar.value;
      // Use cached image if available
      if (!_imageCache.containsKey(url)) {
        _imageCache[url] = CachedNetworkImageProvider(url);
      }
      return _imageCache[url];
    }
    return null;
  }

  /// Preloads avatar images to make them instantly available when needed
  static void preloadAvatarImages(AccountDataProvider provider) {
    if (provider.avatar.value.isNotEmpty && provider.avatar.value != "skiped") {
      // Preload user's avatar
      final url = provider.avatar.value;
      precacheImage(CachedNetworkImageProvider(url), Get.context!);
      _imageCache[url] = CachedNetworkImageProvider(url);
      debugPrint('Avatar preloaded: $url');
    }
    
    if (provider.googleAvatar.value.isNotEmpty) {
      // Preload Google avatar if available
      final url = provider.googleAvatar.value;
      precacheImage(CachedNetworkImageProvider(url), Get.context!);
      _imageCache[url] = CachedNetworkImageProvider(url);
      debugPrint('Google avatar preloaded: $url');
    }
  }

  /// Determines if the default icon should be shown for the avatar
  static bool shouldShowDefaultIcon(
    XFile? selectedImage,
    AccountDataProvider provider,
  ) {
    return selectedImage == null &&
        provider.avatar.value.isEmpty &&
        provider.googleAvatar.value.isEmpty;
  }
}

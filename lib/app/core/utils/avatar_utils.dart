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

  /// Checks if a URL is valid and usable
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) {
      debugPrint('Avatar URL is null or empty');
      return false;
    }
    
    if (url == "skiped" || url == "null") {
      debugPrint('Avatar URL is explicitly marked as skipped: $url');
      return false;
    }
    
    try {
      final uri = Uri.parse(url);
      final bool isValid = uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
      if (!isValid) {
        debugPrint('Invalid URL scheme in AvatarUtils.isValidUrl: $url');
      }
      return isValid;
    } catch (e) {
      debugPrint('Invalid URL format in AvatarUtils.isValidUrl: $url');
      return false;
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
    } 
    
    // First try profile avatar (only if it's not marked as skipped)
    final profileAvatarUrl = provider.avatar.value;
    final googleAvatarUrl = provider.googleAvatar.value;
    
    // CRITICAL DEBUG: Log both avatar URLs to diagnose issues after hot restart
    debugPrint('AVATAR GET - Profile avatar: $profileAvatarUrl (${isValidUrl(profileAvatarUrl) ? 'valid' : 'invalid'})');
    debugPrint('AVATAR GET - Google avatar: $googleAvatarUrl (${isValidUrl(googleAvatarUrl) ? 'valid' : 'invalid'})');
    
    // Check if profile avatar is valid and not "skiped"
    if (isValidUrl(profileAvatarUrl)) {
      // Use cached image if available
      if (!_imageCache.containsKey(profileAvatarUrl)) {
        _imageCache[profileAvatarUrl] = CachedNetworkImageProvider(profileAvatarUrl);
      }
      debugPrint('Using profile avatar: $profileAvatarUrl');
      return _imageCache[profileAvatarUrl];
    } 
    
    // Fall back to Google avatar if profile avatar is invalid or "skiped"
    if (isValidUrl(googleAvatarUrl)) {
      // Use cached image if available
      if (!_imageCache.containsKey(googleAvatarUrl)) {
        _imageCache[googleAvatarUrl] = CachedNetworkImageProvider(googleAvatarUrl);
      }
      debugPrint('Using Google avatar fallback: $googleAvatarUrl');
      return _imageCache[googleAvatarUrl];
    }
    
    // No valid avatar found - return null instead of asset image
    // Callers should handle null by showing a default icon
    debugPrint('No valid avatar found, returning null');
    return null;
  }

  /// Preloads avatar images to make them instantly available when needed
  static void preloadAvatarImages(AccountDataProvider provider) {
    try {
      // Log avatar sources for debugging
      debugPrint('Preloading avatars - Profile avatar: ${provider.avatar.value}');
      debugPrint('Preloading avatars - Google avatar: ${provider.googleAvatar.value}');
      
      final bool hasSkippedAvatar = provider.avatar.value == "skiped" || provider.avatar.value == "null" || provider.avatar.value.isEmpty;
      
      // Preload profile avatar if valid
      final profileAvatarUrl = provider.avatar.value;
      if (isValidUrl(profileAvatarUrl)) {
        precacheImage(CachedNetworkImageProvider(profileAvatarUrl), Get.context!);
        _imageCache[profileAvatarUrl] = CachedNetworkImageProvider(profileAvatarUrl);
        debugPrint('Profile avatar preloaded: $profileAvatarUrl');
      }
      
      // Preload Google avatar if valid
      final googleAvatarUrl = provider.googleAvatar.value;
      if (isValidUrl(googleAvatarUrl)) {
        precacheImage(CachedNetworkImageProvider(googleAvatarUrl), Get.context!);
        _imageCache[googleAvatarUrl] = CachedNetworkImageProvider(googleAvatarUrl);
        debugPrint('Google avatar preloaded: $googleAvatarUrl');
        
        // CRITICAL FIX: If regular avatar is skiped, ensure the Google avatar is ready
        if (hasSkippedAvatar) {
          debugPrint('Regular avatar is skiped, ensuring Google avatar is set as fallback');
        }
      }
    } catch (e) {
      debugPrint('Error preloading avatars: $e');
    }
  }

  /// Determines if the default icon should be shown for the avatar
  static bool shouldShowDefaultIcon(
    XFile? selectedImage,
    AccountDataProvider provider,
  ) {
    // If selected image exists, we don't need the default icon
    if (selectedImage != null) {
      return false;
    }
    
    // Check if profile avatar is valid
    if (isValidUrl(provider.avatar.value)) {
      return false;
    }
    
    // Check if Google avatar is valid as fallback
    if (isValidUrl(provider.googleAvatar.value)) {
      return false;
    }
    
    // If we reach here, no valid avatar was found - show default icon
    return true;
  }

  /// Creates a widget for displaying an avatar with proper fallbacks
  static Widget getAvatarWidget(
    XFile? selectedImage,
    AccountDataProvider provider, {
    double radius = 24.0,
    Color? backgroundColor,
  }) {
    final bgColor = backgroundColor ?? Colors.grey.shade800;
    final avatar = getAvatarImage(selectedImage, provider);
    
    // Log avatar sources for debugging
    debugPrint('Avatar Widget - Profile avatar: ${provider.avatar.value}');
    debugPrint('Avatar Widget - Google avatar: ${provider.googleAvatar.value}');
    debugPrint('Avatar Widget - Has valid avatar: ${avatar != null}');
    
    if (avatar != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: avatar,
      );
    } else {
      // Show default icon if no avatar available
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Icon(
          Icons.person,
          size: radius * 0.8,
          color: Colors.white,
        ),
      );
    }
  }
}

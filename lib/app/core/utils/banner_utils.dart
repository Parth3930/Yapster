import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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
            fileOptions: const FileOptions(upsert: true),
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

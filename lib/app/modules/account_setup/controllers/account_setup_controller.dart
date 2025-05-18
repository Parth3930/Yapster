import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../routes/app_pages.dart';

class AccountSetupController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final TextEditingController usernameController = TextEditingController();
  final RxBool isLoading = false.obs;
  final Rx<XFile?> selectedImage = Rx<XFile?>(null);
  final _accountDataProvider = Get.find<AccountDataProvider>();

  // Save account data and navigate to home
  Future<void> saveUsername() async {
    if (usernameController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a username',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading.value = true;
      final username = usernameController.text.trim();
      if (_supabaseService.currentUser.value == null) return;
      final currentUser = _supabaseService.currentUser.value;

      // Update or insert the username in the profiles table
      // Supabase will handle uniqueness constraints
      try {
        await _supabaseService.client.from('profiles').upsert({
          'user_id': currentUser!.id,
          'username': username,
        });

        // Update local data provider and cache status
        _accountDataProvider.username.value = username;
        _supabaseService.profileDataCached.value = true;
        _supabaseService.lastProfileFetch = DateTime.now();

        // Navigate to avatar setup after successful username save
        Get.offAllNamed(Routes.ACCOUNT_AVATAR_SETUP);
      } catch (dbError) {
        debugPrint('Database error saving username: $dbError');

        // Check if it's a uniqueness constraint error
        if (dbError.toString().contains('unique') ||
            dbError.toString().contains('duplicate') ||
            dbError.toString().contains('23505')) {
          Get.snackbar(
            'Username Taken',
            'This username is already in use. Please choose another one.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red[400],
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        } else {
          Get.snackbar(
            'Error',
            'Failed to save username. Please try again.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red[400],
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      debugPrint('Error in username setup: $e');
      Get.snackbar(
        'Error',
        'An unexpected error occurred',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> skipedAvatar() async {
    try {
      isLoading.value = true;
      if (_supabaseService.currentUser.value == null) return;
      await _supabaseService.client.from('profiles').upsert({
        'user_id': _supabaseService.currentUser.value!.id,
        'avatar': "skiped",
      });

      // Update cache status
      _supabaseService.profileDataCached.value = true;
      _supabaseService.lastProfileFetch = DateTime.now();

      // Navigate to home after skipping
      Get.offAllNamed(Routes.HOME);
    } catch (e) {
      debugPrint('Error skipping avatar: $e');
      Get.snackbar(
        'Error',
        'An error occurred',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveAvatar() async {
    try {
      isLoading.value = true;

      // Check if we have a selected image
      if (selectedImage.value == null) {
        Get.snackbar(
          'Error',
          'No image selected',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Use the centralized avatar upload utility
      final imageUrl = await AvatarUtils.uploadAvatarImage(
        selectedImage.value!,
      );

      if (imageUrl != null) {
        _accountDataProvider.avatar.value = imageUrl;

        // Update cache status
        _supabaseService.profileDataCached.value = true;
        _supabaseService.lastProfileFetch = DateTime.now();

        Get.offAllNamed(Routes.HOME);
      }
    } catch (e) {
      debugPrint('Error saving avatar: $e');
      Get.snackbar(
        'Error',
        'Failed to save avatar',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImage() async {
    final image = await AvatarUtils.pickImageFromGallery();
    if (image != null) {
      selectedImage.value = image;
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }
}

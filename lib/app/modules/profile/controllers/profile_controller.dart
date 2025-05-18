import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/routes/app_pages.dart';

class ProfileController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final Rx<XFile?> selectedImage = Rx<XFile?>(null);
  final RxBool isLoading = false.obs;
  final RxInt selectedTabIndex = 0.obs;
  
  // Track avatar loading status specifically
  final RxBool isAvatarLoaded = false.obs;
  
  // Edit icon animation scale
  final RxDouble editIconScale = 1.0.obs;

  // Store last username update timestamp
  DateTime? _lastUsernameUpdate;

  @override
  void onInit() {
    super.onInit();
    // Preload avatar if available
    preloadAvatarImages();
    fetchUserData();
  }
  
  /// Sets the scale for the edit icon animation
  void setEditIconScale(double scale) {
    editIconScale.value = scale;
  }
  
  /// Preloads avatar images for faster loading
  void preloadAvatarImages() {
    // Only attempt to preload if we already have data cached
    if (_supabaseService.profileDataCached.value && 
        _accountDataProvider.avatar.value.isNotEmpty) {
      debugPrint('Preloading avatar images');
      // Use the utility method to preload avatars
      AvatarUtils.preloadAvatarImages(_accountDataProvider);
      isAvatarLoaded.value = true;
    }
  }

  Future<void> fetchUserData() async {
    try {
      isLoading.value = true;
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) return;

      // Check if we have cached data and it's not too old (cache for 6 hours)
      bool shouldFetchFromDB = true;

      if (_supabaseService.profileDataCached.value &&
          _supabaseService.lastProfileFetch != null) {
        final cacheDuration = DateTime.now().difference(
          _supabaseService.lastProfileFetch!,
        );
        // Use cache if it's less than 6 hours old and we have data
        if (cacheDuration.inHours < 6 &&
            _accountDataProvider.username.value.isNotEmpty) {
          shouldFetchFromDB = false;
          debugPrint('Using cached profile data');
        }
      }

      if (shouldFetchFromDB) {
        debugPrint('Fetching profile data from database');
        final userData =
            await _supabaseService.client
                .from('profiles')
                .select('nickname, username, bio, userNameUpdate, avatar')
                .eq('user_id', userId)
                .single();

        // Update account provider with values from the database
        _accountDataProvider.nickname.value = userData['nickname'] ?? '';
        _accountDataProvider.username.value = userData['username'] ?? '';
        _accountDataProvider.bio.value = userData['bio'] ?? '';
        if (userData['avatar'] != null) {
          _accountDataProvider.avatar.value = userData['avatar'];
          
          // Preload avatar after fetching
          AvatarUtils.preloadAvatarImages(_accountDataProvider);
          isAvatarLoaded.value = true;
        }

        // Parse the username update timestamp if it exists
        if (userData['userNameUpdate'] != null) {
          try {
            // Try to convert string to DateTime
            _lastUsernameUpdate = DateTime.now().subtract(
              Duration(days: 15),
            ); // Default to allowing updates
            debugPrint('Last username update: ${userData['userNameUpdate']}');
          } catch (e) {
            debugPrint('Error parsing username update timestamp: $e');
          }
        }

        // Update cache status
        _supabaseService.profileDataCached.value = true;
        _supabaseService.lastProfileFetch = DateTime.now();
        debugPrint('Profile data loaded from DB: ${userData.toString()}');
      } else {
        debugPrint(
          'Using cached profile data: ${_accountDataProvider.username.value}',
        );
        // Set avatar loaded status for cached data
        isAvatarLoaded.value = true;
      }

      // Initialize controller values with current data (from cache or DB)
      nicknameController.text = _accountDataProvider.nickname.value;
      usernameController.text = _accountDataProvider.username.value;
      bioController.text = _accountDataProvider.bio.value;

      debugPrint('Avatar URL: ${_accountDataProvider.avatar.value}');
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      Get.snackbar(
        'Error',
        'Failed to load profile data',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateUserProfile(String newName) async {
    try {
      _supabaseService.client.from("profiles").upsert({
        'user_id': _supabaseService.currentUser.value!.id,
        'nickname': newName,
      });
      // Update the local nickname
      _accountDataProvider.nickname.value = newName;
      notifyChildrens();
    } catch (e) {
      debugPrint('Error updating nickname: $e');
    }
  }

  void selectTab(int index) {
    selectedTabIndex.value = index;
  }

  Future<String?> uploadImage() async {
    if (selectedImage.value == null) {
      return null;
    }

    // Use the centralized avatar upload utility
    return await AvatarUtils.uploadAvatarImage(selectedImage.value!);
  }

  bool canUpdateUsername() {
    // Check if 14 days have passed since the last username update
    if (_lastUsernameUpdate == null) {
      return true; // First time updating
    }

    final now = DateTime.now();
    final difference = now.difference(_lastUsernameUpdate!);
    final daysRemaining = 14 - difference.inDays;

    debugPrint('Days since last username update: ${difference.inDays}');
    debugPrint('Days remaining until next allowed update: $daysRemaining');

    return difference.inDays >= 14;
  }

  Future<bool> updateFullProfile() async {
    try {
      isLoading.value = true;

      // Check what fields have changed
      final hasNicknameChanged =
          nicknameController.text != _accountDataProvider.nickname.value;
      final hasUsernameChanged =
          usernameController.text != _accountDataProvider.username.value;
      final hasBioChanged =
          bioController.text != _accountDataProvider.bio.value;

      debugPrint(
        'Changes - Nickname: $hasNicknameChanged, Username: $hasUsernameChanged, Bio: $hasBioChanged',
      );

      // If username has changed, check if we can update it
      if (hasUsernameChanged && !canUpdateUsername()) {
        final now = DateTime.now();
        final difference = now.difference(_lastUsernameUpdate!);
        final daysRemaining = 14 - difference.inDays;

        Get.snackbar(
          'Username Update Restricted',
          'You can only update your username once every 14 days. Please wait $daysRemaining more days.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
        return false;
      }

      // Upload image if one is selected
      if (selectedImage.value != null) {
        final avatarUrl = await uploadImage();
        if (avatarUrl != null) {
          _accountDataProvider.avatar.value = avatarUrl;
          // Preload new avatar
          AvatarUtils.preloadAvatarImages(_accountDataProvider);
          isAvatarLoaded.value = true;
        }
      }

      // Only update profile data if something has changed
      if (hasNicknameChanged || hasUsernameChanged || hasBioChanged) {
        await updateProfile(
          hasNicknameChanged ? nicknameController.text : null,
          hasUsernameChanged ? usernameController.text : null,
          hasBioChanged ? bioController.text : null,
          hasUsernameChanged,
        );

        // Update local data provider for changed fields
        if (hasNicknameChanged) {
          _accountDataProvider.nickname.value = nicknameController.text;
        }
        if (hasUsernameChanged) {
          _accountDataProvider.username.value = usernameController.text;
        }
        if (hasBioChanged) {
          _accountDataProvider.bio.value = bioController.text;
        }

        // Update cache status
        _supabaseService.profileDataCached.value = true;
        _supabaseService.lastProfileFetch = DateTime.now();
      }

      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Navigate back to profile page
      Get.offNamed(Routes.PROFILE);

      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      Get.snackbar(
        'Error',
        'Failed to update profile: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProfile(
    String? nickName,
    String? username,
    String? bio,
    bool updateUsernameTimestamp,
  ) async {
    final userId = _supabaseService.currentUser.value!.id;

    // Only include fields that have changed
    final Map<String, dynamic> updateData = {'user_id': userId};

    // Add fields that have changed
    if (nickName != null) updateData['nickname'] = nickName;
    if (username != null) updateData['username'] = username;
    if (bio != null) updateData['bio'] = bio;

    // Update the username update timestamp if username was changed
    if (updateUsernameTimestamp) {
      // Get current time and format it as just time (HH:MM:SS) - for PostgreSQL 'time' type
      final now = DateTime.now();
      final timeString =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      updateData['userNameUpdate'] = timeString;
      _lastUsernameUpdate = now;

      debugPrint('Setting userNameUpdate to time string: $timeString');
    }

    // Only make the update if there's something to update
    if (updateData.length > 1) {
      await _supabaseService.client.from('profiles').upsert(updateData);
      debugPrint('Profile updated with data: $updateData');

      // Update cache status after successful database update
      _supabaseService.profileDataCached.value = true;
      _supabaseService.lastProfileFetch = DateTime.now();
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
    nicknameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    super.onClose();
  }
}

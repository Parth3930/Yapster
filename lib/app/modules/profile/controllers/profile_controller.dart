import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/modules/profile/views/follow_list_view.dart';
import 'package:yapster/app/core/models/follow_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final StorageService _storageService = Get.find<StorageService>();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final Rx<XFile?> selectedImage = Rx<XFile?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isEditPressed = false.obs;
  final RxInt selectedTabIndex = 0.obs;

  // Track image loading and upload status
  final RxBool isAvatarLoaded = false.obs;
  final RxBool isBannerLoaded = false.obs;
  final Rx<XFile?> selectedBanner = Rx<XFile?>(null);
  final RxDouble editIconScale = 1.0.obs;
  DateTime? _lastUsernameUpdate;
  static const String _lastUsernameUpdateKey = 'last_username_update';

  final RxInt selectedTab = 0.obs; // 0 = Posts, 1 = Videos, 2 = Threads

  @override
  void onInit() {
    super.onInit();
    // Preload avatar if available
    preloadAvatarImages();
    _loadLastUpdateTimeFromPrefs();
    fetchUserData();
  }

  /// Loads the last username update time from SharedPreferences
  void _loadLastUpdateTimeFromPrefs() {
    try {
      final savedTimeString = _storageService.getString(_lastUsernameUpdateKey);
      if (savedTimeString != null && savedTimeString.isNotEmpty) {
        _lastUsernameUpdate = DateTime.parse(savedTimeString);
        debugPrint(
          'Loaded username update time from prefs: $_lastUsernameUpdate',
        );
      }
    } catch (e) {
      debugPrint('Error loading last username update time: $e');
    }
  }

  /// Saves the last username update time to SharedPreferences
  Future<void> _saveLastUpdateTimeToPrefs(DateTime updateTime) async {
    try {
      await _storageService.saveString(
        _lastUsernameUpdateKey,
        updateTime.toIso8601String(),
      );
      debugPrint('Saved username update time to prefs: $updateTime');
    } catch (e) {
      debugPrint('Error saving last username update time: $e');
    }
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
                .select(
                  'nickname, username, bio, userNameUpdate, avatar, google_avatar',
                )
                .eq('user_id', userId)
                .single();

        // Update account provider with values from the database
        _accountDataProvider.nickname.value = userData['nickname'] ?? '';
        _accountDataProvider.username.value = userData['username'] ?? '';
        _accountDataProvider.bio.value = userData['bio'] ?? '';

        // Update avatar
        if (userData['avatar'] != null) {
          _accountDataProvider.avatar.value = userData['avatar'];
        }

        // Update Google avatar if available
        if (userData['google_avatar'] != null &&
            userData['google_avatar'].toString().isNotEmpty) {
          debugPrint(
            'Setting Google avatar from DB: ${userData['google_avatar']}',
          );
          _accountDataProvider.googleAvatar.value = userData['google_avatar'];
        }

        // CRITICAL FIX: Log avatar status to help diagnose skiped avatar issues
        final bool hasSkippedAvatar =
            userData['avatar'] == "skiped" || userData['avatar'] == null;
        debugPrint(
          'Avatar status in loadUserProfile: regular=${userData['avatar']}, google=${userData['google_avatar']}, isSkiped=$hasSkippedAvatar',
        );

        // Ensure we have a valid avatar image to show after loading
        if (hasSkippedAvatar &&
            userData['google_avatar'] != null &&
            userData['google_avatar'].toString().isNotEmpty) {
          debugPrint('Using Google avatar as fallback for skiped avatar');
        }

        // Preload avatar after fetching
        AvatarUtils.preloadAvatarImages(_accountDataProvider);
        isAvatarLoaded.value = true;

        // Parse the username update timestamp if it exists in database
        // and we don't already have a more precise timestamp from SharedPreferences
        if (_lastUsernameUpdate == null && userData['userNameUpdate'] != null) {
          try {
            final updateTimeString = userData['userNameUpdate'].toString();
            debugPrint(
              'Found username update timestamp in DB: $updateTimeString',
            );

            if (updateTimeString.isNotEmpty) {
              // If it's just a time string (HH:MM:SS), use today's date with that time
              if (updateTimeString.contains(':') &&
                  !updateTimeString.contains('-')) {
                final now = DateTime.now();
                final parts = updateTimeString.split(':');
                if (parts.length >= 3) {
                  try {
                    final hour = int.parse(parts[0]);
                    final minute = int.parse(parts[1]);
                    final secondParts = parts[2].split(
                      '.',
                    ); // Handle seconds with decimal
                    final second = int.parse(secondParts[0]);

                    // Create a DateTime with today's date but the stored time
                    // Then subtract 13 days to be conservative about the restriction
                    _lastUsernameUpdate = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      hour,
                      minute,
                      second,
                    ).subtract(const Duration(days: 13));

                    debugPrint(
                      'Set username update time to: $_lastUsernameUpdate',
                    );

                    // Also save to SharedPreferences for future reference
                    _saveLastUpdateTimeToPrefs(_lastUsernameUpdate!);
                  } catch (parseError) {
                    debugPrint('Error parsing time components: $parseError');
                    _lastUsernameUpdate = DateTime.now().subtract(
                      const Duration(days: 13),
                    );
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error parsing username update timestamp: $e');
            // Default to a conservative approach if parsing fails
            _lastUsernameUpdate = DateTime.now().subtract(
              const Duration(days: 13),
            );
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

  void setSelectedTab(int index) {
    selectedTab.value = index;
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
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Upload any new avatar image if selected
      String? newAvatarUrl;
      if (selectedImage.value != null) {
        newAvatarUrl = await uploadImage();
        if (newAvatarUrl != null) {
          _accountDataProvider.avatar.value = newAvatarUrl;
        }
      }

      // Upload any new banner image if selected
      String? newBannerUrl;
      if (selectedBanner.value != null) {
        newBannerUrl = await _uploadBannerImage();
        if (newBannerUrl != null) {
          _accountDataProvider.banner.value = newBannerUrl;
        }
      }

      // Update profile data in database
      final updates = {
        'user_id': userId,
        'nickname': nicknameController.text,
        'username': usernameController.text,
        'bio': bioController.text,
        if (newAvatarUrl != null) 'avatar': newAvatarUrl,
        if (newBannerUrl != null) 'banner': newBannerUrl,
      };

      await _supabaseService.client.from('profiles').upsert(updates);

      // Update local state
      _accountDataProvider.nickname.value = nicknameController.text;
      _accountDataProvider.username.value = usernameController.text;
      _accountDataProvider.bio.value = bioController.text;

      Get.back(); // Return to profile view
      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      Get.snackbar(
        'Error',
        'Failed to update profile. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
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

    // Ensure we preserve the Google avatar in the database
    // This ensures it will be available as a fallback when avatar is "skiped"
    if (_accountDataProvider.googleAvatar.value.isNotEmpty) {
      updateData['google_avatar'] = _accountDataProvider.googleAvatar.value;
      debugPrint(
        'Preserving Google avatar in profile update: ${_accountDataProvider.googleAvatar.value}',
      );
    }

    // Update the username update timestamp if username was changed
    if (updateUsernameTimestamp) {
      // Get current time
      final now = DateTime.now();

      // Format it as just time (HH:MM:SS) for PostgreSQL 'time' type
      final timeString =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      updateData['userNameUpdate'] = timeString;

      // Store the full datetime internally
      _lastUsernameUpdate = now;

      // Save to persistent storage
      _saveLastUpdateTimeToPrefs(now);

      debugPrint('Setting userNameUpdate time in DB: $timeString');
      debugPrint('Saving full timestamp locally: ${now.toIso8601String()}');
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

  /// Pick banner image
  Future<void> pickBanner() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        selectedBanner.value = image;
        isBannerLoaded.value = false;
      }
    } catch (e) {
      debugPrint('Error picking banner image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick banner image. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Upload banner image to storage
  Future<String?> _uploadBannerImage() async {
    if (selectedBanner.value == null) return null;

    try {
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) throw Exception('User not authenticated');

      final bytes = await selectedBanner.value!.readAsBytes();
      final fileExt = selectedBanner.value!.path.split('.').last;
      final fileName = 'banner.$fileExt';
      final filePath = 'profiles/$userId/$fileName';

      final result = await _supabaseService.client.storage
          .from('profiles')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      if (result.isEmpty) throw Exception('Failed to upload banner');

      final url = _supabaseService.client.storage
          .from('profiles')
          .getPublicUrl(filePath);

      return url;
    } catch (e) {
      debugPrint('Error uploading banner: $e');
      return null;
    }
  }

  @override
  void onClose() {
    nicknameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    super.onClose();
  }

  // Opens a list of followers for the current user
  void openFollowersList() {
    final userId = _supabaseService.currentUser.value?.id;
    if (userId == null) return;

    final nickname =
        _accountDataProvider.nickname.value.isEmpty
            ? 'User'
            : _accountDataProvider.nickname.value;

    Get.to(
      () => FollowListView(
        userId: userId,
        type: FollowType.followers,
        title: '$nickname\'s Followers',
      ),
      transition: Transition.rightToLeft,
    );
  }

  // Opens a list of users that the current user is following
  void openFollowingList() {
    final userId = _supabaseService.currentUser.value?.id;
    if (userId == null) return;

    final nickname =
        _accountDataProvider.nickname.value.isEmpty
            ? 'User'
            : _accountDataProvider.nickname.value;

    Get.to(
      () => FollowListView(
        userId: userId,
        type: FollowType.following,
        title: '$nickname is Following',
      ),
      transition: Transition.rightToLeft,
    );
  }
}

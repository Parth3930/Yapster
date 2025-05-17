import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  
  // Store last username update timestamp
  DateTime? _lastUsernameUpdate;
  
  @override
  void onInit() {
    super.onInit();
    fetchUserData();
  }
  
  Future<void> fetchUserData() async {
    try {
      isLoading.value = true;
      // Get current profile data from database
      final userId = _supabaseService.currentUser.value?.id;
      if (userId != null) {
        final userData = await _supabaseService.client
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
        }
        
        // Parse the username update timestamp if it exists
        if (userData['userNameUpdate'] != null) {
          try {
            // Try to convert string to DateTime
            _lastUsernameUpdate = DateTime.now().subtract(Duration(days: 15)); // Default to allowing updates
            debugPrint('Last username update: ${userData['userNameUpdate']}');
          } catch (e) {
            debugPrint('Error parsing username update timestamp: $e');
          }
        }
        
        // Initialize controller values with current data
        nicknameController.text = _accountDataProvider.nickname.value;
        usernameController.text = _accountDataProvider.username.value;
        bioController.text = _accountDataProvider.bio.value;
        
        debugPrint('Profile data loaded: ${userData.toString()}');
        debugPrint('Avatar URL: ${_accountDataProvider.avatar.value}');
      }
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
    try {
      if (selectedImage.value == null) {
        return null;
      }
      
      final userId = _supabaseService.currentUser.value?.id;
      if (userId == null) return null;

      // Read image bytes
      final imageBytes = await selectedImage.value!.readAsBytes();

      // Upload image to Supabase storage
      await _supabaseService.client.storage
          .from('profiles')
          .uploadBinary(
            "/$userId/avatar",
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get the public URL for the uploaded image
      final imageUrl = _supabaseService.client.storage
          .from('profiles')
          .getPublicUrl("/$userId/avatar");
      
      debugPrint('Uploaded image URL: $imageUrl');
      
      // Update the avatar in the profiles table
      await _supabaseService.client.from('profiles').upsert({
        'user_id': userId,
        'avatar': imageUrl,
      });
      
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
      final hasNicknameChanged = nicknameController.text != _accountDataProvider.nickname.value;
      final hasUsernameChanged = usernameController.text != _accountDataProvider.username.value;
      final hasBioChanged = bioController.text != _accountDataProvider.bio.value;
      
      debugPrint('Changes - Nickname: $hasNicknameChanged, Username: $hasUsernameChanged, Bio: $hasBioChanged');
      
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
      final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      updateData['userNameUpdate'] = timeString;
      _lastUsernameUpdate = now;
      
      debugPrint('Setting userNameUpdate to time string: $timeString');
    }
    
    // Only make the update if there's something to update
    if (updateData.length > 1) {
      await _supabaseService.client.from('profiles').upsert(updateData);
      debugPrint('Profile updated with data: $updateData');
    }
  }

  Future<void> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Store the selected image in our reactive variable
        selectedImage.value = image;
        debugPrint('Image selected: ${image.path}');
      } else {
        debugPrint('No image selected');
        Get.snackbar(
          'Error',
          'No image selected',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick image',
        snackPosition: SnackPosition.BOTTOM,
      );
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

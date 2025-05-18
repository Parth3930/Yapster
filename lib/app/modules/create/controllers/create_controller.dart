import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';

class CreateController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider = Get.find<AccountDataProvider>();
  
  // User info - use reactive data from AccountDataProvider
  RxString get username => _accountDataProvider.username;
  RxString get userAvatar => _accountDataProvider.avatar;
  final RxBool isVerified = false.obs;
  
  // Post content
  final TextEditingController postTextController = TextEditingController();
  final RxString selectedPostType = 'text'.obs;
  
  // Media URLs
  final RxString imageUrl = ''.obs;
  final RxString gifUrl = ''.obs;
  final RxString stickerUrl = ''.obs;
  
  
  @override
  void onClose() {
    postTextController.dispose();
    super.onClose();
  }
    
  Future<void> createPost() async {
    if (postTextController.text.trim().isEmpty && 
        imageUrl.isEmpty && gifUrl.isEmpty && stickerUrl.isEmpty) {
      Get.snackbar('Error', 'Post cannot be empty');
      return;
    }
    
    try {
      // Create post data based on selected type
      final postData = {
        'content': postTextController.text,
        'image_url': selectedPostType.value == 'image' ? imageUrl.value : null,
        'gif_url': selectedPostType.value == 'gif' ? gifUrl.value : null,
        'sticker_url': selectedPostType.value == 'sticker' ? stickerUrl.value : null,
        'metadata': {},
      };
      
      // Determine post category for API call
      String category;
      switch (selectedPostType.value) {
        case 'text':
          category = 'threads';
          break;
        case 'image':
          category = 'images';
          break;
        case 'gif':
          category = 'gifs';
          break;
        case 'sticker':
          category = 'stickers';
          break;
        default:
          category = 'threads';
      }
      
      // Add the post
      await _supabaseService.addNewPost(postData, category);
      
      Get.back();
      Get.snackbar('Success', 'Post created successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to create post: ${e.toString()}');
    }
  }
  
  void setPostType(String type) {
    selectedPostType.value = type;
  }
}
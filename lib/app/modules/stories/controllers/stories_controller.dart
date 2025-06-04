import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class StoriesController extends GetxController {
  // Track if the story creation panel is visible
  final RxBool isStoryPanelVisible = false.obs;
  
  // Store recent media files
  final RxList<File> recentMedia = <File>[].obs;
  
  // Image picker instance
  final ImagePicker _picker = ImagePicker();
  
  // Track loading state
  final RxBool isLoading = false.obs;
  
  // Track currently selected image
  final Rxn<File> selectedImage = Rxn<File>();

  @override
  void onInit() {
    super.onInit();
    requestPhotoPermission();
  }
  
  // Request photo library permission
  Future<void> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      loadRecentGalleryImages();
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      bool? shouldOpenSettings = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Photo library permission is required to show your recent photos. Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
      
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
    } else {
      Get.snackbar(
        'Permission Required',
        'Please grant photo library access to show recent images',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  // Load recent images from gallery
  Future<void> loadRecentGalleryImages() async {
    try {
      isLoading.value = true;
      
      // Check if we have permission
      final status = await Permission.photos.status;
      if (!status.isGranted) {
        // If permission was denied, don't proceed
        return;
      }
      
      // If we have permission, load the gallery images
      final List<AssetEntity> assets = await PhotoManager.getAssetListRange(
        start: 0,
        end: 5, // Get first 5 images
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );
      
      // Convert assets to files
      final List<File> files = [];
      for (var asset in assets) {
        final file = await asset.file;
        if (file != null) {
          files.add(file);
        }
      }
      
      recentMedia.assignAll(files);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load recent images: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  // Toggle the story creation panel
  void toggleStoryPanel() {
    isStoryPanelVisible.value = !isStoryPanelVisible.value;
  }
  
  // Select an image from the recent media
  void selectImage(File file) {
    selectedImage.value = file;
  }
  
  // Open image picker to select media
  Future<void> pickMedia() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      
      if (image != null) {
        final file = File(image.path);
        // Add to recent media if not already present
        if (!recentMedia.any((element) => element.path == file.path)) {
          recentMedia.insert(0, file);
        }
        selectedImage.value = file;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick media: $e');
    }
  }
  
  // Pick image from gallery
  Future<File?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      
      if (image != null) {
        final file = File(image.path);
        // Add to recent media if not already present
        if (!recentMedia.any((element) => element.path == file.path)) {
          recentMedia.insert(0, file);
        }
        return file;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
    return null;
  }
  
  // Take photo with camera
  Future<File?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      
      if (photo != null) {
        final file = File(photo.path);
        // Add to recent media
        recentMedia.insert(0, file);
        return file;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to take photo: $e');
    }
    return null;
  }
}

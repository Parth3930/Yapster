import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageEditController extends GetxController {
  // Observable variables
  final imageFile = Rx<File?>(null);
  final isLoading = false.obs;
  final aspectRatio = (4.0 / 5.0).obs;
  
  @override
  void onInit() {
    super.onInit();
    
    // Get arguments passed from navigation
    if (Get.arguments != null) {
      if (Get.arguments['imageFile'] != null) {
        imageFile.value = Get.arguments['imageFile'] as File;
      }
      
      if (Get.arguments['aspectRatio'] != null) {
        aspectRatio.value = Get.arguments['aspectRatio'] as double;
      }
      
      // Start cropping immediately
      cropImage();
    } else {
      Get.snackbar('Error', 'No image file provided');
      Get.back();
    }
  }
  
  Future<void> cropImage() async {
    isLoading.value = true;
    
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.value!.path,
        aspectRatio: CropAspectRatio(ratioX: 4, ratioY: 5),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            statusBarColor: Colors.black,
          ),
          IOSUiSettings(
            title: 'Edit Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      
      if (croppedFile != null) {
        imageFile.value = File(croppedFile.path);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      Get.snackbar('Error', 'Failed to crop image');
    } finally {
      isLoading.value = false;
    }
  }
  
  void finishEditing() {
    if (!isLoading.value && imageFile.value != null) {
      Get.back(result: {'editedImage': imageFile.value});
    }
  }
}
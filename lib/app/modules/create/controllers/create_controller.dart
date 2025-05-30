import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';

class CreateController extends GetxController {
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();

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

  void setPostType(String type) {
    selectedPostType.value = type;
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';

class ProfileController extends GetxController {
  final SupabaseService _supabaseService = Get.find<SupabaseService>();
  final AccountDataProvider _accountDataProvider =
      Get.find<AccountDataProvider>();
  final TextEditingController nicknameController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxInt selectedTabIndex = 0.obs;
  final RxString nickName = "".obs;
  final RxString username = "".obs;
  final RxString bio = "".obs;

  Future<void> updateNickName(String newName) async {
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
}

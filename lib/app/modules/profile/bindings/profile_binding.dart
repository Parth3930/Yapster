import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import '../controllers/profile_controller.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(() => ProfileController());
    Get.lazyPut<ChatController>(() => ChatController());

    // Ensure ExploreController is available for profile views
    if (!Get.isRegistered<ExploreController>()) {
      Get.lazyPut<ExploreController>(() => ExploreController());
      Get.lazyPut<AccountRepository>(() => AccountRepository());
    }
  }
}

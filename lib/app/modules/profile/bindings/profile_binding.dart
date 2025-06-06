import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import '../controllers/profile_controller.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/stories/bindings/stories_binding.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize Stories module
    StoriesBinding().dependencies();

    Get.lazyPut<PostRepository>(() => PostRepository());
    Get.lazyPut<ProfileController>(() => ProfileController());
    Get.lazyPut<ChatController>(() => ChatController());

    // Ensure ExploreController is available for profile views
    if (!Get.isRegistered<ExploreController>()) {
      Get.lazyPut<ExploreController>(() => ExploreController());
      Get.lazyPut<AccountRepository>(() => AccountRepository());
    }
  }
}

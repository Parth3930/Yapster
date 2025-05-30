import 'package:get/get.dart';
import '../controllers/profile_controller.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(() => ProfileController());

    // Ensure ExploreController is available for profile views
    if (!Get.isRegistered<ExploreController>()) {
      Get.lazyPut<ExploreController>(() => ExploreController());
    }
  }
}

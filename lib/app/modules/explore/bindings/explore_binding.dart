import 'package:get/get.dart';
import '../controllers/explore_controller.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';

class ExploreBinding extends Bindings {
  @override
  void dependencies() {
    // Register dependencies
    Get.lazyPut<AccountRepository>(() => AccountRepository());
    Get.lazyPut<ExploreController>(() => ExploreController());
  }
}

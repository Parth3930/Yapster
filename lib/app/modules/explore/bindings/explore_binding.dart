import 'package:get/get.dart';
import '../controllers/explore_controller.dart';

class ExploreBinding extends Bindings {
  @override
  void dependencies() {
    // Simply register the controller
    Get.lazyPut<ExploreController>(() => ExploreController());
  }
}
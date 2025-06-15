import 'package:get/get.dart';
import '../controllers/create_group_controller.dart';
import '../controllers/group_controller.dart';

class CreateGroupBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure GroupController is available
    Get.lazyPut<GroupController>(() => GroupController());
    // Create the CreateGroupController
    Get.lazyPut<CreateGroupController>(() => CreateGroupController());
  }
}

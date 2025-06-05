import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import '../controllers/create_controller.dart';

class CreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PostRepository>(() => PostRepository());
    Get.lazyPut<CreateController>(() => CreateController());
  }
}

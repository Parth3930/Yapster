import 'package:get/get.dart';
import 'package:yapster/app/modules/post/controllers/post_detail_controller.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';

class PostDetailBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure PostRepository is available
    if (!Get.isRegistered<PostRepository>()) {
      Get.put<PostRepository>(PostRepository(), permanent: true);
    }

    Get.lazyPut<PostDetailController>(() => PostDetailController());
  }
}

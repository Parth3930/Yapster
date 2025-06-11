import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/create_controller.dart';
import '../controllers/video_edit_controller.dart';
import '../controllers/image_edit_controller.dart';
import '../controllers/post_create_controller.dart';

class CreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PostRepository>(() => PostRepository());
    Get.lazyPut<StoryRepository>(() => StoryRepository());
    Get.lazyPut<CreateController>(() => CreateController());
    Get.lazyPut(() => BottomNavAnimationController());
  }
}

class VideoEditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideoEditController>(() => VideoEditController());
  }
}

class ImageEditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ImageEditController>(() => ImageEditController());
  }
}

class PostCreateBinding extends Bindings {
  @override
  void dependencies() {
    // Make sure CreateController is available
    if (!Get.isRegistered<CreateController>()) {
      Get.lazyPut<CreateController>(() => CreateController());
    }
    Get.lazyPut<PostCreateController>(() => PostCreateController());
  }
}

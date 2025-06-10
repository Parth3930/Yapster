import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import '../controllers/create_controller.dart';

class CreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PostRepository>(() => PostRepository());
    Get.lazyPut<StoryRepository>(() => StoryRepository());
    Get.lazyPut<CreateController>(() => CreateController());
    Get.lazyPut(() => BottomNavAnimationController());
  }
}

import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/doodle_controller.dart';
import 'package:yapster/app/modules/stories/controllers/text_controller.dart';
import 'package:yapster/app/modules/stories/controllers/story_viewer_controller.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import '../controllers/stories_controller.dart';

class StoriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StoryRepository>(() => StoryRepository());
    Get.lazyPut<StoriesController>(() => StoriesController(), fenix: true);
    Get.lazyPut<TextController>(() => TextController());
    Get.lazyPut<DoodleController>(() => DoodleController());
    Get.lazyPut<StoryViewerController>(() => StoryViewerController());
  }
}

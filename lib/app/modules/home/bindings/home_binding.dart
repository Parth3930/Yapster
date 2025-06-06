import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/stories_home_controller.dart';
import '../controllers/create_post_controller.dart';
import '../controllers/posts_feed_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StoryRepository>(() => StoryRepository());
    Get.lazyPut<PostRepository>(() => PostRepository());
    Get.lazyPut<AccountRepository>(() => AccountRepository());
    Get.lazyPut<ExploreController>(() => ExploreController());
    Get.put<HomeController>(HomeController(), permanent: true);
    Get.put<StoriesHomeController>(StoriesHomeController(), permanent: true);
    Get.put<PostsFeedController>(PostsFeedController(), permanent: true);
    Get.lazyPut<CreatePostController>(() => CreatePostController());
    Get.lazyPut(() => ChatController(), fenix: true);
  }
}

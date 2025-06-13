import 'package:get/get.dart';
import 'package:yapster/app/modules/videos/controllers/videos_player_controller.dart';

class VideosPlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideosPlayerController>(
      () => VideosPlayerController(),
    );
  }
} 
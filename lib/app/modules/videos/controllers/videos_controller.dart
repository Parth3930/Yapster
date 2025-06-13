import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';

class VideosController extends GetxController {
  final currentVideo = Rx<PostModel?>(null);
  final _postRepository = Get.find<PostRepository>();
  final _supabase = Get.find<SupabaseService>();

  void toggleVideoFavorite(String videoId) {
    if (currentVideo.value != null && currentVideo.value!.id == videoId) {
      final isFavorited = currentVideo.value!.metadata['isFavorited'] == true;
      currentVideo.value!.metadata['isFavorited'] = !isFavorited;
      currentVideo.refresh();

      // TODO: Implement actual favorite functionality with backend
      _postRepository.togglePostStar(videoId, _supabase.currentUser.value!.id);
      // For now, just update the UI state
    }
  }
}

import 'dart:async';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/models/story_model.dart';
import 'package:yapster/app/modules/home/controllers/stories_home_controller.dart';

class StoryViewerController extends GetxController {
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final StoryRepository _storyRepository = Get.find<StoryRepository>();

  // Observable variables
  final RxList<StoryModel> stories = <StoryModel>[].obs;
  final RxInt currentStoryIndex = 0.obs;
  final RxBool isLoading = true.obs;
  final RxString username = ''.obs;
  final RxString userAvatar = RxString('');

  // Timer for auto-advancing stories
  Timer? _storyTimer;
  final int storyDuration = 5; // seconds

  // Current story getter
  StoryModel? get currentStory =>
      stories.isNotEmpty && currentStoryIndex.value < stories.length
          ? stories[currentStoryIndex.value]
          : null;

  @override
  void onInit() {
    super.onInit();
    final userId = Get.parameters['userId'];
    if (userId != null) {
      loadUserStories(userId);
    }
  }

  @override
  void onClose() {
    _storyTimer?.cancel();

    // Refresh the stories home controller when closing with a delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (Get.isRegistered<StoriesHomeController>()) {
        Get.find<StoriesHomeController>().refreshStories();
      }
    });

    super.onClose();
  }

  /// Load stories for a specific user
  Future<void> loadUserStories(String userId) async {
    try {
      isLoading.value = true;

      // Load user info
      await loadUserInfo(userId);

      // Load stories
      final userStories = await _storyRepository.getUserStories(userId);
      stories.assignAll(userStories);

      if (stories.isNotEmpty) {
        currentStoryIndex.value = 0;
        startStoryTimer();

        // Mark first story as viewed
        await markCurrentStoryAsViewed();
      }
    } catch (e) {
      print('Error loading user stories: $e');
      Get.snackbar('Error', 'Failed to load stories');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load user information
  Future<void> loadUserInfo(String userId) async {
    try {
      final response =
          await _supabase.client
              .from('profiles')
              .select('username, nickname, avatar')
              .eq('user_id', userId)
              .single();

      username.value =
          response['nickname'] ?? response['username'] ?? 'Unknown';
      userAvatar.value = response['avatar'] ?? '';
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  /// Start timer for auto-advancing stories
  void startStoryTimer() {
    _storyTimer?.cancel();
    _storyTimer = Timer(Duration(seconds: storyDuration), () {
      nextStory();
    });
  }

  /// Go to next story
  void nextStory() {
    _storyTimer?.cancel();

    if (currentStoryIndex.value < stories.length - 1) {
      currentStoryIndex.value++;
      startStoryTimer();
      markCurrentStoryAsViewed();
    } else {
      // End of stories, go back and refresh home stories
      Get.back();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (Get.isRegistered<StoriesHomeController>()) {
          Get.find<StoriesHomeController>().refreshStories();
        }
      });
    }
  }

  /// Go to previous story
  void previousStory() {
    _storyTimer?.cancel();

    if (currentStoryIndex.value > 0) {
      currentStoryIndex.value--;
      startStoryTimer();
      markCurrentStoryAsViewed();
    } else {
      // At first story, go back and refresh home stories
      Get.back();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (Get.isRegistered<StoriesHomeController>()) {
          Get.find<StoriesHomeController>().refreshStories();
        }
      });
    }
  }

  /// Mark current story as viewed
  Future<void> markCurrentStoryAsViewed() async {
    try {
      final story = currentStory;
      final currentUser = _supabase.client.auth.currentUser;

      if (story != null && currentUser != null) {
        // Check if user has already viewed this story
        if (!story.viewers.contains(currentUser.id)) {
          // Add current user to viewers list
          final updatedViewers = [...story.viewers, currentUser.id];

          // Update the story in database
          await _supabase.client
              .from('stories')
              .update({
                'viewers': updatedViewers,
                'view_count': updatedViewers.length,
              })
              .eq('id', story.id);

          // Update local story data
          final storyIndex = stories.indexWhere((s) => s.id == story.id);
          if (storyIndex != -1) {
            stories[storyIndex] = StoryModel(
              id: story.id,
              userId: story.userId,
              imageUrl: story.imageUrl,
              textItems: story.textItems,
              doodlePoints: story.doodlePoints,
              createdAt: story.createdAt,
              expiresAt: story.expiresAt,
              updatedAt: story.updatedAt,
              viewCount: updatedViewers.length,
              viewers: updatedViewers,
              isActive: story.isActive,
            );
          }

          // Immediately force UI update and also refresh data
          if (Get.isRegistered<StoriesHomeController>()) {
            final homeController = Get.find<StoriesHomeController>();
            homeController.forceUpdate();
            homeController.refreshStories();
          }
        }
      }
    } catch (e) {
      print('Error marking story as viewed: $e');
    }
  }

  /// Get time ago string
  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

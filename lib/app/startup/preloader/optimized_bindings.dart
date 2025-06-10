import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/modules/home/controllers/home_controller.dart';
import 'package:yapster/app/modules/home/controllers/stories_home_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/controllers/create_post_controller.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/create/controllers/create_controller.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/chat/services/chat_message_service.dart';
import 'package:yapster/app/modules/chat/services/audio_services.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/startup/preloader/preloader_service.dart';

/// Optimized bindings that use preloaded controllers instead of creating new ones
/// This prevents rebuilding controllers and reloading data on every navigation
class OptimizedHomeBinding extends Bindings {
  @override
  void dependencies() {
    // Use preloaded controllers if available, otherwise create permanent ones

    // Repositories - use preloaded or create permanent ones
    if (!Get.isRegistered<StoryRepository>()) {
      Get.put<StoryRepository>(StoryRepository(), permanent: true);
    }
    if (!Get.isRegistered<PostRepository>()) {
      Get.put<PostRepository>(PostRepository(), permanent: true);
    }
    if (!Get.isRegistered<AccountRepository>()) {
      Get.put<AccountRepository>(AccountRepository(), permanent: true);
    }

    // Core controllers - use preloaded or create permanent ones
    if (!Get.isRegistered<ExploreController>()) {
      Get.put<ExploreController>(ExploreController(), permanent: true);
    }

    // Register BottomNavAnimationController as permanent
    if (!Get.isRegistered<BottomNavAnimationController>()) {
      Get.put<BottomNavAnimationController>(
        BottomNavAnimationController(),
        permanent: true,
      );
    }

    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(HomeController(), permanent: true);
    }
    if (!Get.isRegistered<StoriesHomeController>()) {
      Get.put<StoriesHomeController>(StoriesHomeController(), permanent: true);
    }
    if (!Get.isRegistered<PostsFeedController>()) {
      Get.put<PostsFeedController>(PostsFeedController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put<ChatController>(ChatController(), permanent: true);
    }

    // Create post controller can be lazy since it's not always needed
    Get.lazyPut<CreatePostController>(() => CreatePostController());
  }
}

class OptimizedProfileBinding extends Bindings {
  @override
  void dependencies() {
    // Use preloaded repositories
    if (!Get.isRegistered<PostRepository>()) {
      Get.put<PostRepository>(PostRepository(), permanent: true);
    }
    if (!Get.isRegistered<AccountRepository>()) {
      Get.put<AccountRepository>(AccountRepository(), permanent: true);
    }

    // Use preloaded controllers
    if (!Get.isRegistered<ProfileController>()) {
      Get.put<ProfileController>(ProfileController(), permanent: true);
    }
    if (!Get.isRegistered<ExploreController>()) {
      Get.put<ExploreController>(ExploreController(), permanent: true);
    }
    if (!Get.isRegistered<ChatController>()) {
      Get.put<ChatController>(ChatController(), permanent: true);
    }

    // Initialize Stories module if needed
    if (!Get.isRegistered<StoryRepository>()) {
      Get.put<StoryRepository>(StoryRepository(), permanent: true);
    }
  }
}

class OptimizedChatBinding extends Bindings {
  @override
  void dependencies() {
    // Only load essential services for instant chat opening
    if (!Get.isRegistered<ChatController>()) {
      Get.put<ChatController>(ChatController(), permanent: true);
    }
    if (!Get.isRegistered<ExploreController>()) {
      Get.put<ExploreController>(ExploreController(), permanent: true);
    }

    // Load only critical services immediately
    Get.lazyPut(() => ChatCacheService());
    Get.lazyPut(() => ChatMessageService());

    // AudioService is needed for audio message controllers
    Get.lazyPut(() => AudioService());

    // Skip non-essential services for faster loading
    // These will be loaded on-demand if needed:
    // - ChatSearchService (only needed for search)
    // - ChatCleanupService (only needed for cleanup)
  }
}

class OptimizedCreateBinding extends Bindings {
  @override
  void dependencies() {
    // Use preloaded repository
    if (!Get.isRegistered<PostRepository>()) {
      Get.put<PostRepository>(PostRepository(), permanent: true);
    }
    if (!Get.isRegistered<StoryRepository>()) {
      Get.put<StoryRepository>(StoryRepository(), permanent: true);
    }

    // IMPORTANT: CreateController should NOT be permanent to avoid camera access on startup
    // Only create it when actually needed (when navigating to create page)
    Get.lazyPut<CreateController>(() => CreateController());
    Get.lazyPut(() => BottomNavAnimationController());
  }
}

class OptimizedExploreBinding extends Bindings {
  @override
  void dependencies() {
    // Use preloaded controller
    if (!Get.isRegistered<ExploreController>()) {
      Get.put<ExploreController>(ExploreController(), permanent: true);
    }
  }
}

/// Utility class to check if app is optimized
class OptimizationChecker {
  static bool get isAppOptimized {
    try {
      final preloader = Get.find<PreloaderService>();
      return preloader.isPreloaded.value;
    } catch (e) {
      return false;
    }
  }

  static bool get areControllersPreloaded {
    try {
      final preloader = Get.find<PreloaderService>();
      return preloader.controllersPreloaded.value;
    } catch (e) {
      return false;
    }
  }

  static bool get isDataPreloaded {
    try {
      final preloader = Get.find<PreloaderService>();
      return preloader.dataPreloaded.value;
    } catch (e) {
      return false;
    }
  }

  static Map<String, bool> get controllerStatus {
    return {
      'HomeController': Get.isRegistered<HomeController>(),
      'ProfileController': Get.isRegistered<ProfileController>(),
      'ChatController': Get.isRegistered<ChatController>(),
      'CreateController': Get.isRegistered<CreateController>(),
      'ExploreController': Get.isRegistered<ExploreController>(),
      'PostsFeedController': Get.isRegistered<PostsFeedController>(),
      'StoriesHomeController': Get.isRegistered<StoriesHomeController>(),
    };
  }

  static Map<String, bool> get repositoryStatus {
    return {
      'PostRepository': Get.isRegistered<PostRepository>(),
      'AccountRepository': Get.isRegistered<AccountRepository>(),
      'StoryRepository': Get.isRegistered<StoryRepository>(),
    };
  }

  static void printOptimizationStatus() {
    debugPrint('=== App Optimization Status ===');
    debugPrint('App Optimized: $isAppOptimized');
    debugPrint('Controllers Preloaded: $areControllersPreloaded');
    debugPrint('Data Preloaded: $isDataPreloaded');
    debugPrint('');
    debugPrint('Controller Status:');
    controllerStatus.forEach((name, registered) {
      debugPrint('  $name: ${registered ? "✓" : "✗"}');
    });
    debugPrint('');
    debugPrint('Repository Status:');
    repositoryStatus.forEach((name, registered) {
      debugPrint('  $name: ${registered ? "✓" : "✗"}');
    });
    debugPrint('===============================');
  }
}

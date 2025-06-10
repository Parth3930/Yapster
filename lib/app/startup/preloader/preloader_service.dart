import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/modules/home/controllers/home_controller.dart';
import 'package:yapster/app/modules/home/controllers/stories_home_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/controllers/group_controller.dart';
import 'package:yapster/app/modules/create/controllers/create_controller.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/startup/feed_loader/feed_loader_service.dart';

/// Service responsible for preloading and caching all main app pages and controllers
/// This prevents rebuilding controllers and reloading data on every navigation
class PreloaderService extends GetxService {
  static const String _tag = 'PreloaderService';

  // Track preloading status
  final RxBool isPreloading = false.obs;
  final RxBool isPreloaded = false.obs;
  final RxString currentPreloadingStep = ''.obs;

  // Cache status for different components
  final RxBool controllersPreloaded = false.obs;
  final RxBool dataPreloaded = false.obs;
  final RxBool repositoriesPreloaded = false.obs;

  // Preloading progress
  final RxDouble preloadingProgress = 0.0.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    debugPrint('$_tag: Initialized');
  }

  /// Main method to preload all app components
  Future<void> preloadApp() async {
    if (isPreloading.value || isPreloaded.value) {
      debugPrint('$_tag: Already preloading or preloaded');
      return;
    }

    try {
      isPreloading.value = true;
      preloadingProgress.value = 0.0;
      debugPrint('$_tag: Starting app preloading...');

      // Step 1: Preload repositories (10%)
      await _preloadRepositories();
      preloadingProgress.value = 0.1;

      // Step 2: Preload core controllers (30%)
      await _preloadCoreControllers();
      preloadingProgress.value = 0.3;

      // Step 3: Preload page controllers (60%)
      await _preloadPageControllers();
      preloadingProgress.value = 0.6;

      // Step 4: Preload initial data (80%)
      await _preloadInitialData();
      preloadingProgress.value = 0.8;

      // Step 5: Warm up caches (100%)
      await _warmupCaches();
      preloadingProgress.value = 1.0;

      isPreloaded.value = true;
      debugPrint('$_tag: App preloading completed successfully');
    } catch (e) {
      debugPrint('$_tag: Error during preloading: $e');
      // Don't throw - app should still work without preloading
    } finally {
      isPreloading.value = false;
      currentPreloadingStep.value = '';
    }
  }

  /// Preload all repositories with permanent registration
  Future<void> _preloadRepositories() async {
    currentPreloadingStep.value = 'Loading repositories...';
    debugPrint('$_tag: Preloading repositories');

    try {
      // Register repositories as permanent singletons
      if (!Get.isRegistered<StoryRepository>()) {
        Get.put<StoryRepository>(StoryRepository(), permanent: true);
      }

      if (!Get.isRegistered<PostRepository>()) {
        Get.put<PostRepository>(PostRepository(), permanent: true);
      }

      if (!Get.isRegistered<AccountRepository>()) {
        Get.put<AccountRepository>(AccountRepository(), permanent: true);
      }

      repositoriesPreloaded.value = true;
      debugPrint('$_tag: Repositories preloaded');
    } catch (e) {
      debugPrint('$_tag: Error preloading repositories: $e');
    }
  }

  /// Preload core controllers that are used across multiple pages
  Future<void> _preloadCoreControllers() async {
    currentPreloadingStep.value = 'Loading core controllers...';
    debugPrint('$_tag: Preloading core controllers');

    try {
      // Explore controller - used in many places
      if (!Get.isRegistered<ExploreController>()) {
        Get.put<ExploreController>(ExploreController(), permanent: true);
      }

      debugPrint('$_tag: Core controllers preloaded');
    } catch (e) {
      debugPrint('$_tag: Error preloading core controllers: $e');
    }
  }

  /// Preload all main page controllers
  Future<void> _preloadPageControllers() async {
    currentPreloadingStep.value = 'Loading page controllers...';
    debugPrint('$_tag: Preloading page controllers');

    try {
      // Register BottomNavAnimationController first as it's needed by other controllers
      if (!Get.isRegistered<BottomNavAnimationController>()) {
        Get.put<BottomNavAnimationController>(
          BottomNavAnimationController(),
          permanent: true,
        );
      }

      // Home page controllers
      if (!Get.isRegistered<HomeController>()) {
        Get.put<HomeController>(HomeController(), permanent: true);
      }

      if (!Get.isRegistered<StoriesHomeController>()) {
        Get.put<StoriesHomeController>(
          StoriesHomeController(),
          permanent: true,
        );
      }

      if (!Get.isRegistered<PostsFeedController>()) {
        Get.put<PostsFeedController>(PostsFeedController(), permanent: true);
      }

      // Profile controller
      if (!Get.isRegistered<ProfileController>()) {
        Get.put<ProfileController>(ProfileController(), permanent: true);
      }

      // Chat controller
      if (!Get.isRegistered<ChatController>()) {
        Get.put<ChatController>(ChatController(), permanent: true);
      }

      // Create controller
      if (!Get.isRegistered<CreateController>()) {
        Get.put<CreateController>(CreateController(), permanent: true);
      }

      controllersPreloaded.value = true;
      debugPrint('$_tag: Page controllers preloaded');
    } catch (e) {
      debugPrint('$_tag: Error preloading page controllers: $e');
    }
  }

  /// Preload initial data for all main pages
  Future<void> _preloadInitialData() async {
    currentPreloadingStep.value = 'Loading initial data...';
    debugPrint('$_tag: Preloading initial data');

    try {
      // Check if user is authenticated before preloading data
      final supabaseService = Get.find<SupabaseService>();
      if (!supabaseService.isAuthenticated.value) {
        debugPrint('$_tag: User not authenticated, skipping data preload');
        return;
      }

      // Preload feed data (already implemented)
      await FeedLoaderService.preloadFeed();

      // Preload profile data
      await _preloadProfileData();

      // Preload chat data
      await _preloadChatData();

      dataPreloaded.value = true;
      debugPrint('$_tag: Initial data preloaded');
    } catch (e) {
      debugPrint('$_tag: Error preloading initial data: $e');
    }
  }

  /// Preload profile data
  Future<void> _preloadProfileData() async {
    try {
      final supabaseService = Get.find<SupabaseService>();
      final userId = supabaseService.currentUser.value?.id;

      if (userId == null) {
        debugPrint(
          '$_tag: Cannot preload profile data - user not authenticated',
        );
        return;
      }

      // Load profile data directly through AccountDataProvider
      final accountDataProvider = Get.find<AccountDataProvider>();

      // Fetch fresh user data from database
      final userData = await accountDataProvider.fetchUserData();
      if (userData.isNotEmpty) {
        // Update all user data fields
        accountDataProvider.username.value = userData['username'] ?? '';
        accountDataProvider.nickname.value = userData['nickname'] ?? '';
        accountDataProvider.bio.value = userData['bio'] ?? '';
        accountDataProvider.avatar.value = userData['avatar'] ?? '';
        accountDataProvider.banner.value = userData['banner'] ?? '';
        accountDataProvider.email.value = userData['email'] ?? '';
        accountDataProvider.googleAvatar.value =
            userData['google_avatar'] ?? '';

        debugPrint('$_tag: Profile data preloaded successfully');
        debugPrint('  Username: ${accountDataProvider.username.value}');
        debugPrint('  Nickname: ${accountDataProvider.nickname.value}');
        debugPrint('  Avatar: ${accountDataProvider.avatar.value}');
        debugPrint(
          '  Google Avatar: ${accountDataProvider.googleAvatar.value}',
        );
      } else {
        debugPrint('$_tag: No profile data found');
      }
    } catch (e) {
      debugPrint('$_tag: Error preloading profile data: $e');
    }
  }

  /// Preload chat data
  Future<void> _preloadChatData() async {
    try {
      final chatController = Get.find<ChatController>();
      // Preload recent chats
      await chatController.preloadRecentChats();

      // Preload groups data
      await _preloadGroupsData();

      debugPrint('$_tag: Chat data preloaded');
    } catch (e) {
      debugPrint('$_tag: Error preloading chat data: $e');
    }
  }

  /// Preload groups data
  Future<void> _preloadGroupsData() async {
    try {
      // Get or create GroupController
      GroupController groupController;
      if (Get.isRegistered<GroupController>()) {
        groupController = Get.find<GroupController>();
      } else {
        groupController = GroupController();
        Get.put(groupController, permanent: true);
      }

      // Load user groups
      await groupController.loadUserGroups();
      debugPrint('$_tag: Groups data preloaded');
    } catch (e) {
      debugPrint('$_tag: Error preloading groups data: $e');
    }
  }

  /// Warm up various caches
  Future<void> _warmupCaches() async {
    currentPreloadingStep.value = 'Warming up caches...';
    debugPrint('$_tag: Warming up caches');

    try {
      // Warm up account data provider cache
      final accountDataProvider = Get.find<AccountDataProvider>();
      await accountDataProvider.preloadUserData();

      debugPrint('$_tag: Caches warmed up');
    } catch (e) {
      debugPrint('$_tag: Error warming up caches: $e');
    }
  }

  /// Check if a specific controller is preloaded
  bool isControllerPreloaded<T>() {
    return Get.isRegistered<T>();
  }

  /// Force refresh of preloaded data
  Future<void> refreshPreloadedData() async {
    if (!isPreloaded.value) return;

    debugPrint('$_tag: Refreshing preloaded data');
    dataPreloaded.value = false;
    await _preloadInitialData();
  }

  /// Clear all preloaded data and controllers
  void clearPreloadedData() {
    debugPrint('$_tag: Clearing preloaded data');

    isPreloaded.value = false;
    controllersPreloaded.value = false;
    dataPreloaded.value = false;
    repositoriesPreloaded.value = false;
    preloadingProgress.value = 0.0;

    // Note: We don't delete permanent controllers as they should persist
    // across app lifecycle for optimal performance
  }

  /// Get preloading status summary
  Map<String, dynamic> getPreloadingStatus() {
    return {
      'isPreloading': isPreloading.value,
      'isPreloaded': isPreloaded.value,
      'controllersPreloaded': controllersPreloaded.value,
      'dataPreloaded': dataPreloaded.value,
      'repositoriesPreloaded': repositoriesPreloaded.value,
      'progress': preloadingProgress.value,
      'currentStep': currentPreloadingStep.value,
    };
  }
}

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';

class StoriesHomeController extends GetxController {
  final SupabaseService _supabase = Get.find<SupabaseService>();
  final StoryRepository _storyRepository = Get.find<StoryRepository>();
  final AccountDataProvider _accountProvider = Get.find<AccountDataProvider>();

  // Observable lists
  final RxList<StoryUser> usersWithStories = <StoryUser>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasCurrentUserStory = false.obs;
  final RxBool hasCurrentUserUnseenStory = false.obs;
  final RxString currentUserId = ''.obs;
  final RxBool hasLoadedOnce = false.obs;

  // Cache management
  DateTime? _lastStoriesLoad;
  static const Duration _storiesCacheDuration = Duration(minutes: 5);

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';
    loadStoriesData();
  }

  /// Load all stories data for home screen
  Future<void> loadStoriesData({bool forceRefresh = false}) async {
    try {
      // Check if we should use cached data
      if (!forceRefresh && _lastStoriesLoad != null && hasLoadedOnce.value) {
        final timeSinceLastLoad = DateTime.now().difference(_lastStoriesLoad!);
        if (timeSinceLastLoad < _storiesCacheDuration) {
          debugPrint('Using cached stories data');
          return;
        }
      }

      // Only show loading on first load or force refresh
      if (!hasLoadedOnce.value || forceRefresh) {
        isLoading.value = true;
      }

      // Load followers with their story status
      await loadFollowingUsersWithStories();

      // Check if current user has active story
      await checkCurrentUserStory();

      hasLoadedOnce.value = true;
      _lastStoriesLoad = DateTime.now();
    } catch (e) {
      debugPrint('Error loading stories data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load stories from users who follow the current user
  Future<void> loadFollowingUsersWithStories() async {
    try {
      if (currentUserId.value.isEmpty) return;

      // First, load the current user's followers (this method has its own caching)
      await _accountProvider.loadFollowers(currentUserId.value);

      // Get the list of follower user IDs
      final followerIds =
          _accountProvider.followers
              .map((follower) => follower['user_id'] as String)
              .toList();

      if (followerIds.isEmpty) {
        usersWithStories.clear();
        return;
      }

      // Get stories from followers who have active stories
      final storiesResponse = await _supabase.client
          .from('stories')
          .select('''
            user_id,
            id,
            created_at,
            expires_at,
            viewers,
            is_active,
            profiles(
              user_id,
              username,
              nickname,
              avatar
            )
          ''')
          .inFilter('user_id', followerIds)
          .eq('is_active', true)
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      // Group stories by user
      final Map<String, List<Map<String, dynamic>>> userStoriesMap = {};
      final Map<String, Map<String, dynamic>> userProfilesMap = {};

      for (final story in storiesResponse) {
        final userId = story['user_id'];
        final profile = story['profiles'];

        if (profile != null) {
          userProfilesMap[userId] = profile;

          if (!userStoriesMap.containsKey(userId)) {
            userStoriesMap[userId] = [];
          }
          userStoriesMap[userId]!.add(story);
        }
      }

      final List<StoryUser> users = [];

      for (final userId in userStoriesMap.keys) {
        final userStories = userStoriesMap[userId]!;
        final profile = userProfilesMap[userId]!;

        final hasActiveStory = userStories.isNotEmpty;
        bool hasUnseenStory = false;

        if (hasActiveStory) {
          // Check if any story hasn't been viewed by current user
          for (final story in userStories) {
            final viewers = List<String>.from(story['viewers'] ?? []);
            if (!viewers.contains(currentUserId.value)) {
              hasUnseenStory = true;
              break;
            }
          }
        }

        users.add(
          StoryUser(
            userId: userId,
            username: profile['username'] ?? '',
            nickname: profile['nickname'] ?? '',
            avatar: profile['avatar'],
            hasActiveStory: hasActiveStory,
            latestStoryAt:
                hasActiveStory
                    ? DateTime.parse(userStories.first['created_at'])
                    : null,
            hasUnseenStory: hasUnseenStory,
          ),
        );
      }

      usersWithStories.assignAll(users);
    } catch (e) {
      debugPrint('Error loading followers with stories: $e');
    }
  }

  /// Check if current user has active story
  Future<void> checkCurrentUserStory() async {
    try {
      if (currentUserId.value.isEmpty) return;

      final stories = await _storyRepository.getUserStories(
        currentUserId.value,
      );
      hasCurrentUserStory.value = stories.isNotEmpty;

      // Check if current user has unseen stories (stories they haven't viewed themselves)
      if (stories.isNotEmpty) {
        // Check if any of the user's stories haven't been viewed by themselves
        bool hasUnseen = false;
        for (final story in stories) {
          if (!story.viewers.contains(currentUserId.value)) {
            hasUnseen = true;
            break;
          }
        }
        hasCurrentUserUnseenStory.value = hasUnseen;
      } else {
        hasCurrentUserUnseenStory.value = false;
      }
    } catch (e) {
      debugPrint('Error checking current user story: $e');
      // If there's an error, assume user has unseen stories if they have stories
      hasCurrentUserUnseenStory.value = hasCurrentUserStory.value;
    }
  }

  /// Navigate to create story
  void navigateToCreateStory() {
    Get.toNamed('/create-story');
  }

  /// Navigate to view stories for a specific user
  void navigateToViewStories(String userId) {
    Get.toNamed('/view-stories', parameters: {'userId': userId});
  }

  /// Refresh stories data
  Future<void> refreshStories() async {
    await loadStoriesData(forceRefresh: true);

    // Force update of reactive variables
    usersWithStories.refresh();
    hasCurrentUserStory.refresh();
    hasCurrentUserUnseenStory.refresh();

    // Force UI update
    update();
  }

  /// Force update UI immediately
  void forceUpdate() {
    usersWithStories.refresh();
    hasCurrentUserStory.refresh();
    hasCurrentUserUnseenStory.refresh();
    update();
  }

  /// Clear stories cache and reload
  Future<void> clearCacheAndReload() async {
    _lastStoriesLoad = null;
    hasLoadedOnce.value = false;
    await loadStoriesData(forceRefresh: true);
  }
}

/// Model for user with story status
class StoryUser {
  final String userId;
  final String username;
  final String nickname;
  final String? avatar;
  final bool hasActiveStory;
  final DateTime? latestStoryAt;
  final bool hasUnseenStory;

  StoryUser({
    required this.userId,
    required this.username,
    required this.nickname,
    this.avatar,
    required this.hasActiveStory,
    this.latestStoryAt,
    required this.hasUnseenStory,
  });

  factory StoryUser.fromMap(Map<String, dynamic> map) {
    return StoryUser(
      userId: map['user_id'] ?? '',
      username: map['username'] ?? '',
      nickname: map['nickname'] ?? '',
      avatar: map['avatar'],
      hasActiveStory: map['has_active_story'] ?? false,
      latestStoryAt:
          map['latest_story_at'] != null
              ? DateTime.parse(map['latest_story_at'])
              : null,
      hasUnseenStory: map['has_unseen_story'] ?? false,
    );
  }
}

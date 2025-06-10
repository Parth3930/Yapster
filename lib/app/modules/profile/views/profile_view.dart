import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../controllers/profile_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';

import 'package:yapster/app/modules/profile/controllers/profile_posts_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_post_widget_factory.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';

class ProfileView extends GetView<ProfileController> {
  final String? userId;
  final RxInt selectedTabIndex = 0.obs;

  // Track counts loading state per user to prevent "..." flicker
  static final Map<String, RxBool> _countsLoadedCache = <String, RxBool>{};

  // Track if initial data has been loaded to avoid repeated database calls
  static final Map<String, bool> _initialDataLoaded = <String, bool>{};

  // Story status tracking
  final RxBool hasStory = false.obs;
  final RxBool hasUnseenStory = false.obs;

  // Get reactive counts loaded state for current user
  RxBool get countsLoaded {
    final key = userId ?? 'current';
    if (!_countsLoadedCache.containsKey(key)) {
      _countsLoadedCache[key] = RxBool(false);
    }
    return _countsLoadedCache[key]!;
  }

  ProfileView({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();
    final exploreController = Get.find<ExploreController>();
    final bool isCurrentUser =
        userId == null ||
        userId == Get.find<SupabaseService>().currentUser.value?.id;

    // Get a unique key for this profile instance based on user ID
    final String cacheKey = userId ?? 'current_user';

    // Load data only once when the view is first built for this specific user
    if (!_initialDataLoaded.containsKey(cacheKey) ||
        _initialDataLoaded[cacheKey] != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (isCurrentUser) {
          final currentUserId =
              Get.find<SupabaseService>().currentUser.value?.id;
          if (currentUserId != null) {
            // CRITICAL FIX: Debug current data state
            debugPrint('=== PROFILE VIEW DEBUG ===');
            debugPrint('Current user data state:');
            debugPrint('  Username: ${accountDataProvider.username.value}');
            debugPrint('  Nickname: ${accountDataProvider.nickname.value}');
            debugPrint('  Bio: ${accountDataProvider.bio.value}');
            debugPrint('  Avatar: ${accountDataProvider.avatar.value}');
            debugPrint(
              '  Google Avatar: ${accountDataProvider.googleAvatar.value}',
            );
            debugPrint('  Posts count: ${accountDataProvider.posts.length}');
            debugPrint(
              '  Followers count: ${accountDataProvider.followers.length}',
            );
            debugPrint(
              '  Following count: ${accountDataProvider.following.length}',
            );

            // CRITICAL FIX: Force load user data if empty
            if (accountDataProvider.username.value.isEmpty ||
                accountDataProvider.nickname.value.isEmpty) {
              debugPrint('User data is empty, forcing reload...');
              await accountDataProvider.preloadUserData();
            }

            // OPTIMIZATION: Check if we have any cached counts
            final hasFollowerCount =
                accountDataProvider.followerCount.value >= 0;
            final hasFollowingCount =
                accountDataProvider.followingCount.value >= 0;
            final hasCachedCounts = hasFollowerCount && hasFollowingCount;

            // Show counts immediately if we have cached data
            if (hasCachedCounts) {
              countsLoaded.value = true;
              debugPrint('Using cached follower/following counts immediately');
            }

            // Only refresh from database if we have no cached data
            if (!hasCachedCounts) {
              debugPrint('No cached counts found, loading fresh data');
              // Clear stale caches first to prevent showing wrong values
              accountDataProvider.clearFollowCaches(currentUserId);

              // Refresh follow counts from accurate source
              await accountDataProvider.refreshFollowCounts(currentUserId);

              // Force load fresh data to update caches
              await accountDataProvider.loadFollowers(currentUserId);
              await accountDataProvider.loadFollowing(currentUserId);

              // Mark counts as loaded after fresh data is loaded
              countsLoaded.value = true;
            }

            // CRITICAL FIX: Ensure posts are loaded
            if (accountDataProvider.posts.isEmpty) {
              await accountDataProvider.loadUserPosts(currentUserId);
            }
          }
        } else {
          // For other users, check if we have cached profile data
          if (userId != null) {
            // Check if we already have profile data cached
            final hasProfileData =
                exploreController.selectedUserProfile.isNotEmpty &&
                exploreController.selectedUserProfile['user_id'] == userId;

            if (hasProfileData) {
              // Show counts immediately if we have cached profile data
              countsLoaded.value = true;
              debugPrint('Using cached profile data for user: $userId');
            } else {
              // Load fresh profile data if not cached
              await exploreController.loadUserProfile(userId!);
              countsLoaded.value = true;
            }
          }
        }

        // Check story status for the user
        await _checkStoryStatus();

        // Mark initial data as loaded to prevent repeated loading
        _initialDataLoaded[cacheKey] = true;
      });
    }

    // Optimized loading - only preload essential data
    Future.microtask(() {
      final cacheKey = userId ?? 'current';
      if (!_initialDataLoaded.containsKey(cacheKey)) {
        // Mark as loaded immediately to prevent duplicate loading
        _initialDataLoaded[cacheKey] = true;

        // Set avatar as loaded immediately for faster UI
        controller.isAvatarLoaded.value = true;

        // Skip heavy preloading operations for speed
        // Images will load on-demand with caching
      }
    });

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Obx(() {
                    String bannerUrl =
                        isCurrentUser
                            ? accountDataProvider.banner.value
                            : exploreController.selectedUserProfile['banner'] ??
                                '';

                    if (bannerUrl.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 150, // Fixed height to match parent container
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  Container(color: Colors.grey[800]),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey[800],
                                child: Icon(Icons.error, color: Colors.white),
                              ),
                          imageBuilder: (context, imageProvider) {
                            return Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
                // Avatar section positioned 100px from top
                Container(
                  margin: EdgeInsets.only(top: 100), // Position 100px from top
                  child: Obx(() {
                    // Get avatar and Google avatar URLs based on whether it's current user or another user
                    final avatarUrl =
                        isCurrentUser
                            ? accountDataProvider.avatar.value
                            : exploreController.selectedUserProfile['avatar'] ??
                                '';
                    final googleAvatarUrl =
                        isCurrentUser
                            ? accountDataProvider.googleAvatar.value
                            : exploreController
                                    .selectedUserProfile['google_avatar'] ??
                                '';

                    return Obx(
                      () => ProfileAvatarWidget(
                        selectedImage: null,
                        imageUrl: avatarUrl,
                        googleAvatarUrl: googleAvatarUrl,
                        onTap: () {
                          if (isCurrentUser) {
                            if (hasStory.value) {
                              // View own stories
                              Get.toNamed(
                                Routes.VIEW_STORIES,
                                parameters: {
                                  'userId':
                                      Get.find<SupabaseService>()
                                          .currentUser
                                          .value
                                          ?.id ??
                                      '',
                                },
                              );
                            } else {
                              // Create new story
                              Get.toNamed(Routes.CREATE_STORY);
                            }
                          } else {
                            if (hasStory.value) {
                              // View other user's stories
                              Get.toNamed(
                                Routes.VIEW_STORIES,
                                parameters: {'userId': userId ?? ''},
                              );
                            }
                          }
                        },
                        radius: 45,
                        isLoaded: true,
                        hasStory: hasStory.value,
                        hasUnseenStory: hasUnseenStory.value,
                        showAddButton:
                            isCurrentUser &&
                            !hasStory
                                .value, // Show add button only for current user when no story
                      ),
                    );
                  }),
                ),
              ],
            ),
            // Content below avatar with reduced top margin
            Container(
              margin: EdgeInsets.only(top: 20),
              child: GetX<AccountDataProvider>(
                builder:
                    (provider) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Nickname with edit icon
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Nickname text centered
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                isCurrentUser
                                    ? (provider.nickname.value.isNotEmpty
                                        ? provider.nickname.value
                                        : 'No Nickname')
                                    : _getDisplayNickname(exploreController),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ), // Edit icon positioned to the right
                            if (isCurrentUser)
                              Positioned(
                                right: 0,
                                child: GestureDetector(
                                  onTapDown:
                                      (_) =>
                                          controller.isEditPressed.value = true,
                                  onTapUp: (_) {
                                    controller.isEditPressed.value = false;
                                    Get.toNamed(Routes.EDIT_PROFILE);
                                  },
                                  onTapCancel:
                                      () =>
                                          controller.isEditPressed.value =
                                              false,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    child: Obx(
                                      () => AnimatedScale(
                                        scale:
                                            controller.isEditPressed.value
                                                ? 0.8
                                                : 1.0,
                                        duration: Duration(milliseconds: 100),
                                        curve: Curves.easeInOut,
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Username text
                        Text(
                          isCurrentUser
                              ? (provider.username.value.isNotEmpty
                                  ? '@${provider.username.value}'
                                  : '@username')
                              : (exploreController
                                          .selectedUserProfile['username'] !=
                                      null
                                  ? '@${exploreController.selectedUserProfile['username']}'
                                  : '@username'),
                          style: TextStyle(fontSize: 15, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        // Bio text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            isCurrentUser
                                ? (provider.bio.value.isNotEmpty
                                    ? provider.bio.value
                                    : 'No bio yet')
                                : (exploreController.selectedUserProfile['bio']
                                        ?.toString() ??
                                    'No bio yet'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
            SizedBox(height: 20),
            // Stats row for Posts, Followers, Following
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Obx(() {
                        // Get the post count from the appropriate source
                        final postCount =
                            isCurrentUser
                                ? accountDataProvider.postsCount
                                : (exploreController
                                            .selectedUserProfile['post_count']
                                        as int?) ??
                                    0;

                        return _buildStatColumn(
                          postCount.toString(),
                          'Posts',
                          onTap: () {
                            // Handle posts tap if needed
                          },
                        );
                      }),
                    ),
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black, Color(0xFFCCCCCC), Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Obx(() {
                        // Only show counts after they're properly loaded to prevent stutter
                        if (!countsLoaded.value) {
                          return _buildStatColumn(
                            '...',
                            'Followers',
                            onTap: () {},
                          );
                        }

                        // Get the followers count from the appropriate source
                        final followersCount =
                            isCurrentUser
                                ? accountDataProvider.followerCount.value
                                : (exploreController
                                            .selectedUserProfile['follower_count']
                                        as int?) ??
                                    0;

                        debugPrint(
                          'ProfileView: Displaying followers count for ${isCurrentUser ? "current user" : "user $userId"}: $followersCount',
                        );
                        if (isCurrentUser) {
                          debugPrint(
                            '  - Source: AccountDataProvider.followerCount = ${accountDataProvider.followerCount.value}',
                          );
                        } else {
                          debugPrint(
                            '  - Source: ExploreController.selectedUserProfile[follower_count] = ${exploreController.selectedUserProfile['follower_count']}',
                          );
                        }

                        return _buildStatColumn(
                          followersCount.toString(),
                          'Followers',
                          onTap: () {
                            Get.toNamed(
                              Routes.FOLLOWERS,
                              arguments: {
                                'userId': isCurrentUser ? null : userId,
                              },
                            );
                          },
                        );
                      }),
                    ),
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black, Color(0xFFCCCCCC), Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Obx(() {
                        // Only show counts after they're properly loaded to prevent stutter
                        if (!countsLoaded.value) {
                          return _buildStatColumn(
                            '...',
                            'Following',
                            onTap: () {},
                          );
                        }

                        // Get the following count from the appropriate source
                        final followingCount =
                            isCurrentUser
                                ? accountDataProvider.followingCount.value
                                : (exploreController
                                            .selectedUserProfile['following_count']
                                        as int?) ??
                                    0;

                        debugPrint(
                          'ProfileView: Displaying following count for ${isCurrentUser ? "current user" : "user $userId"}: $followingCount',
                        );
                        if (isCurrentUser) {
                          debugPrint(
                            '  - Source: AccountDataProvider.followingCount = ${accountDataProvider.followingCount.value}',
                          );
                        } else {
                          debugPrint(
                            '  - Source: ExploreController.selectedUserProfile[following_count] = ${exploreController.selectedUserProfile['following_count']}',
                          );
                        }

                        return _buildStatColumn(
                          followingCount.toString(),
                          'Following',
                          onTap: () {
                            Get.toNamed(
                              Routes.FOLLOWING,
                              arguments: {
                                'userId': isCurrentUser ? null : userId,
                              },
                            );
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Tab buttons
            // Add follow and message buttons if this is not the current user's profile
            _buildActionButtons(context),
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF242424), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => selectedTabIndex.value = 0,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Posts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => selectedTabIndex.value = 1,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Videos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => selectedTabIndex.value = 2,
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Threads',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  final tabWidth = MediaQuery.of(context).size.width / 3;
                  final center =
                      tabWidth * selectedTabIndex.value + (tabWidth / 2);
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(selectedTabIndex.value),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, _) {
                      return Positioned(
                        bottom: 0,
                        left: center - (18 * value),
                        child: Container(
                          width: 36 * value,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
            // Tab content
            SizedBox(
              height:
                  MediaQuery.of(context).size.height *
                  0.6, // Give it a fixed height
              child: Obx(() {
                switch (selectedTabIndex.value) {
                  case 0:
                    return _buildPostsTab();
                  case 1:
                    return _buildVideosTab();
                  case 2:
                    return _buildThreadsTab();
                  default:
                    return _buildPostsTab();
                }
              }),
            ),
          ],
        ),
      ),
      extendBody: true,
      floatingActionButton: BottomNavigation(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // Helper method to build stat columns (Posts, Followers, Following)
  Widget _buildStatColumn(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(Get.context!).size.width / 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build follow and message buttons
  Widget _buildActionButtons(BuildContext context) {
    // Use the class-level 'userId' and 'isCurrentUser' instead of Get.parameters
    if (isCurrentUser || userId == null) {
      return SizedBox.shrink();
    }

    final exploreController = Get.find<ExploreController>();

    // Use cached state first
    final initialFollowState = exploreController.isFollowingUser(userId!);
    debugPrint(
      'ProfileView: Initial follow state for $userId: $initialFollowState',
    );

    final RxBool isFollowing = RxBool(initialFollowState);
    final RxBool isLoadingFollow = RxBool(false);

    // OPTIMIZATION: Only refresh follow state if absolutely necessary
    Future.microtask(() async {
      // Only refresh if we have no cached data at all
      final hasCachedFollowState =
          exploreController.isFollowingUser(userId!) != false ||
          exploreController.hasFollowStateCached(userId!);

      if (!isLoadingFollow.value && userId != null && !hasCachedFollowState) {
        try {
          debugPrint(
            'No cached follow state found, refreshing for user: $userId',
          );
          final actualFollowState = await exploreController.refreshFollowState(
            userId!,
            forceRefresh: false, // Use cache-friendly refresh
          );
          if (actualFollowState != isFollowing.value) {
            isFollowing.value = actualFollowState;
          }
        } catch (e) {
          debugPrint('Error refreshing follow state in ProfileView: $e');
        }
      } else {
        debugPrint('Using cached follow state for user: $userId');
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => ElevatedButton(
                onPressed:
                    isLoadingFollow.value
                        ? null
                        : () async {
                          if (userId == null) return;
                          isLoadingFollow.value = true;

                          final initialState = isFollowing.value;
                          debugPrint(
                            'ProfileView: Follow button pressed. Initial state: $initialState',
                          );

                          try {
                            // Update local state immediately for better UX
                            isFollowing.value = !isFollowing.value;
                            debugPrint(
                              'ProfileView: Optimistically updated to: ${isFollowing.value}',
                            );

                            // Update follow status in database
                            await exploreController.toggleFollowUser(userId!);

                            // After the operation, get the actual follow state from the controller
                            final actualFollowState = exploreController
                                .isFollowingUser(userId!);
                            debugPrint(
                              'ProfileView: Actual state after operation: $actualFollowState',
                            );

                            // Update local state to match the actual state
                            isFollowing.value = actualFollowState;
                            debugPrint(
                              'ProfileView: Final state set to: ${isFollowing.value}',
                            );

                            // SMART CACHE MANAGEMENT: Counts will be updated automatically
                            // by the ExploreController's cache management system
                            debugPrint(
                              'ProfileView: Follow action completed - cache updated automatically',
                            );
                          } catch (e) {
                            // Revert local state if there was an error
                            debugPrint('Error toggling follow: $e');
                            isFollowing.value = !isFollowing.value;
                            // Show error to user
                            Get.snackbar(
                              'Error',
                              'Failed to update follow status. Please try again.',
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          } finally {
                            isLoadingFollow.value = false;
                          }
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFollowing.value ? Colors.grey[800] : Color(0xff0060FF),
                  minimumSize: Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Obx(() {
                  final buttonText =
                      isLoadingFollow.value
                          ? "Processing..."
                          : isFollowing.value
                          ? "Following"
                          : "Follow";

                  debugPrint(
                    'ProfileView: Button text for $userId: $buttonText (isFollowing: ${isFollowing.value})',
                  );

                  return Text(
                    buttonText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: GoogleFonts.inter().fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (userId == null) return;

                // Get the current user ID
                final currentUser =
                    Get.find<SupabaseService>().currentUser.value;
                if (currentUser == null) {
                  Get.snackbar(
                    'Error',
                    'You need to be logged in to send messages',
                  );
                  return;
                }

                try {
                  // Get the other user's username from the explore controller or parameters
                  final exploreController = Get.find<ExploreController>();

                  // Debug print to check the selectedUserProfile
                  debugPrint(
                    'Selected User Profile: ${exploreController.selectedUserProfile}',
                  );

                  final otherUsername =
                      exploreController.selectedUserProfile['username']
                          ?.toString() ??
                      'User';

                  // Debug print to check user IDs
                  debugPrint('Current User ID: ${currentUser.id}');
                  debugPrint('Other User ID: $userId');

                  try {
                    // Get the chat controller
                    final chatController = Get.find<ChatController>();

                    // Open or create a chat with the user
                    chatController.openChat(userId!, otherUsername);
                  } catch (e) {
                    debugPrint('Error in chat navigation: $e');
                    Get.snackbar(
                      'Error',
                      'Could not start chat. Please try again.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error navigating to chat: $e');
                  debugPrint('Stack trace: $stackTrace');
                  Get.snackbar(
                    'Error',
                    'Could not start chat. Please try again.',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF171717),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab content builders
  Widget _buildPostsTab() {
    // Create or get the ProfilePostsController
    final profilePostsController = Get.put(
      ProfilePostsController(),
      tag: 'profile_posts_${userId ?? 'current'}',
    );

    final currentUserId = Get.find<SupabaseService>().currentUser.value?.id;
    final targetUserId = isCurrentUser ? currentUserId ?? '' : userId ?? '';

    // OPTIMIZATION: Check if posts are already cached using the cache service
    final cacheService = Get.find<UserPostsCacheService>();
    final hasCachedPosts = cacheService.hasCachedPosts(targetUserId);
    final hasPostsInController = profilePostsController.profilePosts.isNotEmpty;
    final isTargetCurrentUser = targetUserId == currentUserId;

    // For other users, only load once and don't cache
    if (!isTargetCurrentUser) {
      // Check if we've already attempted to load posts for this user
      final hasAttempted = profilePostsController.hasLoadAttempted(
        targetUserId,
      );
      if (!hasPostsInController &&
          !profilePostsController.isLoading.value &&
          !hasAttempted) {
        debugPrint('Loading posts once for other user: $targetUserId');
        Future.microtask(() {
          profilePostsController.loadUserPosts(targetUserId);
        });
      } else {
        debugPrint(
          'Posts already loaded, loading, or attempted for other user: $targetUserId (attempted: $hasAttempted)',
        );
      }
    } else {
      // For current user, use caching logic
      if (!hasCachedPosts &&
          !hasPostsInController &&
          !profilePostsController.isLoading.value) {
        debugPrint(
          'No cached posts found, loading for current user: $targetUserId',
        );
        Future.microtask(() {
          profilePostsController.loadUserPosts(targetUserId);
        });
      } else if (hasCachedPosts && !hasPostsInController) {
        debugPrint(
          'Loading cached posts instantly for current user: $targetUserId',
        );
        // Load cached posts immediately and synchronously
        _loadCachedPostsInstantly(
          profilePostsController,
          cacheService,
          targetUserId,
        );
      } else {
        debugPrint(
          'Using existing posts data for current user: $targetUserId (cached: $hasCachedPosts, controller: $hasPostsInController)',
        );
      }
    }

    return Obx(() {
      final posts = profilePostsController.profilePosts;

      // Show loading only if we have no cached posts and are currently loading
      if (posts.isEmpty && profilePostsController.isLoading.value) {
        return Center(child: CircularProgressIndicator(color: Colors.white));
      }

      if (posts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.post_add_outlined, size: 64, color: Colors.grey[600]),
              SizedBox(height: 16),
              Text(
                isCurrentUser ? 'No posts yet' : 'No posts to show',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              if (isCurrentUser) ...[
                SizedBox(height: 8),
                Text(
                  'Create your first post!',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ],
          ),
        );
      }

      // Show cached posts immediately
      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return ProfilePostWidgetFactory.createPostWidget(
            post: post,
            controller: profilePostsController,
          );
        },
      );
    });
  }

  Widget _buildVideosTab() {
    return Center(
      child: Text(
        'Videos content coming soon',
        style: TextStyle(color: Colors.grey[400], fontSize: 16),
      ),
    );
  }

  Widget _buildThreadsTab() {
    // Create or get the ProfilePostsController
    final profilePostsController = Get.put(
      ProfilePostsController(),
      tag: 'profile_threads_${userId ?? 'current'}',
    );

    final targetUserId =
        isCurrentUser
            ? Get.find<SupabaseService>().currentUser.value?.id ?? ''
            : userId ?? '';

    return FutureBuilder<void>(
      future: profilePostsController.loadUserPosts(targetUserId),
      builder: (context, snapshot) {
        return Obx(() {
          if (profilePostsController.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final allPosts = profilePostsController.profilePosts;
          // Filter for text posts only
          final textPosts =
              allPosts
                  .where((post) => post.postType.toLowerCase() == 'text')
                  .toList();

          if (textPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.text_fields, size: 64, color: Colors.grey[600]),
                  SizedBox(height: 16),
                  Text(
                    isCurrentUser
                        ? 'No text posts yet'
                        : 'No text posts to show',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  if (isCurrentUser) ...[
                    SizedBox(height: 8),
                    Text(
                      'Create your first text post!',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: textPosts.length,
            itemBuilder: (context, index) {
              final post = textPosts[index];
              return ProfilePostWidgetFactory.createPostWidget(
                post: post,
                controller: profilePostsController,
              );
            },
          );
        });
      },
    );
  }

  // Helper method to load cached posts instantly without async delay
  void _loadCachedPostsInstantly(
    ProfilePostsController profilePostsController,
    UserPostsCacheService cacheService,
    String targetUserId,
  ) {
    try {
      // Get cached posts synchronously from the cache service
      final cachedPosts = cacheService.getCachedPosts(targetUserId);
      if (cachedPosts.isNotEmpty) {
        // Load posts immediately into the controller
        profilePostsController.profilePosts.assignAll(cachedPosts);
        debugPrint(
          'Instantly loaded ${cachedPosts.length} cached posts for user: $targetUserId',
        );

        // Load engagement states in background without blocking UI
        Future.microtask(() async {
          await profilePostsController.loadEngagementStatesForCachedPosts(
            cachedPosts,
          );
        });
      } else {
        // If no cached posts, fall back to async loading
        Future.microtask(() {
          profilePostsController.loadUserPosts(targetUserId);
        });
      }
    } catch (e) {
      debugPrint('Error loading cached posts instantly: $e');
      // Fall back to async loading on error
      Future.microtask(() {
        profilePostsController.loadUserPosts(targetUserId);
      });
    }
  }

  // Helper method to get display nickname for other users
  String _getDisplayNickname(ExploreController exploreController) {
    final nickname =
        exploreController.selectedUserProfile['nickname']?.toString();

    // If nickname exists and is not empty, use it
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }

    // Otherwise, return 'Yapper' as fallback
    return 'Yapper';
  }

  // Add a getter for isCurrentUser to be used within the build method and _buildActionButtons
  bool get isCurrentUser =>
      userId == null ||
      userId == Get.find<SupabaseService>().currentUser.value?.id;

  // Check story status for the current user or other user
  Future<void> _checkStoryStatus() async {
    try {
      final storyRepository = Get.find<StoryRepository>();
      final currentUserId = Get.find<SupabaseService>().currentUser.value?.id;
      final targetUserId = isCurrentUser ? currentUserId : userId;

      if (targetUserId == null || targetUserId.isEmpty) {
        hasStory.value = false;
        hasUnseenStory.value = false;
        return;
      }

      // Get user's stories
      final stories = await storyRepository.getUserStories(targetUserId);
      hasStory.value = stories.isNotEmpty;

      if (stories.isNotEmpty) {
        // Check if any story hasn't been viewed by the current user
        bool hasUnseen = false;
        for (final story in stories) {
          if (isCurrentUser) {
            // For current user, check if they haven't viewed their own story
            if (!story.viewers.contains(currentUserId)) {
              hasUnseen = true;
              break;
            }
          } else {
            // For other users, check if current user hasn't viewed their stories
            if (!story.viewers.contains(currentUserId)) {
              hasUnseen = true;
              break;
            }
          }
        }
        hasUnseenStory.value = hasUnseen;
      } else {
        hasUnseenStory.value = false;
      }
    } catch (e) {
      debugPrint('Error checking story status: $e');
      hasStory.value = false;
      hasUnseenStory.value = false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/models/story_model.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../controllers/profile_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/core/utils/banner_utils.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';

class ProfileView extends GetView<ProfileController> {
  final String? userId;
  final RxInt selectedTabIndex = 0.obs;

  // Track if initial data has been loaded to avoid repeated database calls
  static final Map<String, bool> _initialDataLoaded = <String, bool>{};

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
            // Check cache timestamps in accountDataProvider before loading
            if (accountDataProvider.shouldRefreshFollowers(currentUserId)) {
              await accountDataProvider.loadFollowers(currentUserId);
              debugPrint('Loaded followers data from database');
            } else {
              debugPrint('Using cached followers data');
            }

            if (accountDataProvider.shouldRefreshFollowing(currentUserId)) {
              await accountDataProvider.loadFollowing(currentUserId);
              debugPrint('Loaded following data from database');
            } else {
              debugPrint('Using cached following data');
            }

            debugPrint(
              'Profile counts - Followers: ${accountDataProvider.followerCount}, Following: ${accountDataProvider.followingCount}',
            );
          }
        } else if (userId != null) {
          // For other users' profiles, only load if we don't have the data cached
          final userProfile = exploreController.selectedUserProfile;
          if (userProfile.isEmpty ||
              !userProfile.containsKey('follower_count')) {
            // We don't have this user's data - let the ExploreController handle loading it
            debugPrint(
              'No cached data for user $userId, letting ExploreController handle it',
            );
          }
        }

        // Mark initial data as loaded to prevent repeated loading
        _initialDataLoaded[cacheKey] = true;
      });
    }

    // This will run when the view is built or becomes visible after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Only preload if we haven't already done so for this user
      final cacheKey = userId ?? 'current';
      if (!_initialDataLoaded.containsKey(cacheKey) ||
          _initialDataLoaded[cacheKey] != true) {
        // Get avatar URLs using the utility method
        final avatars = AvatarUtils.getAvatarUrls(
          isCurrentUser: isCurrentUser,
          accountDataProvider: accountDataProvider,
          exploreController: exploreController,
        );

        // Preload avatars if available
        if (avatars['avatar']!.isNotEmpty ||
            avatars['google_avatar']!.isNotEmpty) {
          if (isCurrentUser) {
            AvatarUtils.preloadAvatarImages(accountDataProvider);
          }
          controller.isAvatarLoaded.value = true;
        }

        // Preload banner image
        if (isCurrentUser) {
          await BannerUtils.preloadBannerImages(accountDataProvider);
        } else if (exploreController.selectedUserProfile['banner'] != null) {
          // For other users, update the account data provider temporarily
          final tempProvider = AccountDataProvider();
          tempProvider.banner.value =
              exploreController.selectedUserProfile['banner'];
          await BannerUtils.preloadBannerImages(tempProvider);
        }

        _initialDataLoaded[cacheKey] = true;
      }
    });

    return Scaffold(
      body: Column(
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
                  debugPrint(
                    'Banner widget rebuilt at ${DateTime.now().toIso8601String()}',
                  );

                  String bannerUrl =
                      isCurrentUser
                          ? accountDataProvider.banner.value
                          : exploreController.selectedUserProfile['banner'] ??
                              '';

                  debugPrint('Banner URL: $bannerUrl');

                  if (bannerUrl.isEmpty) {
                    debugPrint('No banner URL available');
                  }

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

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      FutureBuilder<List<StoryModel>>(
                        future: Get.find<StoryRepository>().getUserStories(
                          isCurrentUser
                              ? Get.find<SupabaseService>()
                                      .currentUser
                                      .value
                                      ?.id ??
                                  ''
                              : userId ?? '',
                        ),
                        builder: (context, storySnapshot) {
                          final hasStories =
                              storySnapshot.hasData &&
                              storySnapshot.data!.isNotEmpty;

                          return ProfileAvatarWidget(
                            selectedImage: null,
                            imageUrl: avatarUrl,
                            googleAvatarUrl: googleAvatarUrl,
                            onTap: () {
                              if (hasStories) {
                                // Navigate to story viewer
                                Get.toNamed(
                                  Routes.VIEW_STORIES,
                                  parameters: {
                                    'userId':
                                        isCurrentUser
                                            ? Get.find<SupabaseService>()
                                                    .currentUser
                                                    .value
                                                    ?.id ??
                                                ''
                                            : userId ?? '',
                                  },
                                );
                              } else {
                                debugPrint('Profile image tapped - no stories');
                              }
                            },
                            radius: 45,
                            isLoaded: true,
                            hasStory: hasStories,
                            hasUnseenStory:
                                hasStories &&
                                !isCurrentUser, // Other users' stories are unseen
                            showAddButton:
                                false, // Don't show add button on profile page
                          );
                        },
                      ),
                      if (isCurrentUser)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                debugPrint(
                                  '+ button tapped - navigating to create story',
                                );
                                Get.toNamed(Routes.CREATE_STORY);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              isCurrentUser
                                  ? (provider.nickname.value.isNotEmpty
                                      ? provider.nickname.value
                                      : 'No Nickname')
                                  : (exploreController
                                          .selectedUserProfile['nickname']
                                          ?.toString() ??
                                      'No Nickname'),
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
                                        controller.isEditPressed.value = false,
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
                              ? accountDataProvider.posts.length
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
                      // Get the followers count from the appropriate source
                      final followersCount =
                          isCurrentUser
                              ? accountDataProvider.followers.length
                              : (exploreController
                                          .selectedUserProfile['follower_count']
                                      as int?) ??
                                  0;

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
                      // Get the following count from the appropriate source
                      final followingCount =
                          isCurrentUser
                              ? accountDataProvider.following.length
                              : (exploreController
                                          .selectedUserProfile['following_count']
                                      as int?) ??
                                  0;

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
                            'Stories',
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
                        onTap: () => selectedTabIndex.value = 3,
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
                final tabWidth = MediaQuery.of(context).size.width / 4;
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
          Expanded(
            child: Obx(() {
              switch (selectedTabIndex.value) {
                case 0:
                  return _buildPostsTab();
                case 1:
                  return _buildStoriesTab();
                case 2:
                  return _buildVideosTab();
                case 3:
                  return _buildThreadsTab();
                default:
                  return _buildPostsTab();
              }
            }),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(),
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
    final RxBool isFollowing = RxBool(
      exploreController.isFollowingUser(userId!),
    );
    final RxBool isLoadingFollow = RxBool(false);

    // Only check database state once when view is first built and not already cached
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Only refresh follow state if we don't have this user's complete profile data cached
      final shouldRefreshFollowState =
          !exploreController.selectedUserProfile.containsKey('user_id') ||
          exploreController.shouldRefreshFollowState(userId!);

      if (!isLoadingFollow.value &&
          userId != null &&
          shouldRefreshFollowState) {
        try {
          final actualFollowState = await exploreController.refreshFollowState(
            userId!,
          );
          if (actualFollowState != isFollowing.value) {
            isFollowing.value = actualFollowState;
          }
          // Mark this follow state as refreshed recently
          exploreController.markFollowStateRefreshed(userId!);
        } catch (e) {
          debugPrint('Error refreshing follow state in ProfileView: $e');
        }
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
                          try {
                            // Update local state immediately for better UX
                            isFollowing.value = !isFollowing.value;

                            // Update follow status in database
                            await exploreController.toggleFollowUser(userId!);

                            // Get current user's ID
                            final currentUserId =
                                Get.find<SupabaseService>()
                                    .currentUser
                                    .value
                                    ?.id;
                            if (currentUserId != null) {
                              // Asynchronously verify counts in database without blocking UI
                              Future.delayed(Duration.zero, () {
                                exploreController.verifyDatabaseCounts(
                                  currentUserId,
                                  userId!,
                                );
                              });
                            }
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
                child: Text(
                  isLoadingFollow.value
                      ? "Processing..."
                      : isFollowing.value
                      ? "Following"
                      : "Follow",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    return Center(
      child: Text(
        'Posts content coming soon',
        style: TextStyle(color: Colors.grey[400], fontSize: 16),
      ),
    );
  }

  Widget _buildStoriesTab() {
    final storyRepository = Get.find<StoryRepository>();

    return FutureBuilder<List<StoryModel>>(
      future: storyRepository.getUserStories(
        isCurrentUser
            ? Get.find<SupabaseService>().currentUser.value?.id ?? ''
            : userId ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading stories',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          );
        }

        final stories = snapshot.data ?? [];

        if (stories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
                SizedBox(height: 16),
                Text(
                  isCurrentUser ? 'No stories yet' : 'No stories to show',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                if (isCurrentUser) ...[
                  SizedBox(height: 8),
                  Text(
                    'Create your first story!',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            return GestureDetector(
              onTap: () {
                // Navigate to story viewer
                Get.toNamed(
                  Routes.VIEW_STORIES,
                  parameters: {
                    'userId': story.userId,
                    'storyIndex': index.toString(),
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      story.imageUrl != null
                          ? Image.network(
                            story.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[900],
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[600],
                                  size: 32,
                                ),
                              );
                            },
                          )
                          : Container(
                            color: Colors.grey[900],
                            child: Stack(
                              children: [
                                // Show text items if no image
                                ...story.textItems.asMap().entries.map((entry) {
                                  final textItem = entry.value;
                                  return Positioned(
                                    left:
                                        textItem.position.dx *
                                        0.3, // Scale down for preview
                                    top: textItem.position.dy * 0.3,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: textItem.backgroundColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        textItem.text.length > 20
                                            ? '${textItem.text.substring(0, 20)}...'
                                            : textItem.text,
                                        style: TextStyle(
                                          color: textItem.color,
                                          fontSize:
                                              textItem.fontSize *
                                              0.3, // Scale down
                                          fontWeight: textItem.fontWeight,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }),
                                if (story.textItems.isEmpty)
                                  Center(
                                    child: Icon(
                                      Icons.text_fields,
                                      color: Colors.grey[600],
                                      size: 32,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                ),
              ),
            );
          },
        );
      },
    );
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
    return Center(
      child: Text(
        'Threads content coming soon',
        style: TextStyle(color: Colors.grey[400], fontSize: 16),
      ),
    );
  }

  // Add a getter for isCurrentUser to be used within the build method and _buildActionButtons
  bool get isCurrentUser =>
      userId == null ||
      userId == Get.find<SupabaseService>().currentUser.value?.id;
}

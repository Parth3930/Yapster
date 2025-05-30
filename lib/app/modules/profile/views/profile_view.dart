import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../controllers/profile_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';

class ProfileView extends GetView<ProfileController> {
  final String? userId;
  final RxInt selectedTabIndex = 0.obs; // Add this line to track selected tab

  ProfileView({super.key, this.userId}); // Removed const keyword

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();
    final exploreController = Get.find<ExploreController>();
    final bool isCurrentUser =
        userId == null ||
        userId == Get.find<SupabaseService>().currentUser.value?.id;

    // Fetch user data based on whether it's the current user or another user
    if (!isCurrentUser && userId != null) {
      // Fetch complete profile data including accurate follow counts for the specified userId
      exploreController.loadUserProfile(userId!);
    } else if (isCurrentUser) {
      // For current user profile, ensure follow counts are up-to-date
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentUserId = Get.find<SupabaseService>().currentUser.value?.id;
        if (currentUserId != null) {
          await accountDataProvider.loadFollowers(currentUserId);
          await accountDataProvider.loadFollowing(currentUserId);
          debugPrint(
            'Updated current user follow counts - Followers: ${accountDataProvider.followerCount}, Following: ${accountDataProvider.followingCount}',
          );
        }
      });
    }

    // This will run when the view is built or becomes visible after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use a different data source if viewing another user's profile
      final avatar =
          isCurrentUser
              ? accountDataProvider.avatar.value
              : exploreController.selectedUserProfile['avatar'] ?? '';
      final googleAvatar =
          isCurrentUser
              ? accountDataProvider.googleAvatar.value
              : exploreController.selectedUserProfile['google_avatar'] ?? '';

      if (avatar.isNotEmpty || googleAvatar.isNotEmpty) {
        if (isCurrentUser) {
          AvatarUtils.preloadAvatarImages(accountDataProvider);
        }
        controller.isAvatarLoaded.value = true;
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
                child: Stack(
                  children: [
                    Obx(() {
                      final bannerUrl =
                          isCurrentUser
                              ? accountDataProvider.banner.value
                              : exploreController
                                      .selectedUserProfile['banner'] ??
                                  '';

                      if (bannerUrl.isEmpty) return const SizedBox.shrink();

                      return ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          errorWidget:
                              (context, url, error) => const Icon(Icons.error),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Positioned(
                top: 100,
                child: Stack(
                  children: [
                    GetX<AccountDataProvider>(
                      builder: (provider) {
                        if (!isCurrentUser) {
                          debugPrint(
                            'Selected user profile data for avatar: ${exploreController.selectedUserProfile}',
                          );
                        }

                        // Get avatar URLs with proper fallbacks
                        final String avatarUrl =
                            isCurrentUser
                                ? provider.avatar.value
                                : exploreController
                                        .selectedUserProfile['avatar']
                                        ?.toString() ??
                                    '';

                        final String googleAvatarUrl =
                            isCurrentUser
                                ? provider.googleAvatar.value
                                : exploreController
                                        .selectedUserProfile['google_avatar']
                                        ?.toString() ??
                                    '';

                        if (!isCurrentUser) {
                          debugPrint('Raw Avatar URL: $avatarUrl');
                          debugPrint('Raw Google Avatar URL: $googleAvatarUrl');
                        }

                        // Determine if the regular avatar should be skiped
                        final bool useGoogleAvatar =
                            avatarUrl == 'skiped' ||
                            (avatarUrl.isEmpty && googleAvatarUrl.isNotEmpty);
                        final bool showDefaultIcon =
                            avatarUrl.isEmpty &&
                            googleAvatarUrl.isEmpty &&
                            avatarUrl != 'skiped';

                        // Determine which image to use
                        final ImageProvider? imageProvider;
                        if (useGoogleAvatar && googleAvatarUrl.isNotEmpty) {
                          imageProvider = CachedNetworkImageProvider(
                            googleAvatarUrl,
                          );
                        } else if (avatarUrl.isNotEmpty &&
                            avatarUrl != 'skiped') {
                          imageProvider = CachedNetworkImageProvider(avatarUrl);
                        } else {
                          imageProvider = null;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black, Color(0xff666666)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(54),
                          ),
                          padding: EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: imageProvider,
                            backgroundColor: Colors.grey[300],
                            child:
                                showDefaultIcon
                                    ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey[600],
                                    )
                                    : null,
                          ),
                        );
                      },
                    ),
                    if (isCurrentUser)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 25,
                          width: 25,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 60), // 50 (radius) + 10 (gap)
          // User info section
          GetX<AccountDataProvider>(
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
                                  (_) => controller.isEditPressed.value = true,
                              onTapUp: (_) {
                                controller.isEditPressed.value = false;
                                Get.toNamed(Routes.EDIT_PROFILE);
                              },
                              onTapCancel:
                                  () => controller.isEditPressed.value = false,
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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
                    child: Obx(
                      () => _buildStatColumn(
                        isCurrentUser
                            ? accountDataProvider.postsCount.toString()
                            : (exploreController
                                        .selectedUserProfile['posts_count'] ??
                                    0)
                                .toString(),
                        'Posts',
                      ),
                    ),
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
                    child: Obx(
                      () => _buildStatColumn(
                        isCurrentUser
                            ? accountDataProvider.followerCount.toString()
                            : (exploreController
                                        .selectedUserProfile['follower_count'] ??
                                    0)
                                .toString(),
                        'Followers',
                        onTap: () {
                          Get.toNamed(
                            Routes.FOLLOWERS,
                            arguments: {
                              'userId': isCurrentUser ? null : userId,
                            },
                          );
                        },
                      ),
                    ),
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
                    child: Obx(
                      () => _buildStatColumn(
                        isCurrentUser
                            ? accountDataProvider.followingCount.toString()
                            : (exploreController
                                        .selectedUserProfile['following_count'] ??
                                    0)
                                .toString(),
                        'Following',
                        onTap: () {
                          Get.toNamed(
                            Routes.FOLLOWING,
                            arguments: {
                              'userId': isCurrentUser ? null : userId,
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Tab buttons
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
          // Add follow and message buttons if this is not the current user's profile
          _buildActionButtons(context),
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
    final accountDataProvider = Get.find<AccountDataProvider>();

    // Use cached state first
    final RxBool isFollowing = RxBool(
      exploreController.isFollowingUser(userId!),
    );
    final RxBool isLoadingFollow = RxBool(false);

    // Only check database state once when view is first built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Skip if already loading or if we already have this user's data cached
      if (!isLoadingFollow.value &&
          userId != null &&
          !exploreController.selectedUserProfile.containsKey('user_id')) {
        try {
          final actualFollowState = await exploreController.refreshFollowState(
            userId!,
          );
          if (actualFollowState != isFollowing.value) {
            isFollowing.value = actualFollowState;
          }
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
                              // Update local counts immediately based on the action
                              if (isFollowing.value) {
                                accountDataProvider.followingCount.value++;
                                exploreController
                                        .selectedUserProfile['follower_count'] =
                                    (exploreController
                                            .selectedUserProfile['follower_count'] ??
                                        0) +
                                    1;
                              } else {
                                accountDataProvider.followingCount.value--;
                                exploreController
                                        .selectedUserProfile['follower_count'] =
                                    (exploreController
                                            .selectedUserProfile['follower_count'] ??
                                        1) -
                                    1;
                              }

                              // Verify counts in database without updating UI
                              exploreController.verifyDatabaseCounts(
                                currentUserId,
                                userId!,
                              );
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
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (userId == null) return;
                Get.toNamed(Routes.CHAT_WINDOW, arguments: {'userId': userId});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF171717),
                minimumSize: Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text("Message", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // Add a getter for isCurrentUser to be used within the build method and _buildActionButtons
  bool get isCurrentUser =>
      userId == null ||
      userId == Get.find<SupabaseService>().currentUser.value?.id;
}

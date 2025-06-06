import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/home/controllers/stories_home_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/routes/app_pages.dart';

class StoriesListWidget extends StatelessWidget {
  const StoriesListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<StoriesHomeController>(
      builder: (controller) {
        return Container(
          height: 95, // Increased height to accommodate plus button
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: () {
            // Filter users to only show those with active stories
            final usersWithActiveStories =
                controller.usersWithStories
                    .where((user) => user.hasActiveStory)
                    .toList();

            // Calculate item count: current user + users with stories
            final itemCount = 1 + usersWithActiveStories.length;

            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 10, right: 16),
              itemCount: itemCount,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Current user's story
                  return _buildCurrentUserStory(controller);
                } else {
                  // Users' stories (only those with active stories)
                  final user = usersWithActiveStories[index - 1];
                  return _buildUserStory(user, controller);
                }
              },
            );
          }(),
        );
      },
    );
  }

  Widget _buildCurrentUserStory(StoriesHomeController controller) {
    return Obx(() {
      final accountProvider = Get.find<AccountDataProvider>();

      return SizedBox(
        width:
            100, // Increased to accommodate larger radius + border + plus button
        child: ProfileAvatarWidget(
          imageUrl:
              accountProvider.avatar.value.isNotEmpty
                  ? accountProvider.avatar.value
                  : null,
          googleAvatarUrl:
              accountProvider.googleAvatar.value.isNotEmpty
                  ? accountProvider.googleAvatar.value
                  : null,
          onTap: () {
            if (controller.hasCurrentUserStory.value) {
              // View own stories
              controller.navigateToViewStories(controller.currentUserId.value);
            } else {
              // Create new story - navigate to create story page
              Get.toNamed(Routes.CREATE_STORY);
            }
          },
          radius: 35,
          isLoaded: true,
          hasStory: controller.hasCurrentUserStory.value,
          hasUnseenStory:
              controller
                  .hasCurrentUserUnseenStory
                  .value, // Show colored border until user views their own story
          showAddButton: true, // Always show + button for current user
        ),
      );
    });
  }

  Widget _buildUserStory(StoryUser user, StoriesHomeController controller) {
    return Obx(() {
      // Find the updated user data from the controller
      final updatedUser =
          controller.usersWithStories.firstWhereOrNull(
            (u) => u.userId == user.userId,
          ) ??
          user;

      return SizedBox(
        width: 100, // Increased to accommodate larger radius + border
        child: ProfileAvatarWidget(
          imageUrl: updatedUser.avatar,
          googleAvatarUrl: null,
          onTap: () {
            controller.navigateToViewStories(updatedUser.userId);
          },
          radius: 35,
          isLoaded: true,
          hasStory: updatedUser.hasActiveStory,
          hasUnseenStory: updatedUser.hasUnseenStory,
          showAddButton: false,
        ),
      );
    });
  }
}

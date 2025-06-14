import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/settings/controllers/user_activity_controller.dart';
import 'package:yapster/app/modules/settings/widgets/activity_posts_grid.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  late UserActivityController activityController;

  @override
  void initState() {
    super.initState();
    // Initialize controller with explicit error handling
    try {
      activityController = Get.find<UserActivityController>(
        tag: 'user_activity',
      );
      debugPrint('Found existing UserActivityController');
    } catch (e) {
      debugPrint('Creating new UserActivityController: $e');
      activityController = Get.put(
        UserActivityController(),
        tag: 'user_activity',
        permanent: true,
      );
    }
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    await activityController.loadLikedPosts();
  }

  Future<void> _refreshLikedPosts() async {
    await activityController.loadLikedPosts(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Liked Posts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        return RefreshIndicator(
          onRefresh: _refreshLikedPosts,
          child: ActivityPostsGrid(
            posts: activityController.likedPosts,
            isLoading: activityController.isLoadingLikedPosts.value,
            emptyStateTitle: 'No liked posts yet',
            emptyStateSubtitle: 'Posts you like will appear here',
            emptyStateIcon: Icons.favorite_outline,
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    // Don't delete UserActivityController here as it might be used by other pages
    super.dispose();
  }
}

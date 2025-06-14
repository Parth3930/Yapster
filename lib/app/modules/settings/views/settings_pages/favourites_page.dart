import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/settings/controllers/user_activity_controller.dart';
import 'package:yapster/app/modules/settings/widgets/activity_posts_grid.dart';

class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
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
    _loadFavouritePosts();
  }

  Future<void> _loadFavouritePosts() async {
    await activityController.loadFavoritePosts();
  }

  Future<void> _refreshFavouritePosts() async {
    await activityController.loadFavoritePosts(forceRefresh: true);
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
          'Favourite Posts',
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
          onRefresh: _refreshFavouritePosts,
          child: ActivityPostsGrid(
            posts: activityController.favoritePosts,
            isLoading: activityController.isLoadingFavoritePosts.value,
            emptyStateTitle: 'No favourite posts yet',
            emptyStateSubtitle: 'Posts you star will appear here',
            emptyStateIcon: Icons.star_outline,
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/settings/controllers/user_activity_controller.dart';
import 'package:yapster/app/modules/settings/widgets/activity_posts_grid.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
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
    _loadCommentedPosts();
  }

  Future<void> _loadCommentedPosts() async {
    await activityController.loadCommentedPosts();
  }

  Future<void> _refreshCommentedPosts() async {
    await activityController.loadCommentedPosts(forceRefresh: true);
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
          'Commented Posts',
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
          onRefresh: _refreshCommentedPosts,
          child: ActivityPostsGrid(
            posts: activityController.commentedPosts,
            isLoading: activityController.isLoadingCommentedPosts.value,
            emptyStateTitle: 'No commented posts yet',
            emptyStateSubtitle: 'Posts you comment on will appear here',
            emptyStateIcon: Icons.comment_outlined,
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

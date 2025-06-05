import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_widget_factory.dart';

class PostsFeedWidget extends StatelessWidget {
  const PostsFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<PostsFeedController>(
      builder: (controller) {
        if (controller.isLoading.value && !controller.hasLoadedOnce.value) {
          return _buildShimmerEffect();
        }

        if (controller.posts.isEmpty && controller.hasLoadedOnce.value) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: controller.refreshPosts,
          child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            itemCount:
                controller.posts.length +
                (controller.hasMorePosts.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.posts.length) {
                // Load more indicator
                if (controller.isLoadingMore.value) {
                  return _buildLoadMoreIndicator();
                } else {
                  // Trigger load more
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.loadMorePosts();
                  });
                  return SizedBox.shrink();
                }
              }

              final post = controller.posts[index];
              return PostWidgetFactory.createPostWidget(
                post: post,
                controller: controller,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 20, backgroundColor: Colors.grey[700]),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 16,
                          color: Colors.grey[700],
                        ),
                        SizedBox(height: 4),
                        Container(
                          width: 60,
                          height: 12,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey[700],
                ),
                SizedBox(height: 8),
                Container(width: 200, height: 16, color: Colors.grey[700]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 64, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

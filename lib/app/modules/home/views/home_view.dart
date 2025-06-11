import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/modules/home/controllers/home_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/stories_list_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_widget_factory.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yapster/app/modules/notifications/controllers/notifications_controller.dart';
import 'package:yapster/app/modules/explore/views/explore_view.dart';
import 'package:yapster/app/modules/explore/bindings/explore_binding.dart';
import 'package:yapster/app/modules/notifications/views/notifications_view.dart';
import 'package:yapster/app/modules/notifications/bindings/notifications_binding.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fix 1: Set background color to match your app theme
      backgroundColor:
          Colors.black, // or whatever your app's background color is
      body: GetX<PostsFeedController>(
        init: PostsFeedController(),
        builder: (feedController) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              controller.onScroll(notification);
              return false;
            },
            child: RefreshIndicator(
              onRefresh: feedController.refreshPosts,
              // Fix 2: Remove conditional padding, let the feed take full height
              child: CustomScrollView(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // App bar
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 0),
                        child: Stack(
                          children: [
                            // Centered Yapster text
                            Row(
                              children: [
                                SizedBox(width: 20),
                                Text(
                                  "Yapster",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: GoogleFonts.dongle().fontFamily,
                                  ),
                                ),
                              ],
                            ),

                            // Right-aligned icons
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Image.asset(
                                      'assets/icons/explore.png',
                                      width: 24,
                                      height: 24,
                                      color: Colors.white,
                                    ),
                                    onPressed:
                                        () => controller
                                            .navigateWithBottomNavAnimation(
                                              const ExploreView(),
                                              transition:
                                                  Transition.rightToLeft,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              binding: ExploreBinding(),
                                            ),
                                  ),
                                  GetX<NotificationsController>(
                                    init: NotificationsController(),
                                    builder: (notificationController) {
                                      return Stack(
                                        children: [
                                          IconButton(
                                            icon: Image.asset(
                                              'assets/icons/bell.png',
                                              width: 24,
                                              height: 24,
                                              color: Colors.white,
                                            ),
                                            onPressed:
                                                () => controller
                                                    .navigateWithBottomNavAnimation(
                                                      const NotificationsView(),
                                                      transition:
                                                          Transition
                                                              .rightToLeft,
                                                      duration: const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                      binding:
                                                          NotificationsBinding(),
                                                    ),
                                          ),
                                          if (notificationController
                                                  .unreadCount
                                                  .value >
                                              0)
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: Container(
                                                padding: EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                constraints: BoxConstraints(
                                                  minWidth: 16,
                                                  minHeight: 16,
                                                ),
                                                child: Text(
                                                  notificationController
                                                              .unreadCount
                                                              .value >
                                                          99
                                                      ? '99+'
                                                      : notificationController
                                                          .unreadCount
                                                          .value
                                                          .toString(),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Stories section
                  const SliverToBoxAdapter(child: StoriesListWidget()),
                  // Add spacing below stories
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  // Posts Feed - Handle different states
                  if (feedController.isLoading.value &&
                      !feedController.hasLoadedOnce.value)
                    // Initial loading state - reduced shimmer count for faster loading
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildShimmerEffect(context),
                        childCount: 1, // Reduced from 3 to 1 for faster loading
                      ),
                    )
                  else if (feedController.posts.isEmpty &&
                      feedController.hasLoadedOnce.value)
                    // Empty state - no posts available
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else if (feedController.posts.isNotEmpty)
                    // Posts available - show the feed
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == feedController.posts.length) {
                            if (feedController.isLoadingMore.value) {
                              return _buildLoadMoreIndicator();
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                feedController.loadMorePosts();
                              });
                              return const SizedBox.shrink();
                            }
                          }
                          final post = feedController.posts[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: PostWidgetFactory.createPostWidget(
                                post: post,
                                controller: feedController,
                              ),
                            ),
                          );
                        },
                        childCount:
                            feedController.posts.length +
                            (feedController.hasMorePosts.value ? 1 : 0),
                      ),
                    )
                  else
                    // Fallback loading state
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Fix 3: Add bottom padding as a sliver to ensure proper spacing
                  SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          );
        },
      ),
      // Fix 4: Use extendBody to allow content behind bottom nav when hidden
      extendBody: true,
      floatingActionButton: Obx(
        () => AnimatedSlide(
          duration: const Duration(milliseconds: 150),
          offset:
              controller.bottomNavController.showBottomNav.value
                  ? Offset.zero
                  : const Offset(0, 1),
          curve: Curves.easeOut,
          child: BottomNavigation(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

Widget _buildShimmerEffect(BuildContext context) {
  return Center(
    child: Container(
      width: MediaQuery.of(context).size.width * 0.95,
      height: 350,
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 16, color: Colors.grey[700]),
                  SizedBox(height: 8),
                  Container(width: 200, height: 16, color: Colors.grey[700]),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Container(width: 40, height: 16, color: Colors.grey[700]),
                      SizedBox(width: 16),
                      Container(width: 40, height: 16, color: Colors.grey[700]),
                      SizedBox(width: 16),
                      Container(width: 40, height: 16, color: Colors.grey[700]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.post_add, size: 64, color: Colors.grey[600]),
        SizedBox(height: 16),
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Looking for new posts...',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/modules/home/controllers/home_controller.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/widgets/stories_list_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_widget_factory.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool showBottomNav = true;
  Timer? _showNavTimer;
  double _lastOffset = 0;

  void _onScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification ||
        notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      if (currentOffset > _lastOffset + 5) {
        // Scrolling down
        if (showBottomNav) setState(() => showBottomNav = false);
        _showNavTimer?.cancel();
      } else if (currentOffset < _lastOffset - 5) {
        // Scrolling up
        if (!showBottomNav) setState(() => showBottomNav = true);
        _showNavTimer?.cancel();
      } else if (notification is UserScrollNotification &&
          notification.direction == ScrollDirection.idle) {
        // Stopped scrolling
        _showNavTimer?.cancel();
        _showNavTimer = Timer(const Duration(seconds: 1), () {
          if (!showBottomNav) setState(() => showBottomNav = true);
        });
      }
      _lastOffset = currentOffset;
    }
  }

  @override
  void dispose() {
    _showNavTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fix 1: Set background color to match your app theme
      backgroundColor:
          Colors.black, // or whatever your app's background color is
      body: GetX<PostsFeedController>(
        init: PostsFeedController(),
        builder: (controller) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _onScroll(notification);
              return false;
            },
            child: RefreshIndicator(
              onRefresh: controller.refreshPosts,
              // Fix 2: Remove conditional padding, let the feed take full height
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // App bar
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        child: Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Yapster",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                ),
                                onPressed:
                                    () => Get.toNamed(Routes.NOTIFICATIONS),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Stories section
                  const SliverToBoxAdapter(child: StoriesListWidget()),
                  // Posts Feed
                  if (controller.posts.isEmpty &&
                      controller.hasLoadedOnce.value)
                    SliverToBoxAdapter(child: _buildEmptyState()),
                  if (controller.posts.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == controller.posts.length) {
                            if (controller.isLoadingMore.value) {
                              return _buildLoadMoreIndicator();
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                controller.loadMorePosts();
                              });
                              return const SizedBox.shrink();
                            }
                          }
                          final post = controller.posts[index];
                          return Center(
                            child: PostWidgetFactory.createPostWidget(
                              post: post,
                              controller: controller,
                            ),
                          );
                        },
                        childCount:
                            controller.posts.length +
                            (controller.hasMorePosts.value ? 1 : 0),
                      ),
                    ),
                  // Fix 3: Add bottom padding as a sliver to ensure proper spacing
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          showBottomNav ? 56.0 : 0, // Bottom navigation height
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // Fix 4: Use extendBody to allow content behind bottom nav when hidden
      extendBody: true,
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: showBottomNav ? Offset.zero : const Offset(0, 1),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: showBottomNav ? Colors.black : Colors.transparent,
            boxShadow:
                showBottomNav
                    ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ]
                    : null,
          ),
          child: BottomNavigation(),
        ),
      ),
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

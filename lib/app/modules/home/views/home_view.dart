import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/modules/home/controllers/home_controller.dart';
import 'package:yapster/app/modules/home/widgets/stories_list_widget.dart';
import 'package:yapster/app/modules/home/widgets/posts_feed_widget.dart';
import 'package:yapster/app/routes/app_pages.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Yapster",
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => Get.toNamed(Routes.NOTIFICATIONS),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stories section
          const StoriesListWidget(),

          // Main content - Posts Feed
          Expanded(child: PostsFeedWidget()),
        ],
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }
}

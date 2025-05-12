import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../../global_widgets/custom_app_bar.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../core/theme/theme_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() => Scaffold(
      appBar: CustomAppBar(
        title: controller.username.value.isNotEmpty 
            ? controller.username.value
            : "Welcome",
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => SupabaseService.to.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // show current theme
            Center(
              child: Text(
                themeController.isDarkMode ? "Dark" : "Light",
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

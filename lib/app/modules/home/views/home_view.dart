import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import '../controllers/home_controller.dart';
import '../../../global_widgets/custom_app_bar.dart';
import '../../../core/utils/supabase_service.dart';
import '../../../core/theme/theme_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final AccountDataProvider accountDataProvider =
        Get.find<AccountDataProvider>();

    return Obx(
      () => Scaffold(
        appBar: CustomAppBar(
          title:
              controller.username.value.isNotEmpty
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
              Center(
                child: Text(
                  themeController.isDarkMode ? "Dark" : "Light",
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

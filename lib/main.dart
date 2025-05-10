import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/core/theme/app_theme.dart';
import 'app/core/theme/theme_controller.dart';
import 'app/core/utils/storage_service.dart';
import 'app/core/utils/api_service.dart';
import 'app/core/utils/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await initServices();

  runApp(const MyApp());
}

// Initialize services before app starts
Future<void> initServices() async {
  // Initialize storage service
  await Get.putAsync(() => StorageService().init());

  // Initialize API service
  Get.put(ApiService());

  // Initialize theme controller
  Get.put(ThemeController());

  // Initialize Supabase service
  await Get.putAsync(() => SupabaseService().init());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final supabaseService = Get.find<SupabaseService>();

    return Obx(() => GetMaterialApp(
      title: 'Yapster',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.fade,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      initialRoute: supabaseService.isAuthenticated.value ? Routes.HOME : Routes.LOGIN,
      getPages: AppPages.routes,
    ));
  }
}

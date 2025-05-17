import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/core/theme/app_theme.dart';
import 'app/core/theme/theme_controller.dart';
import 'app/core/utils/storage_service.dart';
import 'app/core/utils/api_service.dart';
import 'app/core/utils/supabase_service.dart';
import 'app/data/providers/account_data_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await initServices();

  runApp(const MyApp());
}

// Initialize services before app starts
Future<void> initServices() async {
  // First initialize storage
  await Get.putAsync(() => StorageService().init());
  
  // Then API service
  Get.put(ApiService());
  
  // Initialize AccountDataProvider before SupabaseService
  Get.put(AccountDataProvider());
  
  // Initialize Supabase
  await Get.putAsync(() => SupabaseService().init());
  
  // Initialize theme controller
  Get.put(ThemeController());
  
  debugPrint('All services initialized');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(
      () => GetMaterialApp(
        title: 'Yapster',
        debugShowCheckedModeBanner: false,
        defaultTransition: Transition.fade,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode,
        initialRoute: Routes.SPLASH,
        getPages: AppPages.routes,
      ),
    );
  }
}

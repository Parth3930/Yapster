import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/core/utils/storage_service.dart';
import 'app/core/utils/api_service.dart';
import 'app/core/utils/supabase_service.dart';
import 'app/data/providers/account_data_provider.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await initServices();

  // Configure EasyLoading
  configureEasyLoading();

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

  debugPrint('All services initialized');
}

// Configure EasyLoading settings
void configureEasyLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 1500)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 35.0
    ..radius = 10.0
    ..progressColor = Colors.white
    ..backgroundColor = Colors.black.withOpacity(0.7)
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskColor = Colors.black.withOpacity(0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Yapster',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.fade,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,
      builder: EasyLoading.init(),
    );
  }
}

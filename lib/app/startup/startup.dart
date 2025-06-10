import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:yapster/app/routes/app_pages.dart';
import 'package:yapster/app/startup/app_initializer.dart';
import 'package:yapster/app/startup/feed_loader/feed_loader_service.dart';

/// Main application widget
class MyApp extends StatefulWidget {
  final bool initializationFailed;

  const MyApp({super.key, this.initializationFailed = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Handle hot reload by checking if services are initialized
    AppInitializer.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Yapster',
      initialRoute: widget.initializationFailed ? Routes.ERROR : Routes.SPLASH,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.noTransition,
      transitionDuration: Duration.zero,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(onSecondary: Colors.black),
      ),
      builder: EasyLoading.init(),
    );
  }
}

/// Main entry point for the application
Future<void> startApp() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system to reduce memory usage and prevent buffer issues
  _configureSystemForOptimalPerformance();

  try {
    // Pre-initialize app components
    await AppInitializer.preInitialize();

    // Run the app
    runApp(const MyApp());

    // Post-initialize remaining services after UI is shown
    AppInitializer.postInitialize();

    // Initialize FeedLoaderService and preload the feed after services are ready
    // This is done in the background and won't block app startup
    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        await FeedLoaderService.preloadFeed();
      } catch (e) {
        debugPrint('Error preloading feed (non-critical): $e');
      }
    });
  } catch (e) {
    debugPrint('Failed to initialize essential services: $e');
    // Run the app in error state
    runApp(const MyApp(initializationFailed: true));
  }
}

/// Configure system settings for optimal performance and reduced memory usage
void _configureSystemForOptimalPerformance() {
  try {
    // Set system UI overlay style to reduce memory usage
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Configure preferred orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    debugPrint('System configured for optimal performance');
  } catch (e) {
    debugPrint('Error configuring system: $e');
  }
}

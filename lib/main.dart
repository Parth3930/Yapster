import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/core/utils/storage_service.dart';
import 'app/core/utils/api_service.dart';
import 'app/core/utils/supabase_service.dart';
import 'app/core/utils/db_cache_service.dart';
import 'app/core/utils/encryption_service.dart';
import 'app/core/utils/chat_cache_service.dart';
import 'app/data/providers/account_data_provider.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred device orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Setup error handling
  _setupErrorHandling();
  
  try {
    // Initialize essential services before showing splash screen
    await Get.putAsync(() => StorageService().init());
    Get.put(ApiService());
    Get.put(AccountDataProvider());
    
    // Configure EasyLoading
    configureEasyLoading();
    
    // Start with splash screen (which will act as a loader)
    runApp(const MyApp());
    
    // Initialize remaining services in background after splash is displayed
    _initRemainingServices();
    
  } catch (e) {
    debugPrint('Failed to initialize essential services: $e');
    // Configure EasyLoading
    configureEasyLoading();
    // Show app with error state
    runApp(const MyApp(initializationFailed: true));
  }
}

// Setup global error handling
void _setupErrorHandling() {
  // Set Flutter error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Set Dart error handler for errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };
}

// This function has been removed and replaced by splitting the initialization
// between essential services (initialized immediately) and
// remaining services (initialized in the background).

// Monitor connectivity changes
void _setupConnectivityMonitoring() {
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final dbCacheService = Get.find<DbCacheService>();
    final isOffline = result == ConnectivityResult.none;
    
    // Only update if the state actually changed
    if (dbCacheService.isOfflineModeEnabled.value != isOffline) {
      debugPrint('Connectivity changed: ${result.name}, setting offline mode: $isOffline');
      dbCacheService.setOfflineModeEnabled(isOffline);
    }
  });
}

// Initialize remaining services after splash screen is shown
Future<void> _initRemainingServices() async {
  final stopwatch = Stopwatch()..start();
  
  try {
    // Initialize DB cache service
    await Get.putAsync(() => DbCacheService().init())
        .timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('DbCacheService initialization timed out');
    });
    debugPrint('DbCacheService initialized in ${stopwatch.elapsedMilliseconds}ms');
    
    // Initialize Supabase (most time-consuming)
    await Get.putAsync(() => SupabaseService().init())
        .timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('SupabaseService initialization timed out');
    });
    debugPrint('SupabaseService initialized in ${stopwatch.elapsedMilliseconds}ms');
    
    // Initialize encryption service if user is logged in
    final supabaseService = Get.find<SupabaseService>();
    if (supabaseService.isAuthenticated.value && supabaseService.currentUser.value?.id != null) {
      final userId = supabaseService.currentUser.value!.id;
      await Get.putAsync(() => EncryptionService().init(userId))
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('EncryptionService initialization timed out');
      });
      debugPrint('EncryptionService initialized in ${stopwatch.elapsedMilliseconds}ms');
      
      // Initialize chat cache service (depends on encryption service)
      final chatCacheService = ChatCacheService();
      Get.put(chatCacheService);
      await chatCacheService.init();
      debugPrint('ChatCacheService initialized in ${stopwatch.elapsedMilliseconds}ms');
    } else {
      // Still register the service without initialization
      Get.put(EncryptionService());
      debugPrint('EncryptionService registered (not initialized yet, waiting for login)');
      
      // Register chat cache service as well
      Get.put(ChatCacheService());
      debugPrint('ChatCacheService registered (not initialized, waiting for login)');
    }
    
    // Initialize connectivity monitoring
    _setupConnectivityMonitoring();
    
    debugPrint('All remaining services initialized in ${stopwatch.elapsedMilliseconds}ms');
  } catch (e) {
    debugPrint('Error during remaining services initialization: $e');
  } finally {
    stopwatch.stop();
  }
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
    _ensureServicesInitialized();
  }

  // Make sure essential services are available, even on hot reload
  Future<void> _ensureServicesInitialized() async {
    try {
      // Check if StorageService is available, initialize if not
      if (!Get.isRegistered<StorageService>()) {
        debugPrint('StorageService not found on hot reload, initializing');
        await Get.putAsync(() => StorageService().init());
      }

      // Check if ApiService is available, initialize if not
      if (!Get.isRegistered<ApiService>()) {
        debugPrint('ApiService not found on hot reload, initializing');
        Get.put(ApiService());
      }

      // Check if AccountDataProvider is available, initialize if not
      if (!Get.isRegistered<AccountDataProvider>()) {
        debugPrint('AccountDataProvider not found on hot reload, initializing');
        Get.put(AccountDataProvider());
      }
      
      // Check if DbCacheService is available, initialize if not
      if (!Get.isRegistered<DbCacheService>()) {
        debugPrint('DbCacheService not found on hot reload, initializing');
        await Get.putAsync(() => DbCacheService().init());
      }
      
      // Check if SupabaseService is available, initialize if not
      if (!Get.isRegistered<SupabaseService>()) {
        debugPrint('SupabaseService not found on hot reload, initializing');
        await Get.putAsync(() => SupabaseService().init());
      }
      
      // Check if EncryptionService is available, initialize if not and user is logged in
      if (!Get.isRegistered<EncryptionService>()) {
        debugPrint('EncryptionService not found on hot reload');
        // Register service without initialization
        Get.put(EncryptionService());
        
        // Initialize if user is logged in
        final supabaseService = Get.find<SupabaseService>();
        if (supabaseService.isAuthenticated.value && supabaseService.currentUser.value?.id != null) {
          final userId = supabaseService.currentUser.value!.id;
          await Get.find<EncryptionService>().init(userId);
          debugPrint('EncryptionService initialized on hot reload');
        }
      }
      
      // Check if ChatCacheService is available, initialize if not
      if (!Get.isRegistered<ChatCacheService>()) {
        debugPrint('ChatCacheService not found on hot reload, initializing');
        final chatCacheService = ChatCacheService();
        Get.put(chatCacheService);
        await chatCacheService.init();
        debugPrint('ChatCacheService initialized on hot reload');
      }
    } catch (e) {
      debugPrint('Error ensuring services on hot reload: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Yapster',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.fade,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          onSecondary: Colors.black,
        ),
      ),
      initialRoute: widget.initializationFailed ? Routes.ERROR : Routes.SPLASH,
      getPages: AppPages.routes,
      builder: EasyLoading.init(),
    );
  }
}

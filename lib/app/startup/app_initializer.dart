import 'package:yapster/app/startup/error_handling.dart';
import 'package:yapster/app/startup/service_initializer.dart';
import 'package:yapster/app/startup/ui_initializer.dart';

/// Main coordinator for application initialization
class AppInitializer {
  /// Initialize all required components before app startup
  static Future<void> preInitialize() async {
    // Setup error handling first to catch any errors during initialization
    ErrorHandling.setupErrorHandling();

    // Configure system UI
    UiInitializer.configureSystemUI();

    // Initialize essential services
    await ServiceInitializer.initializeEssentialServices();

    // Configure loading indicators
    UiInitializer.configureEasyLoading();
  }

  /// Initialize remaining services after app has started
  static Future<void> postInitialize() async {
    // Initialize remaining services that can be loaded after UI is shown
    await ServiceInitializer.initializeRemainingServices();
  }

  /// Ensure all services are initialized (useful for hot reload)
  static Future<void> ensureInitialized() async {
    await ServiceInitializer.ensureServicesInitialized();
  }
}

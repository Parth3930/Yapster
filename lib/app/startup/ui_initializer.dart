import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

/// Handles initialization of UI-related configurations
class UiInitializer {
  /// Configure system UI overlays and status bar appearance
  static void configureSystemUI() {
    // Set preferred orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Configure system overlays
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Hide status bar for full screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive, overlays: []);
  }

  /// Configure EasyLoading for app-wide loading indicators
  static void configureEasyLoading() {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 1500)
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..loadingStyle = EasyLoadingStyle.dark
      ..indicatorSize = 35.0
      ..radius = 10.0
      ..progressColor = Colors.white
      ..backgroundColor = Colors.black
      ..indicatorColor = Colors.white
      ..textColor = Colors.white
      ..maskColor = Colors.black
      ..userInteractions = false
      ..dismissOnTap = false;
  }
}

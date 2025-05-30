import 'dart:ui';
import 'package:flutter/material.dart';

/// Handles global error setup for the application
class ErrorHandling {
  /// Setup global error handling for both Flutter and Dart errors
  static void setupErrorHandling() {
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
}

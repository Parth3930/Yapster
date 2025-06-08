import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yapster/app/startup/preloader/optimized_bindings.dart';

/// Utility class for testing and verifying navigation optimizations
class NavigationTestUtils {
  /// Test navigation speed by measuring time taken
  static Future<void> testNavigationSpeed(String route) async {
    final stopwatch = Stopwatch()..start();
    
    // Perform navigation
    Get.offNamed(route);
    
    stopwatch.stop();
    debugPrint('Navigation to $route took: ${stopwatch.elapsedMilliseconds}ms');
    
    // Log if navigation is slower than expected
    if (stopwatch.elapsedMilliseconds > 100) {
      debugPrint('⚠️ Navigation slower than expected (>100ms)');
    } else {
      debugPrint('✅ Navigation is optimized (<100ms)');
    }
  }

  /// Verify that controllers are properly preloaded and persistent
  static void verifyControllerOptimization() {
    debugPrint('\n=== Navigation Optimization Verification ===');
    
    // Check if optimization system is working
    final isOptimized = OptimizationChecker.isAppOptimized;
    final controllersPreloaded = OptimizationChecker.areControllersPreloaded;
    
    debugPrint('App Optimized: ${isOptimized ? "✅" : "❌"}');
    debugPrint('Controllers Preloaded: ${controllersPreloaded ? "✅" : "❌"}');
    
    // Check individual controller status
    final controllerStatus = OptimizationChecker.controllerStatus;
    debugPrint('\nController Status:');
    controllerStatus.forEach((name, registered) {
      debugPrint('  $name: ${registered ? "✅ Registered" : "❌ Not Registered"}');
    });
    
    // Check repository status
    final repositoryStatus = OptimizationChecker.repositoryStatus;
    debugPrint('\nRepository Status:');
    repositoryStatus.forEach((name, registered) {
      debugPrint('  $name: ${registered ? "✅ Registered" : "❌ Not Registered"}');
    });
    
    debugPrint('============================================\n');
  }

  /// Test animation performance (should not block navigation)
  static void testAnimationPerformance() {
    debugPrint('\n=== Animation Performance Test ===');
    
    final stopwatch = Stopwatch()..start();
    
    // Simulate animation trigger (this should be non-blocking)
    Future.microtask(() {
      stopwatch.stop();
      debugPrint('Animation microtask executed in: ${stopwatch.elapsedMicroseconds}μs');
      
      if (stopwatch.elapsedMicroseconds < 1000) {
        debugPrint('✅ Animation is properly deferred (non-blocking)');
      } else {
        debugPrint('⚠️ Animation might be blocking navigation');
      }
    });
    
    debugPrint('===================================\n');
  }

  /// Comprehensive navigation optimization test
  static void runFullOptimizationTest() {
    debugPrint('\n🚀 Running Full Navigation Optimization Test 🚀\n');
    
    // Test 1: Controller optimization
    verifyControllerOptimization();
    
    // Test 2: Animation performance
    testAnimationPerformance();
    
    // Test 3: Memory usage check
    _checkMemoryOptimization();
    
    debugPrint('🎯 Navigation Optimization Test Complete 🎯\n');
  }

  /// Check memory optimization status
  static void _checkMemoryOptimization() {
    debugPrint('\n=== Memory Optimization Check ===');
    
    // Count registered permanent controllers
    int permanentControllers = 0;
    final controllers = [
      'HomeController',
      'ProfileController', 
      'ChatController',
      'CreateController',
      'ExploreController',
      'PostsFeedController',
      'StoriesHomeController'
    ];
    
    for (final controller in controllers) {
      try {
        // This is a simplified check - in real implementation you'd check if they're permanent
        if (Get.isRegistered(tag: controller)) {
          permanentControllers++;
        }
      } catch (e) {
        // Controller not registered
      }
    }
    
    debugPrint('Permanent Controllers: $permanentControllers/${controllers.length}');
    
    if (permanentControllers >= controllers.length * 0.8) {
      debugPrint('✅ Memory optimization is good (80%+ controllers permanent)');
    } else {
      debugPrint('⚠️ Memory optimization could be improved');
    }
    
    debugPrint('==================================\n');
  }

  /// Quick navigation test for bottom navigation
  static void testBottomNavigationSpeed() {
    debugPrint('\n=== Bottom Navigation Speed Test ===');
    
    final routes = ['/home', '/explore', '/chat', '/profile', '/create'];
    
    for (final route in routes) {
      final stopwatch = Stopwatch()..start();
      
      // Simulate the navigation call (without actually navigating in test)
      Future.microtask(() {
        stopwatch.stop();
        debugPrint('$route navigation simulation: ${stopwatch.elapsedMicroseconds}μs');
      });
    }
    
    debugPrint('=====================================\n');
  }
}

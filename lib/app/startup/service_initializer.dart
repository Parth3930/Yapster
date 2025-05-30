import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/api_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/db_cache_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Handles initialization of all application services
class ServiceInitializer {
  /// Initialize essential services required before app startup
  static Future<void> initializeEssentialServices() async {
    // Initialize storage service first (required by other services)
    await Get.putAsync(() => StorageService().init());

    // Initialize basic services
    Get.put(ApiService());
    Get.put(AccountDataProvider());
  }

  /// Initialize remaining services after app has started
  static Future<void> initializeRemainingServices() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Initialize DB cache service
      await Get.putAsync(() => DbCacheService().init()).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('DbCacheService initialization timed out');
        },
      );
      debugPrint(
        'DbCacheService initialized in ${stopwatch.elapsedMilliseconds}ms',
      );

      // Initialize Supabase (most time-consuming)
      await Get.putAsync(() => SupabaseService().init()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('SupabaseService initialization timed out');
        },
      );
      debugPrint(
        'SupabaseService initialized in ${stopwatch.elapsedMilliseconds}ms',
      );

      // Initialize encryption service if user is logged in
      final supabaseService = Get.find<SupabaseService>();
      if (supabaseService.isAuthenticated.value &&
          supabaseService.currentUser.value?.id != null) {
        final userId = supabaseService.currentUser.value!.id;
        await Get.putAsync(() => EncryptionService().init(userId)).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException(
              'EncryptionService initialization timed out',
            );
          },
        );
        debugPrint(
          'EncryptionService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );

        // Initialize chat cache service (depends on encryption service)
        final chatCacheService = ChatCacheService();
        Get.put(chatCacheService);
        await chatCacheService.init();
        debugPrint(
          'ChatCacheService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      } else {
        // Still register the service without initialization
        Get.put(EncryptionService());
        debugPrint(
          'EncryptionService registered (not initialized yet, waiting for login)',
        );

        // Register chat cache service as well
        Get.put(ChatCacheService());
        debugPrint(
          'ChatCacheService registered (not initialized, waiting for login)',
        );
      }

      // Initialize connectivity monitoring
      setupConnectivityMonitoring();

      debugPrint(
        'All remaining services initialized in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('Error during remaining services initialization: $e');
    } finally {
      stopwatch.stop();
    }
  }

  /// Setup connectivity monitoring to track online/offline status
  static void setupConnectivityMonitoring() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      final dbCacheService = Get.find<DbCacheService>();
      final isOffline = result == ConnectivityResult.none;

      // Only update if the state actually changed
      if (dbCacheService.isOfflineModeEnabled.value != isOffline) {
        debugPrint(
          'Connectivity changed: ${result.name}, setting offline mode: $isOffline',
        );
        dbCacheService.setOfflineModeEnabled(isOffline);
      }
    });
  }

  /// Ensure all essential services are initialized (useful for hot reload)
  static Future<void> ensureServicesInitialized() async {
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

      // Check if AccountDataProvider is available
      if (!Get.isRegistered<AccountDataProvider>()) {
        debugPrint(
          'AccountDataProvider not found on hot reload. This should have been initialized by initializeEssentialServices.',
        );
        // Consider if re-initialization or a different strategy is needed here if this state is possible.
        // For now, we assume initializeEssentialServices handles it.
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
        if (supabaseService.isAuthenticated.value &&
            supabaseService.currentUser.value?.id != null) {
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
}

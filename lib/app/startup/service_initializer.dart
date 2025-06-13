import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/services/intelligent_feed_service.dart';

import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/api_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/utils/db_cache_service.dart';
import 'package:yapster/app/core/utils/encryption_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/startup/preloader/preloader_service.dart';
import 'package:yapster/app/startup/preloader/cache_manager.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/repositories/account_repository.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/repositories/notification_repository.dart';
import 'package:yapster/app/data/repositories/device_token_repository.dart';
import 'package:yapster/app/core/services/push_notification_service.dart';
import 'package:yapster/app/core/services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Handles initialization of all application services
class ServiceInitializer {
  /// Initialize essential services required before app startup
  static Future<void> initializeEssentialServices() async {
    // Initialize storage service first (required by other services)
    if (!Get.isRegistered<StorageService>()) {
      await Get.putAsync(() => StorageService().init());
    }

    // Initialize cache manager early for app optimization
    if (!Get.isRegistered<CacheManager>()) {
      Get.put(CacheManager(), permanent: true);
    }

    // Initialize basic services
    if (!Get.isRegistered<ApiService>()) {
      Get.put(ApiService());
    }
    if (!Get.isRegistered<AccountDataProvider>()) {
      Get.put(AccountDataProvider());
    }

    // Initialize app preloader service
    if (!Get.isRegistered<PreloaderService>()) {
      Get.put(PreloaderService(), permanent: true);
    }

    // Initialize repositories
    if (!Get.isRegistered<PostRepository>()) {
      Get.put(PostRepository(), permanent: true);
    }
    if (!Get.isRegistered<AccountRepository>()) {
      Get.put(AccountRepository(), permanent: true);
    }
    if (!Get.isRegistered<StoryRepository>()) {
      Get.put(StoryRepository(), permanent: true);
    }
    if (!Get.isRegistered<NotificationRepository>()) {
      Get.put(NotificationRepository(), permanent: true);
    }

    // Initialize device token repository
    if (!Get.isRegistered<DeviceTokenRepository>()) {
      Get.put(DeviceTokenRepository(), permanent: true);
    }

    // Note: NotificationService and IntelligentFeedService moved to initializeRemainingServices
    // because they depend on SupabaseService which is initialized later
  }

  /// Initialize remaining services after app has started
  static Future<void> initializeRemainingServices() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Initialize DB cache service
      if (!Get.isRegistered<DbCacheService>()) {
        await Get.putAsync(() => DbCacheService().init()).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('DbCacheService initialization timed out');
          },
        );
        debugPrint(
          'DbCacheService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Initialize Supabase (most time-consuming)
      if (!Get.isRegistered<SupabaseService>()) {
        await Get.putAsync(() => SupabaseService().init()).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('SupabaseService initialization timed out');
          },
        );
        debugPrint(
          'SupabaseService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Initialize intelligent feed services after SupabaseService is ready

      if (!Get.isRegistered<IntelligentFeedService>()) {
        Get.put(IntelligentFeedService(), permanent: true);
        debugPrint(
          'IntelligentFeedService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Initialize UserPostsCacheService after SupabaseService is ready
      if (!Get.isRegistered<UserPostsCacheService>()) {
        Get.put(UserPostsCacheService(), permanent: true);
        debugPrint(
          'UserPostsCacheService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Initialize notification service after SupabaseService is ready
      if (!Get.isRegistered<NotificationService>()) {
        await Get.putAsync(() => NotificationService().init());
        debugPrint(
          'NotificationService initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Initialize encryption service if user is logged in
      final supabaseService = Get.find<SupabaseService>();
      if (supabaseService.isAuthenticated.value &&
          supabaseService.currentUser.value?.id != null) {
        final userId = supabaseService.currentUser.value!.id;

        if (!Get.isRegistered<EncryptionService>()) {
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
        }

        // Initialize chat cache service (depends on encryption service)
        if (!Get.isRegistered<ChatCacheService>()) {
          final chatCacheService = ChatCacheService();
          Get.put(chatCacheService);
          await chatCacheService.init();
          debugPrint(
            'ChatCacheService initialized in ${stopwatch.elapsedMilliseconds}ms',
          );
        }
      } else {
        // Still register the service without initialization
        if (!Get.isRegistered<EncryptionService>()) {
          Get.put(EncryptionService());
          debugPrint(
            'EncryptionService registered (not initialized yet, waiting for login)',
          );
        }

        // Register chat cache service as well
        if (!Get.isRegistered<ChatCacheService>()) {
          Get.put(ChatCacheService());
          debugPrint(
            'ChatCacheService registered (not initialized, waiting for login)',
          );
        }
      }

      // Initialize Supabase notification service after user is authenticated
      if (!Get.isRegistered<PushNotificationService>()) {
        await Get.putAsync(() => PushNotificationService().init()).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint(
              'Supabase notification service initialization timed out (non-critical)',
            );
            return PushNotificationService();
          },
        );
        debugPrint(
          'Supabase notification service initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // Initialize connectivity monitoring
      setupConnectivityMonitoring();

      // Start app preloading if user is authenticated
      if (supabaseService.isAuthenticated.value) {
        if (Get.isRegistered<PreloaderService>()) {
          final appPreloader = Get.find<PreloaderService>();
          // Start preloading in background - don't await to avoid blocking
          appPreloader.preloadApp().catchError((e) {
            debugPrint('App preloading failed (non-critical): $e');
          });
        }
      }

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

      // Check if intelligent feed services are available

      // Check if device token repository is available
      if (!Get.isRegistered<DeviceTokenRepository>()) {
        debugPrint(
          'DeviceTokenRepository not found on hot reload, initializing',
        );
        Get.put(DeviceTokenRepository(), permanent: true);
      }

      // Check if notification service is available
      if (!Get.isRegistered<NotificationService>()) {
        debugPrint('NotificationService not found on hot reload, initializing');
        await Get.putAsync(() => NotificationService().init());
      }

      // Check if Supabase notification service is available
      if (!Get.isRegistered<PushNotificationService>()) {
        debugPrint(
          'Supabase notification service not found on hot reload, initializing',
        );
        await Get.putAsync(() => PushNotificationService().init());
      }

      if (!Get.isRegistered<IntelligentFeedService>()) {
        debugPrint(
          'IntelligentFeedService not found on hot reload, initializing',
        );
        Get.put(IntelligentFeedService(), permanent: true);
      }

      if (!Get.isRegistered<UserPostsCacheService>()) {
        debugPrint(
          'UserPostsCacheService not found on hot reload, initializing',
        );
        Get.put(UserPostsCacheService(), permanent: true);
      }

      // Check if repositories are available
      if (!Get.isRegistered<PostRepository>()) {
        debugPrint('PostRepository not found on hot reload, initializing');
        Get.put(PostRepository(), permanent: true);
      }

      if (!Get.isRegistered<AccountRepository>()) {
        debugPrint('AccountRepository not found on hot reload, initializing');
        Get.put(AccountRepository(), permanent: true);
      }

      if (!Get.isRegistered<StoryRepository>()) {
        debugPrint('StoryRepository not found on hot reload, initializing');
        Get.put(StoryRepository(), permanent: true);
      }

      if (!Get.isRegistered<NotificationRepository>()) {
        debugPrint(
          'NotificationRepository not found on hot reload, initializing',
        );
        Get.put(NotificationRepository(), permanent: true);
      }

      // CRITICAL: Force refresh data after hot reload to ensure consistency
      final supabaseService = Get.find<SupabaseService>();
      if (supabaseService.isAuthenticated.value) {
        debugPrint('User authenticated after hot reload, refreshing data');

        // Force refresh account data
        final accountDataProvider = Get.find<AccountDataProvider>();
        await accountDataProvider.preloadUserData();

        // DON'T force refresh posts feed on hot reload - let the controller use cached data
        // The posts feed controller will handle hot reload properly with cached user data
        if (Get.isRegistered<PostsFeedController>()) {
          debugPrint(
            'PostsFeedController exists - letting it handle hot reload with cached data',
          );
          // The controller's onInit will detect hot reload and use cached posts with user data
        }
      }
    } catch (e) {
      debugPrint('Error ensuring services on hot reload: $e');
    }
  }
}

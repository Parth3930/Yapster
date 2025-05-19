class AppConstants {
  // API URLs
  static const String baseUrl = 'https://api.example.com';
  static const String apiVersion = '/v1';

  // App Settings
  static const String appName = 'Yapster';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String languageKey = 'app_language';
  
  // Security
  static const String encryptionKey = 'yapster_secure_storage_key_2024';
  
  // Cache Settings
  static const String cachingEnabledKey = 'caching_enabled';
  static const String offlineModeKey = 'offline_mode_enabled';
  static const String cacheExpirationTimesKey = 'cache_expiration_times';
  static const int maxCacheSizeMB = 50; 

  // Timeouts
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Pagination
  static const int defaultPageSize = 20;

  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
}

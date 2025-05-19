import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../values/constants.dart';
import 'package:flutter/foundation.dart';

class StorageService extends GetxService {
  late final SharedPreferences _prefs;
  
  // In-memory cache for frequently accessed values
  final Map<String, dynamic> _cache = {};
  
  // Keys that store sensitive data - use encryption for these
  final List<String> _sensitiveKeys = [
    AppConstants.tokenKey,
  ];

  Future<StorageService> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Preload frequently used values into memory
      _preCache();
      
      return this;
    } catch (e) {
      debugPrint('Error initializing StorageService: $e');
      rethrow;
    }
  }
  
  // Preload commonly used values into memory cache
  void _preCache() {
    try {
      // Cache user data and token
      if (_prefs.containsKey(AppConstants.userDataKey)) {
        _cache[AppConstants.userDataKey] = getObject(AppConstants.userDataKey);
      }
      
      if (_prefs.containsKey(AppConstants.tokenKey)) {
        _cache[AppConstants.tokenKey] = getString(AppConstants.tokenKey);
      }
      
      if (_prefs.containsKey(AppConstants.themeKey)) {
        _cache[AppConstants.themeKey] = getString(AppConstants.themeKey);
      }
    } catch (e) {
      debugPrint('Error pre-caching values: $e');
    }
  }

  // Basic encryption for sensitive data (in a real app, use a dedicated encryption library)
  String _encrypt(String value) {
    // This is a simple XOR encryption - for production, use proper encryption
    final key = AppConstants.encryptionKey;
    final result = <int>[];
    
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      final k = key.codeUnitAt(i % key.length);
      result.add(c ^ k);
    }
    
    return base64.encode(result);
  }
  
  // Decrypt sensitive data
  String _decrypt(String encrypted) {
    try {
      final decoded = base64.decode(encrypted);
      final key = AppConstants.encryptionKey;
      final result = <int>[];
      
      for (var i = 0; i < decoded.length; i++) {
        final c = decoded[i];
        final k = key.codeUnitAt(i % key.length);
        result.add(c ^ k);
      }
      
      return String.fromCharCodes(result);
    } catch (e) {
      debugPrint('Error decrypting value: $e');
      return ''; // Return empty string on decrypt error
    }
  }

  // Save string data
  Future<bool> saveString(String key, String value) async {
    try {
      // Update memory cache
      _cache[key] = value;
      
      // Encrypt sensitive values
      final valueToStore = _sensitiveKeys.contains(key) ? _encrypt(value) : value;
      
      return await _prefs.setString(key, valueToStore);
    } catch (e) {
      debugPrint('Error saving string: $e');
      return false;
    }
  }

  // Read string data
  String? getString(String key) {
    try {
      // Check cache first
      if (_cache.containsKey(key)) {
        return _cache[key] as String?;
      }
      
      // Not in cache, read from storage
      final value = _prefs.getString(key);
      
      // Decrypt if sensitive
      if (value != null && _sensitiveKeys.contains(key)) {
        final decrypted = _decrypt(value);
        // Update cache with decrypted value
        _cache[key] = decrypted;
        return decrypted;
      }
      
      // Update cache
      if (value != null) {
        _cache[key] = value;
      }
      
      return value;
    } catch (e) {
      debugPrint('Error getting string: $e');
      return null;
    }
  }

  // Save boolean data
  Future<bool> saveBool(String key, bool value) async {
    try {
      // Update memory cache
      _cache[key] = value;
      
      return await _prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error saving boolean: $e');
      return false;
    }
  }

  // Read boolean data
  bool? getBool(String key) {
    try {
      // Check cache first
      if (_cache.containsKey(key)) {
        return _cache[key] as bool?;
      }
      
      // Not in cache, read from storage
      final value = _prefs.getBool(key);
      
      // Update cache
      if (value != null) {
        _cache[key] = value;
      }
      
      return value;
    } catch (e) {
      debugPrint('Error getting boolean: $e');
      return null;
    }
  }

  // Save integer data
  Future<bool> saveInt(String key, int value) async {
    try {
      // Update memory cache
      _cache[key] = value;
      
      return await _prefs.setInt(key, value);
    } catch (e) {
      debugPrint('Error saving int: $e');
      return false;
    }
  }

  // Read integer data
  int? getInt(String key) {
    try {
      // Check cache first
      if (_cache.containsKey(key)) {
        return _cache[key] as int?;
      }
      
      // Not in cache, read from storage
      final value = _prefs.getInt(key);
      
      // Update cache
      if (value != null) {
        _cache[key] = value;
      }
      
      return value;
    } catch (e) {
      debugPrint('Error getting int: $e');
      return null;
    }
  }

  // Save double data
  Future<bool> saveDouble(String key, double value) async {
    try {
      // Update memory cache
      _cache[key] = value;
      
      return await _prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('Error saving double: $e');
      return false;
    }
  }

  // Read double data
  double? getDouble(String key) {
    try {
      // Check cache first
      if (_cache.containsKey(key)) {
        return _cache[key] as double?;
      }
      
      // Not in cache, read from storage
      final value = _prefs.getDouble(key);
      
      // Update cache
      if (value != null) {
        _cache[key] = value;
      }
      
      return value;
    } catch (e) {
      debugPrint('Error getting double: $e');
      return null;
    }
  }

  // Save object data (converts to JSON string)
  Future<bool> saveObject(String key, Map<String, dynamic> value) async {
    try {
      // Update memory cache
      _cache[key] = value;
      
      String jsonString = json.encode(value);
      
      // Encrypt if sensitive
      if (_sensitiveKeys.contains(key)) {
        jsonString = _encrypt(jsonString);
      }
      
      return await _prefs.setString(key, jsonString);
    } catch (e) {
      debugPrint('Error saving object: $e');
      return false;
    }
  }

  // Read object data (parses from JSON string)
  Map<String, dynamic>? getObject(String key) {
    try {
      // Check cache first
      if (_cache.containsKey(key)) {
        return _cache[key] as Map<String, dynamic>?;
      }
      
      // Not in cache, read from storage
      String? jsonString = _prefs.getString(key);
      if (jsonString == null) return null;
      
      // Decrypt if sensitive
      if (_sensitiveKeys.contains(key)) {
        jsonString = _decrypt(jsonString);
      }
      
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      
      // Update cache
      _cache[key] = decoded;
      
      return decoded;
    } catch (e) {
      debugPrint('Error getting object: $e');
      return null;
    }
  }

  // Save auth token
  Future<bool> saveToken(String token) async {
    return await saveString(AppConstants.tokenKey, token);
  }

  // Get auth token
  String? getToken() {
    return getString(AppConstants.tokenKey);
  }

  // Save user data
  Future<bool> saveUserData(Map<String, dynamic> userData) async {
    return await saveObject(AppConstants.userDataKey, userData);
  }

  // Get user data
  Map<String, dynamic>? getUserData() {
    return getObject(AppConstants.userDataKey);
  }

  // Save theme mode
  Future<bool> saveThemeMode(String themeMode) async {
    return await saveString(AppConstants.themeKey, themeMode);
  }

  // Get theme mode
  String? getThemeMode() {
    return getString(AppConstants.themeKey);
  }

  // Clear specific data
  Future<bool> remove(String key) async {
    try {
      // Remove from cache
      _cache.remove(key);
      
      return await _prefs.remove(key);
    } catch (e) {
      debugPrint('Error removing key: $e');
      return false;
    }
  }

  // Clear all data
  Future<bool> clear() async {
    try {
      // Clear cache
      _cache.clear();
      
      return await _prefs.clear();
    } catch (e) {
      debugPrint('Error clearing storage: $e');
      return false;
    }
  }
  
  // Clear cache only (without clearing persistent storage)
  void clearCache() {
    _cache.clear();
  }
}

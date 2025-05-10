import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../values/constants.dart';

class StorageService extends GetxService {
  late final SharedPreferences _prefs;

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // Save string data
  Future<bool> saveString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  // Read string data
  String? getString(String key) {
    return _prefs.getString(key);
  }

  // Save boolean data
  Future<bool> saveBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  // Read boolean data
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  // Save integer data
  Future<bool> saveInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  // Read integer data
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  // Save double data
  Future<bool> saveDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  // Read double data
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  // Save object data (converts to JSON string)
  Future<bool> saveObject(String key, Map<String, dynamic> value) async {
    return await _prefs.setString(key, json.encode(value));
  }

  // Read object data (parses from JSON string)
  Map<String, dynamic>? getObject(String key) {
    String? jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return json.decode(jsonString) as Map<String, dynamic>;
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
    return await _prefs.remove(key);
  }

  // Clear all data
  Future<bool> clear() async {
    return await _prefs.clear();
  }
}

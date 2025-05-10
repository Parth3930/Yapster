import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/storage_service.dart';

class ThemeController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  @override
  void onInit() {
    super.onInit();
    _loadThemeMode();
  }

  // Load saved theme mode from storage
  void _loadThemeMode() {
    String? savedTheme = _storageService.getThemeMode();
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode.value = ThemeMode.light;
          break;
        case 'dark':
          _themeMode.value = ThemeMode.dark;
          break;
        default:
          _themeMode.value = ThemeMode.dark;
          break;
      }
    }
  }

  // Change theme mode and save to storage
  void changeThemeMode(ThemeMode mode) {
    _themeMode.value = mode;
    _saveThemeMode(mode);
    Get.changeThemeMode(mode);
    Get.forceAppUpdate();
  }

  // Toggle between light and dark mode
  void toggleTheme() {
    _themeMode.value =
        _themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    changeThemeMode(_themeMode.value);
  }

  // Save theme mode to storage
  void _saveThemeMode(ThemeMode mode) {
    String themeString;
    switch (mode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      default:
        themeString = 'dark';
        break;
    }
    _storageService.saveThemeMode(themeString);
  }

  // Check if current theme is dark
  bool get isDarkMode {
    if (_themeMode.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode.value == ThemeMode.dark;
  }
}

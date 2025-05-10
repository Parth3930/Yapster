import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../values/colors.dart';
import 'theme_controller.dart';
// import '../values/fonts.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light().copyWith(
      primary: AppColors.primaryColor,
      secondary: AppColors.accentColor,
      onSurface: AppColors.textDark,
      onPrimary: Colors.white,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primaryColor: AppColors.primaryColorDark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: AppColors.primaryColorDark,
      secondary: AppColors.accentColorDark,
    ),
  );

  // Method to toggle between light and dark themes
  static void changeTheme() {
    final themeController = Get.find<ThemeController>();
    themeController.toggleTheme();
  }
}

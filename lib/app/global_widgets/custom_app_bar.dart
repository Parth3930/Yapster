import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/theme_controller.dart';
import '../core/values/colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showThemeToggle;
  final Color? backgroundColor;
  final Color? titleColor;
  final double elevation;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.showThemeToggle = true,
    this.backgroundColor,
    this.titleColor,
    this.elevation = 0,
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(() {
      final bool isDark = themeController.isDarkMode;
      List<Widget> actionWidgets = [];

      // Add theme toggle button if enabled
      if (showThemeToggle) {
        actionWidgets.add(
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => themeController.toggleTheme(),
          ),
        );
      }

      // Add any additional action widgets
      if (actions != null) {
        actionWidgets.addAll(actions!);
      }

      return AppBar(
        title: Text(
          title,
          style: Get.textTheme.titleLarge?.copyWith(
            color: titleColor ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor:
            backgroundColor ??
            (isDark ? AppColors.primaryColorDark : AppColors.primaryColor),
        elevation: elevation,
        automaticallyImplyLeading: showBackButton,
        leading: leading,
        actions: actionWidgets,
        bottom: bottom,
        iconTheme: const IconThemeData(color: Colors.white),
      );
    });
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

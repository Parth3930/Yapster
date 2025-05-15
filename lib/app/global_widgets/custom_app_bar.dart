import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_controller.dart';
import '../core/values/colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
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

      // Add any additional action widgets
      if (actions != null) {
        actionWidgets.addAll(actions!);
      }

      return AppBar(
        title: Text(
          title,
          style: Get.textTheme.titleLarge?.copyWith(
            color: titleColor ?? Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.dongle().fontFamily,
          ),
        ),
        centerTitle: true,
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

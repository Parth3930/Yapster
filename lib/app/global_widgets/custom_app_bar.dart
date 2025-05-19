import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
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
          fontFamily: GoogleFonts.dongle().fontFamily,
        ),
      ),
      centerTitle: true,
      backgroundColor: AppColors.primaryColorDark,
      elevation: elevation,
      automaticallyImplyLeading: showBackButton,
      leading: leading,
      actions: actionWidgets,
      bottom: bottom,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/values/colors.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;
  final double strokeWidth;
  final bool isOverlay;
  final Color? overlayColor;
  final Color? textColor;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.isOverlay = false,
    this.overlayColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final loadingColor = color ?? AppColors.primaryColor;
    final messageColor = textColor ?? (Get.isDarkMode ? AppColors.textWhite : AppColors.textDark);
    
    final loadingWidget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
            strokeWidth: strokeWidth,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: Get.textTheme.bodyMedium?.copyWith(
              color: messageColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (isOverlay) {
      return Container(
        color: overlayColor ?? Colors.black.withOpacity(0.5),
        child: Center(child: loadingWidget),
      );
    }

    return Center(child: loadingWidget);
  }

  // Static method to show a fullscreen loading overlay
  static void show({String? message, Color? color, Color? textColor}) {
    Get.dialog(
      LoadingWidget(
        message: message,
        color: color,
        textColor: textColor,
        isOverlay: true
      ),
      barrierDismissible: false,
    );
  }

  // Static method to hide the loading overlay
  static void hide() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }
}

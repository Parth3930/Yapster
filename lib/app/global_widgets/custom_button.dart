import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final bool isLoading;
  final IconData? icon;
  final Widget? imageIcon;
  final String? fontFamily;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 50.0,
    this.isLoading = false,
    this.icon,
    this.imageIcon,
    this.fontFamily,
  }) : assert(
         icon == null || imageIcon == null,
         'Cannot provide both icon and imageIcon',
       );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: Get.theme.primaryColor,
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.0,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon)],
                    if (imageIcon != null) ...[
                      imageIcon!,
                      const SizedBox(width: 15),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        fontFamily:
                            fontFamily == ''
                                ? GoogleFonts.roboto().fontFamily
                                : fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor ?? Colors.black,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

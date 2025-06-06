import 'package:flutter/material.dart';
import 'dart:ui';

/// A reusable individual post action button that can be used standalone
class PostActionButton extends StatelessWidget {
  final String assetPath;
  final String? text;
  final VoidCallback onTap;
  final bool glassy;
  final double size;
  final Color? textColor;

  const PostActionButton({
    Key? key,
    required this.assetPath,
    this.text,
    required this.onTap,
    this.glassy = false,
    this.size = 25,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconWidget = Image.asset(assetPath, width: size, height: size);

    if (text != null) {
      return GestureDetector(
        onTap: onTap,
        child:
            glassy
                ? _buildGlassyButton(iconWidget)
                : _buildRegularButton(iconWidget),
      );
    } else {
      return GestureDetector(
        onTap: onTap,
        child: glassy ? _buildGlassyIconOnly() : _buildRegularIconOnly(),
      );
    }
  }

  Widget _buildRegularButton(Widget iconWidget) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        if (text != null) ...[
          SizedBox(width: 6),
          Text(
            text!,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGlassyButton(Widget iconWidget) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              if (text != null) ...[
                SizedBox(width: 6),
                Text(
                  text!,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegularIconOnly() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Image.asset(assetPath, width: size, height: size),
    );
  }

  Widget _buildGlassyIconOnly() {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle),
          padding: const EdgeInsets.all(8),
          child: Image.asset(assetPath, width: size, height: size),
        ),
      ),
    );
  }
}

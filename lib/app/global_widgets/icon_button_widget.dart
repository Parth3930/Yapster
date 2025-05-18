import 'package:flutter/material.dart';

class IconButtonWidget extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final VoidCallback onTap;

  const IconButtonWidget({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(assetPath, width: width, height: height),
    );
  }
}

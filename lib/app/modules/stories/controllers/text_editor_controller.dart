import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TextEditorController extends GetxController {
  // Text properties
  final Rx<Color> textColor = Colors.white.obs;
  final Rx<Color?> backgroundColor = Colors.transparent.obs;
  final RxDouble textSize = 20.0.obs;
  final RxBool isBold = false.obs;

  // RGB values for text color slider
  final RxDouble textRed = 255.0.obs;
  final RxDouble textGreen = 255.0.obs;
  final RxDouble textBlue = 255.0.obs;

  // RGB values for background color slider
  final RxDouble bgRed = 0.0.obs;
  final RxDouble bgGreen = 0.0.obs;
  final RxDouble bgBlue = 0.0.obs;

  // Flag to determine which color is being edited
  final RxBool editingBackground = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize RGB values based on current colors
    updateTextRgbFromColor(textColor.value);
    if (backgroundColor.value != null) {
      updateBgRgbFromColor(backgroundColor.value!);
    }

    // Listen for color changes
    ever(textColor, updateTextRgbFromColor);
    ever(backgroundColor, (color) {
      if (color != null) {
        updateBgRgbFromColor(color);
      }
    });
  }

  void updateTextRgbFromColor(Color color) {
    textRed.value = color.red.toDouble();
    textGreen.value = color.green.toDouble();
    textBlue.value = color.blue.toDouble();
  }

  void updateBgRgbFromColor(Color color) {
    bgRed.value = color.red.toDouble();
    bgGreen.value = color.green.toDouble();
    bgBlue.value = color.blue.toDouble();
  }

  void updateTextColorFromRgb() {
    textColor.value = Color.fromRGBO(
      textRed.value.toInt(),
      textGreen.value.toInt(),
      textBlue.value.toInt(),
      1.0,
    );
  }

  void updateBgColorFromRgb() {
    backgroundColor.value = Color.fromRGBO(
      bgRed.value.toInt(),
      bgGreen.value.toInt(),
      bgBlue.value.toInt(),
      1.0,
    );
  }

  void toggleBackgroundColor() {
    backgroundColor.value =
        backgroundColor.value == Colors.transparent
            ? Colors.black.withOpacity(0.7)
            : Colors.transparent;
  }

  void increaseTextSize() {
    textSize.value = (textSize.value + 2).clamp(16.0, 72.0);
  }

  void decreaseTextSize() {
    textSize.value = (textSize.value - 2).clamp(16.0, 72.0);
  }

  void toggleFontWeight() {
    isBold.value = !isBold.value;
  }
}

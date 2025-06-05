import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TextController extends GetxController {
  static TextController get to => Get.find<TextController>();
  final RxList<TextItem> textItems = <TextItem>[].obs;
  final RxInt selectedTextIndex = (-1).obs;
  final textEditingController = TextEditingController();
  final focusNode = FocusNode();
  final isEditing = false.obs;

  // Text styling
  final textColor = Colors.black.obs;
  final backgroundColor = Colors.white.obs;
  final fontSize = 20.0.obs;
  final fontWeight = FontWeight.normal.obs;
  final textAlign = TextAlign.center.obs;
  final isBold = false.obs;

  void addText(Offset position) {
    final newText = TextItem(
      text: 'Tap to edit',
      position: position,
      color: textColor.value,
      backgroundColor: backgroundColor.value,
      fontSize: fontSize.value,
      fontWeight: fontWeight.value,
      textAlign: textAlign.value,
    );
    textItems.add(newText);
    selectedTextIndex.value = textItems.length - 1;
    startEditing(textItems.length - 1);
  }

  void updateText(String newText) {
    if (selectedTextIndex.value != -1) {
      final updatedItem = textItems[selectedTextIndex.value].copyWith(
        text: newText,
      );
      textItems[selectedTextIndex.value] = updatedItem;
      textItems.refresh();
    }
  }

  void stopEditing() {
    isEditing.value = false;
    selectedTextIndex.value = -1;
    focusNode.unfocus();
  }

  void updateTextPosition(int index, Offset newPosition) {
    if (index >= 0 && index < textItems.length) {
      final updatedItem = textItems[index].copyWith(position: newPosition);
      textItems[index] = updatedItem;
      textItems.refresh();
    }
  }

  void updateTextStyle() {
    if (selectedTextIndex.value >= 0 &&
        selectedTextIndex.value < textItems.length) {
      textItems[selectedTextIndex.value] = textItems[selectedTextIndex.value]
          .copyWith(
            color: textColor.value,
            backgroundColor: backgroundColor.value,
            fontSize: fontSize.value,
            fontWeight: fontWeight.value,
            textAlign: textAlign.value,
          );
      textItems.refresh();
    }
  }

  void startEditing(int index) {
    selectedTextIndex.value = index;
    final item = textItems[index];

    // If it's the default text, clear it when starting to edit
    if (item.text == 'Tap to edit') {
      textEditingController.text = '';
    } else {
      textEditingController.text = item.text;
    }

    textColor.value = item.color;
    backgroundColor.value = item.backgroundColor;
    fontSize.value = item.fontSize;
    fontWeight.value = item.fontWeight;
    textAlign.value = item.textAlign;
    isBold.value = item.fontWeight == FontWeight.bold;
    isEditing.value = true;
    focusNode.requestFocus();
  }

  void toggleBold() {
    isBold.value = !isBold.value;
    fontWeight.value = isBold.value ? FontWeight.bold : FontWeight.normal;
    updateTextStyle();
  }

  void changeTextColor(Color color) {
    textColor.value = color;
    updateTextStyle();
  }

  void changeBackgroundColor(Color color) {
    backgroundColor.value = color;
    updateTextStyle();
  }

  void changeFontSize(double size) {
    fontSize.value = size;
    updateTextStyle();
  }

  void deleteSelectedText() {
    if (selectedTextIndex.value >= 0 &&
        selectedTextIndex.value < textItems.length) {
      textItems.removeAt(selectedTextIndex.value);
      if (textItems.isEmpty) {
        selectedTextIndex.value = -1;
      } else {
        selectedTextIndex.value = textItems.length - 1;
      }
      isEditing.value = false;
    }
  }

  void finishEditing() {
    isEditing.value = false;
    focusNode.unfocus();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}

class TextItem {
  String text;
  Offset position;
  Color color;
  Color backgroundColor;
  double fontSize;
  FontWeight fontWeight;
  TextAlign textAlign;

  TextItem({
    required this.text,
    required this.position,
    this.color = Colors.black,
    this.backgroundColor = Colors.white,
    this.fontSize = 24.0,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.center,
  });

  TextItem copyWith({
    String? text,
    Offset? position,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
  }) {
    return TextItem(
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
    );
  }
}

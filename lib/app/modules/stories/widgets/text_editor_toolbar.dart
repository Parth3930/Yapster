import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';

class TextEditorToolbar extends StatelessWidget {
  final TextEditingController textController;
  final Rx<Color> textColor;
  final Rx<Color> textBackgroundColor;
  final RxDouble textSize;
  final Rx<FontWeight> textFontWeight;
  final VoidCallback onAddText;
  final List<Color> quickColors;

  const TextEditorToolbar({
    Key? key,
    required this.textController,
    required this.textColor,
    required this.textBackgroundColor,
    required this.textSize,
    required this.textFontWeight,
    required this.onAddText,
    required this.quickColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      top: MediaQuery.of(context).size.height * 0.2,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarButton(
              icon: Icons.format_color_text,
              isSelected: false,
              onTap: _showColorPicker,
              color: textColor.value,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.format_color_fill,
              isSelected: false,
              onTap: _toggleBackgroundColor,
              color: textBackgroundColor.value == Colors.transparent 
                  ? Colors.white 
                  : textBackgroundColor.value,
              isBackground: true,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.add,
              isSelected: false,
              onTap: _increaseTextSize,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.remove,
              isSelected: false,
              onTap: _decreaseTextSize,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.format_bold,
              isSelected: textFontWeight.value == FontWeight.bold,
              onTap: _toggleFontWeight,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.check,
              isSelected: false,
              onTap: onAddText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? color,
    bool isBackground = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: isBackground && color != null
              ? Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                  child: color == Colors.transparent
                      ? const Icon(Icons.not_interested, size: 16, color: Colors.white)
                      : null,
                )
              : Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    child: ColorPicker(
                      pickerColor: textColor.value,
                      onColorChanged: (color) {
                        textColor.value = color;
                      },
                      enableAlpha: true,
                      displayThumbColor: true,
                      pickerAreaBorderRadius: BorderRadius.circular(16),
                      portraitOnly: true,
                      labelTypes: const [],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: quickColors.length,
                  itemBuilder: (context, index) {
                    final color = quickColors[index];
                    return GestureDetector(
                      onTap: () {
                        textColor.value = color;
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: textColor.value == color 
                                ? Colors.white 
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: color == Colors.transparent
                            ? const Icon(Icons.not_interested, size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleBackgroundColor() {
    textBackgroundColor.value = textBackgroundColor.value == Colors.transparent
        ? Colors.black.withOpacity(0.7)
        : Colors.transparent;
  }

  void _increaseTextSize() {
    textSize.value = (textSize.value + 2).clamp(16.0, 72.0);
  }

  void _decreaseTextSize() {
    textSize.value = (textSize.value - 2).clamp(16.0, 72.0);
  }

  void _toggleFontWeight() {
    textFontWeight.value = textFontWeight.value == FontWeight.bold
        ? FontWeight.normal
        : FontWeight.bold;
  }
}

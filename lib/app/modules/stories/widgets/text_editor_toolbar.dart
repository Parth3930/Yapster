import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/text_editor_controller.dart';

class TextEditorToolbar extends GetView<TextEditorController> {
  final VoidCallback onDone;

  const TextEditorToolbar({super.key, required this.onDone});

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
              onTap: () => _showColorPicker(context),
              color: controller.textColor.value,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.format_color_fill,
              isSelected: false,
              onTap: () => _showColorPicker(context, isBackground: true),
              color:
                  controller.backgroundColor.value == Colors.transparent
                      ? Colors.white
                      : controller.backgroundColor.value ?? Colors.transparent,
              isBackground: true,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.add,
              isSelected: false,
              onTap: controller.increaseTextSize,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.remove,
              isSelected: false,
              onTap: controller.decreaseTextSize,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.format_bold,
              isSelected: controller.isBold.value,
              onTap: controller.toggleFontWeight,
            ),
            const SizedBox(height: 12),
            _buildToolbarButton(
              icon: Icons.check,
              isSelected: false,
              onTap: onDone,
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
          border: Border.all(color: Colors.white, width: isSelected ? 2 : 1),
        ),
        child: Center(
          child:
              isBackground && color != null
                  ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child:
                        color == Colors.transparent
                            ? const Icon(
                              Icons.not_interested,
                              size: 16,
                              color: Colors.white,
                            )
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

  void _showColorPicker(BuildContext context, {bool isBackground = false}) {
    controller.editingBackground.value = isBackground;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBackground ? 'Select Background Color' : 'Select Text Color',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),

              // Color preview
              Obx(() {
                final previewColor =
                    isBackground
                        ? (controller.backgroundColor.value ??
                            Colors.transparent)
                        : controller.textColor.value;
                return Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: previewColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      previewColor == Colors.transparent
                          ? const Icon(
                            Icons.not_interested,
                            size: 30,
                            color: Colors.white,
                          )
                          : null,
                );
              }),

              const SizedBox(height: 16),

              // RGB Color sliders
              Obx(() {
                final redValue =
                    isBackground
                        ? controller.bgRed.value
                        : controller.textRed.value;
                final greenValue =
                    isBackground
                        ? controller.bgGreen.value
                        : controller.textGreen.value;
                final blueValue =
                    isBackground
                        ? controller.bgBlue.value
                        : controller.textBlue.value;

                return Column(
                  children: [
                    // Red slider
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text(
                          'R',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: redValue,
                            min: 0,
                            max: 255,
                            activeColor: Colors.red,
                            inactiveColor: Colors.red.withOpacity(0.3),
                            onChanged: (value) {
                              if (isBackground) {
                                controller.bgRed.value = value;
                                controller.updateBgColorFromRgb();
                              } else {
                                controller.textRed.value = value;
                                controller.updateTextColorFromRgb();
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${redValue.toInt()}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    // Green slider
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text(
                          'G',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: greenValue,
                            min: 0,
                            max: 255,
                            activeColor: Colors.green,
                            inactiveColor: Colors.green.withOpacity(0.3),
                            onChanged: (value) {
                              if (isBackground) {
                                controller.bgGreen.value = value;
                                controller.updateBgColorFromRgb();
                              } else {
                                controller.textGreen.value = value;
                                controller.updateTextColorFromRgb();
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${greenValue.toInt()}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    // Blue slider
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text(
                          'B',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: blueValue,
                            min: 0,
                            max: 255,
                            activeColor: Colors.blue,
                            inactiveColor: Colors.blue.withOpacity(0.3),
                            onChanged: (value) {
                              if (isBackground) {
                                controller.bgBlue.value = value;
                                controller.updateBgColorFromRgb();
                              } else {
                                controller.textBlue.value = value;
                                controller.updateTextColorFromRgb();
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${blueValue.toInt()}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),

              // Transparent option for background
              if (isBackground)
                (TextButton.icon(
                  icon: const Icon(Icons.not_interested, color: Colors.white),
                  label: const Text(
                    'Transparent',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    controller.backgroundColor.value = null;
                    Navigator.pop(context);
                  },
                )),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }
}

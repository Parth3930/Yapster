import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/text_controller.dart';

class TextEditingControls extends StatelessWidget {
  final TextController controller;

  const TextEditingControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isEditing.value) return const SizedBox.shrink();

      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.black54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Bold toggle
              IconButton(
                icon: Icon(
                  Icons.format_bold,
                  color: controller.isBold.value ? Colors.blue : Colors.white,
                ),
                onPressed: controller.toggleBold,
              ),

              // Text color picker
              PopupMenuButton<Color>(
                icon: const Icon(Icons.color_lens, color: Colors.white),
                onSelected: controller.changeTextColor,
                itemBuilder:
                    (context) => [
                      _buildColorMenuItem(Colors.white, 'White'),
                      _buildColorMenuItem(Colors.black, 'Black'),
                      _buildColorMenuItem(Colors.red, 'Red'),
                      _buildColorMenuItem(Colors.green, 'Green'),
                      _buildColorMenuItem(Colors.blue, 'Blue'),
                      _buildColorMenuItem(Colors.yellow, 'Yellow'),
                    ],
              ),

              // Background color picker
              PopupMenuButton<Color>(
                icon: const Icon(Icons.format_color_fill, color: Colors.white),
                onSelected: controller.changeBackgroundColor,
                itemBuilder:
                    (context) => [
                      _buildColorMenuItem(Colors.transparent, 'Transparent'),
                      _buildColorMenuItem(
                        Colors.black.withOpacity(0.5),
                        'Black',
                      ),
                      _buildColorMenuItem(
                        Colors.white.withOpacity(0.5),
                        'White',
                      ),
                      _buildColorMenuItem(Colors.red.withOpacity(0.5), 'Red'),
                      _buildColorMenuItem(
                        Colors.green.withOpacity(0.5),
                        'Green',
                      ),
                      _buildColorMenuItem(Colors.blue.withOpacity(0.5), 'Blue'),
                    ],
              ),

              // Font size slider
              Expanded(
                child: Slider(
                  value: controller.fontSize.value,
                  min: 12,
                  max: 72,
                  divisions: 10,
                  label: '${controller.fontSize.value.round()}',
                  onChanged: (value) {
                    controller.changeFontSize(value);
                  },
                ),
              ),

              // Text alignment
              IconButton(
                icon: const Icon(Icons.format_align_left, color: Colors.white),
                onPressed: () => controller.textAlign.value = TextAlign.left,
              ),
              IconButton(
                icon: const Icon(
                  Icons.format_align_center,
                  color: Colors.white,
                ),
                onPressed: () => controller.textAlign.value = TextAlign.center,
              ),
              IconButton(
                icon: const Icon(Icons.format_align_right, color: Colors.white),
                onPressed: () => controller.textAlign.value = TextAlign.right,
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: controller.deleteSelectedText,
              ),

              // Done button
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: controller.finishEditing,
              ),
            ],
          ),
        ),
      );
    });
  }

  PopupMenuItem<Color> _buildColorMenuItem(Color color, String label) {
    return PopupMenuItem<Color>(
      value: color,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            color: color,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(label),
        ],
      ),
    );
  }
}

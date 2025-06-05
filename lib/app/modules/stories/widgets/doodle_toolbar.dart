import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/doodle_controller.dart';

class DoodleToolbar extends GetView<DoodleController> {
  const DoodleToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Stroke width slider
            Row(
              children: [
                const Icon(Icons.brush, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: controller.currentWidth.value,
                    min: 1,
                    max: 20,
                    onChanged: (value) {
                      controller.currentWidth.value = value;
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.grey,
                  ),
                ),
                Text(
                  '${controller.currentWidth.value.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Color preview
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: controller.currentColor.value,
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
            ),

            // RGB Color sliders
            Obx(
              () => Column(
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
                          value: controller.red.value,
                          min: 0,
                          max: 255,
                          activeColor: Colors.red,
                          inactiveColor: Colors.red.withOpacity(0.3),
                          onChanged: (value) {
                            controller.red.value = value;
                            controller.updateColorFromRgb();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${controller.red.value.toInt()}',
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
                          value: controller.green.value,
                          min: 0,
                          max: 255,
                          activeColor: Colors.green,
                          inactiveColor: Colors.green.withOpacity(0.3),
                          onChanged: (value) {
                            controller.green.value = value;
                            controller.updateColorFromRgb();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${controller.green.value.toInt()}',
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
                          value: controller.blue.value,
                          min: 0,
                          max: 255,
                          activeColor: Colors.blue,
                          inactiveColor: Colors.blue.withOpacity(0.3),
                          onChanged: (value) {
                            controller.blue.value = value;
                            controller.updateColorFromRgb();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${controller.blue.value.toInt()}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.undo, 'Undo', controller.undo),
                _buildActionButton(Icons.clear, 'Clear', controller.clear),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

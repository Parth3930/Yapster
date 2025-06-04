import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DoodleToolbar extends StatelessWidget {
  final Rx<Color> doodleColor;
  final RxDouble doodleStrokeWidth;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final List<Color> quickColors;

  const DoodleToolbar({
    Key? key,
    required this.doodleColor,
    required this.doodleStrokeWidth,
    required this.onClear,
    required this.onUndo,
    required this.quickColors,
  }) : super(key: key);

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
                    value: doodleStrokeWidth.value,
                    min: 1,
                    max: 20,
                    onChanged: (value) {
                      doodleStrokeWidth.value = value;
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.grey,
                  ),
                ),
                Text(
                  '${doodleStrokeWidth.value.toInt()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Color selection
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: quickColors.length,
                itemBuilder: (context, index) {
                  final color = quickColors[index];
                  return GestureDetector(
                    onTap: () {
                      doodleColor.value = color;
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: doodleColor.value == color 
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
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.undo, 'Undo', onUndo),
                _buildActionButton(Icons.clear, 'Clear', onClear),
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
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/drawing_point.dart';

class DoodleController extends GetxController {
  // Drawing points list
  final RxList<DrawingPoint> drawingPoints = <DrawingPoint>[].obs;

  // History for redo functionality
  final RxList<DrawingPoint> redoHistory = <DrawingPoint>[].obs;

  // Current color and stroke width
  final Rx<Color> currentColor =
      const Color(0xFFF44336).obs; // Default red (primary shade of Colors.red)
  final RxDouble currentWidth = 5.0.obs;

  // Store the last slider position to prevent jumping
  final RxDouble lastSliderPosition = 0.0.obs;

  // RGB values for color slider
  final RxDouble red = 255.0.obs;
  final RxDouble green = 0.0.obs;
  final RxDouble blue = 0.0.obs;

  // Current drawing point
  DrawingPoint? currentDrawingPoint;

  @override
  void onInit() {
    super.onInit();
    // Listen for color changes
    ever(currentColor, updateRgbFromColor);

    // Initialize the slider position based on the default color
    final HSVColor hsvColor = HSVColor.fromColor(currentColor.value);
    lastSliderPosition.value = hsvColor.hue / 359.999;
  }

  void updateRgbFromColor(Color color) {
    red.value = color.red.toDouble();
    green.value = color.green.toDouble();
    blue.value = color.blue.toDouble();
  }

  void updateColorFromRgb() {
    currentColor.value = Color.fromRGBO(
      red.value.toInt(),
      green.value.toInt(),
      blue.value.toInt(),
      1.0,
    );
  }

  void handleDoodleStart(DragStartDetails details) {
    currentDrawingPoint = DrawingPoint(
      points: [details.localPosition],
      color: currentColor.value,
      width: currentWidth.value,
    );

    // Add the initial point to the drawing points list
    drawingPoints.add(currentDrawingPoint!);
  }

  void handleDoodleUpdate(DragUpdateDetails details) {
    if (currentDrawingPoint == null) return;

    // Remove the last point (we'll add an updated version)
    if (drawingPoints.isNotEmpty) {
      drawingPoints.removeLast();
    }

    // Add the new point to the current drawing point
    currentDrawingPoint!.points.add(details.localPosition);

    // Add the updated drawing point back to the list
    drawingPoints.add(currentDrawingPoint!);
  }

  void handleDoodleEnd(DragEndDetails details) {
    // Reset the current drawing point
    currentDrawingPoint = null;
  }

  void clear() {
    // Clear both drawing points and redo history
    drawingPoints.clear();
    redoHistory.clear();
  }

  void undo() {
    if (drawingPoints.isNotEmpty) {
      // Move the last drawing point to redo history
      redoHistory.add(drawingPoints.last);
      drawingPoints.removeLast();
    }
  }

  void redo() {
    if (redoHistory.isNotEmpty) {
      // Move the last item from redo history back to drawing points
      drawingPoints.add(redoHistory.last);
      redoHistory.removeLast();
    }
  }

  void erase() {
    // Set color to transparent for eraser functionality
    currentColor.value = Colors.transparent;
  }
}

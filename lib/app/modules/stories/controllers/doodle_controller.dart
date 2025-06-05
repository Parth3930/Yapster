import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/drawing_point.dart';

class DoodleController extends GetxController {
  // Drawing points list
  final RxList<DrawingPoint> drawingPoints = <DrawingPoint>[].obs;

  // Current color and stroke width
  final Rx<Color> currentColor = Colors.red.obs;
  final RxDouble currentWidth = 5.0.obs;

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
    drawingPoints.clear();
  }

  void undo() {
    if (drawingPoints.isNotEmpty) {
      drawingPoints.removeLast();
    }
  }
}

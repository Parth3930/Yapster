import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/stories/controllers/text_controller.dart';

class TextWidget extends StatefulWidget {
  final TextItem textItem;
  final int index;
  final Function(Offset) onDragEnd;
  final Function() onTap;

  const TextWidget({
    super.key,
    required this.textItem,
    required this.index,
    required this.onDragEnd,
    required this.onTap,
  });

  @override
  State<TextWidget> createState() => _TextWidgetState();
}

class _TextWidgetState extends State<TextWidget> {
  final TextController _controller = Get.find<TextController>();
  double _scaleFactor = 1.0;
  double _baseFontSize = 24.0;
  double _rotation = 0.0;
  double _baseRotation = 0.0;
  Offset? _initialFocalPoint;
  Offset? _initialPosition;

  @override
  void initState() {
    super.initState();
    _baseFontSize = widget.textItem.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = _controller.selectedTextIndex.value == widget.index;

      return Positioned(
        left: widget.textItem.position.dx,
        top: widget.textItem.position.dy,
        child: GestureDetector(
          onTap: () {
            _controller.selectedTextIndex.value = widget.index;
            widget.onTap();
          },
          onDoubleTap: () {
            _controller.startEditing(widget.index);
          },
          onScaleStart: (details) {
            if (!isSelected) {
              _controller.selectedTextIndex.value = widget.index;
            }
            _baseFontSize = widget.textItem.fontSize;
            _baseRotation = _rotation;
            _initialFocalPoint = details.focalPoint;
            _initialPosition = widget.textItem.position;
          },
          onScaleUpdate: (details) {
            setState(() {
              // Always handle position changes
              final delta = details.focalPoint - _initialFocalPoint!;
              widget.textItem.position = _initialPosition! + delta;

              // Handle scaling and rotation if more than one finger
              if (details.scale != 1.0 || details.rotation != 0.0) {
                _scaleFactor = details.scale;
                _rotation = _baseRotation + details.rotation;

                // Update the font size based on scale
                final newFontSize = (_baseFontSize * _scaleFactor).clamp(
                  12.0,
                  72.0,
                );
                _controller.changeFontSize(newFontSize);
              }
            });
          },
          onScaleEnd: (details) {
            _scaleFactor = 1.0;
            _baseRotation = _rotation;
            widget.onDragEnd(
              Offset(widget.textItem.position.dx, widget.textItem.position.dy),
            );
          },
          child: Transform.rotate(
            angle: _rotation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.textItem.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border:
                    isSelected
                        ? Border.all(color: Colors.blue, width: 2.0)
                        : Border.all(color: Colors.grey.shade300, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.textItem.text.isEmpty
                    ? 'Tap to edit'
                    : widget.textItem.text,
                style: TextStyle(
                  color: widget.textItem.color,
                  fontSize: widget.textItem.fontSize,
                  fontWeight: widget.textItem.fontWeight,
                ),
                textAlign: widget.textItem.textAlign,
                maxLines: null, // Allow multiple lines
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      );
    });
  }
}

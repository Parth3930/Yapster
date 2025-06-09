import 'package:flutter/material.dart';
import 'package:yapster/app/modules/stories/models/text_element.dart';

class StoryTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Offset position;
  final Color textColor;
  final Color backgroundColor;
  final double textSize;
  final FontWeight fontWeight;
  final ValueChanged<TextElement> onTextUpdated;
  final VoidCallback onTap;
  final bool isEditing;

  const StoryTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.position,
    required this.textColor,
    required this.backgroundColor,
    required this.textSize,
    required this.fontWeight,
    required this.onTextUpdated,
    required this.onTap,
    this.isEditing = false,
  });

  @override
  State<StoryTextField> createState() => _StoryTextFieldState();
}

class _StoryTextFieldState extends State<StoryTextField> {
  bool _isDragging = false;
  late Offset _position;
  Offset? _dragStart;
  Offset? _dragPosition;

  @override
  void initState() {
    super.initState();
    _position = widget.position;
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(StoryTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _position = widget.position;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus) {
      widget.onTap();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.isEditing) {
      setState(() {
        _isDragging = true;
        _dragStart = _position;
        _dragPosition = details.globalPosition;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDragging && _dragStart != null && _dragPosition != null) {
      final offset = details.globalPosition - _dragPosition!;
      setState(() {
        _position = _dragStart! + offset;
        _dragPosition = details.globalPosition;
      });
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragStart = null;
        _dragPosition = null;
      });
      widget.onTextUpdated(
        TextElement(
          text: widget.controller.text,
          position: _position,
          color: widget.textColor,
          backgroundColor: widget.backgroundColor,
          size: widget.textSize,
          fontWeight: widget.fontWeight,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                widget.backgroundColor != Colors.transparent
                    ? widget.backgroundColor
                    : null,
            borderRadius: BorderRadius.circular(8),
            border:
                widget.isEditing
                    ? Border.all(color: Colors.white, width: 1)
                    : null,
          ),
          child: IntrinsicWidth(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: TextStyle(
                color: widget.textColor,
                fontSize: widget.textSize,
                fontWeight: widget.fontWeight,
                decoration: TextDecoration.none,
              ),
              decoration: InputDecoration.collapsed(
                hintText: 'Type something...',
                hintStyle: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontSize: widget.textSize,
                  fontWeight: widget.fontWeight,
                ),
              ),
              textAlign: TextAlign.center,
              maxLines: null,
              onChanged: (_) {
                widget.onTextUpdated(
                  TextElement(
                    text: widget.controller.text,
                    position: _position,
                    color: widget.textColor,
                    backgroundColor: widget.backgroundColor,
                    size: widget.textSize,
                    fontWeight: widget.fontWeight,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// File: lib/app/core/animations/message_animations.dart
import 'package:flutter/material.dart';

/// Simple and clean message animation configurations
class MessageAnimationConfig {
  final Duration duration;
  final Curve curve;
  final Offset slideFrom;
  final Offset slideTo;
  final double scaleFrom;
  final double scaleTo;
  final double opacityFrom;
  final double opacityTo;

  const MessageAnimationConfig({
    required this.duration,
    required this.curve,
    required this.slideFrom,
    required this.slideTo,
    this.scaleFrom = 1.0,
    this.scaleTo = 1.0,
    this.opacityFrom = 1.0,
    this.opacityTo = 1.0,
  });

  /// Top drop-in arc motion for sent messages
  static MessageAnimationConfig slideInFromRight() {
    return const MessageAnimationConfig(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      slideFrom: Offset(0.3, -0.5), // Start from top-right
      slideTo: Offset.zero,
      scaleFrom: 0.0,
      scaleTo: 1.0,
      opacityFrom: 0.0,
      opacityTo: 1.0,
    );
  }

  /// Top drop-in arc motion for received messages
  static MessageAnimationConfig slideInFromLeft() {
    return const MessageAnimationConfig(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      slideFrom: Offset(-0.3, -0.5), // Start from top-left
      slideTo: Offset.zero,
      scaleFrom: 0.0,
      scaleTo: 1.0,
      opacityFrom: 0.0,
      opacityTo: 1.0,
    );
  }

  /// Smooth fade-scale out to right for deleting sent messages
  static MessageAnimationConfig slideOutToRight() {
    return const MessageAnimationConfig(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      slideFrom: Offset.zero,
      slideTo: Offset(0.5, -0.2),
      scaleFrom: 1.0,
      scaleTo: 0.0,
      opacityFrom: 1.0,
      opacityTo: 0.0,
    );
  }

  /// Smooth fade-scale out to left for deleting received messages
  static MessageAnimationConfig slideOutToLeft() {
    return const MessageAnimationConfig(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      slideFrom: Offset.zero,
      slideTo: Offset(-0.5, -0.2),
      scaleFrom: 1.0,
      scaleTo: 0.0,
      opacityFrom: 1.0,
      opacityTo: 0.0,
    );
  }

  /// Springy and responsive tap feedback
  static MessageAnimationConfig tapBounce() {
    return const MessageAnimationConfig(
      duration: Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      slideFrom: Offset.zero,
      slideTo: Offset.zero,
      scaleFrom: 1.0,
      scaleTo: 0.95,
      opacityFrom: 1.0,
      opacityTo: 0.8,
    );
  }
}

/// Simple animation controller for messages
class MessageAnimationController {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  final MessageAnimationConfig config;

  MessageAnimationController({
    required this.config,
    required TickerProvider vsync,
  }) {
    _controller = AnimationController(duration: config.duration, vsync: vsync);

    _slideAnimation = Tween<Offset>(
      begin: config.slideFrom,
      end: config.slideTo,
    ).animate(CurvedAnimation(parent: _controller, curve: config.curve));

    _scaleAnimation = Tween<double>(
      begin: config.scaleFrom,
      end: config.scaleTo,
    ).animate(CurvedAnimation(parent: _controller, curve: config.curve));

    _opacityAnimation = Tween<double>(
      begin: config.opacityFrom,
      end: config.opacityTo,
    ).animate(CurvedAnimation(parent: _controller, curve: config.curve));
  }

  /// Current animation values
  Offset get slideValue => _slideAnimation.value;
  double get scaleValue => _scaleAnimation.value;
  double get opacityValue => _opacityAnimation.value;

  /// Animation control
  Future<void> forward() => _controller.forward();
  Future<void> reverse() => _controller.reverse();
  void reset() => _controller.reset();

  /// Listeners
  void addStatusListener(AnimationStatusListener listener) {
    _controller.addStatusListener(listener);
  }

  void addListener(VoidCallback listener) {
    _controller.addListener(listener);
  }

  /// Access to underlying controller
  AnimationController get controller => _controller;

  /// Cleanup
  void dispose() {
    _controller.dispose();
  }
}

/// Simple animated wrapper widget
class AnimatedMessageWidget extends StatefulWidget {
  final Widget child;
  final MessageAnimationConfig config;
  final bool autoStart;
  final VoidCallback? onComplete;

  const AnimatedMessageWidget({
    super.key,
    required this.child,
    required this.config,
    this.autoStart = true,
    this.onComplete,
  });

  @override
  State<AnimatedMessageWidget> createState() => _AnimatedMessageWidgetState();
}

class _AnimatedMessageWidgetState extends State<AnimatedMessageWidget>
    with SingleTickerProviderStateMixin {
  late MessageAnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = MessageAnimationController(
      config: widget.config,
      vsync: this,
    );

    if (widget.onComplete != null) {
      _animationController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete!();
        }
      });
    }

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController.forward();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController.controller,
      builder: (context, child) {
        return Transform.translate(
          offset:
              _animationController.slideValue *
              MediaQuery.of(context).size.width,
          child: Transform.scale(
            scale: _animationController.scaleValue,
            child: Opacity(
              opacity: _animationController.opacityValue,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }

  /// Expose controller for manual control
  MessageAnimationController get animationController => _animationController;
}

/// Utility functions for common animation patterns
class MessageAnimationUtils {
  /// Get the correct send animation based on message sender
  static MessageAnimationConfig getSendAnimation(bool isMe) {
    return isMe
        ? MessageAnimationConfig.slideInFromRight()
        : MessageAnimationConfig.slideInFromLeft();
  }

  /// Get the correct delete animation based on message sender
  static MessageAnimationConfig getDeleteAnimation(bool isMe) {
    return isMe
        ? MessageAnimationConfig.slideOutToLeft()
        : MessageAnimationConfig.slideOutToRight();
  }

  /// Create staggered animations for message lists
  static void staggeredAnimate({
    required List<MessageAnimationController> controllers,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    for (int i = 0; i < controllers.length; i++) {
      Future.delayed(delay * i, () {
        if (controllers[i].controller.isCompleted == false) {
          controllers[i].forward();
        }
      });
    }
  }
}

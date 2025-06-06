import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';

/// Widget that tracks when a post comes into view and measures time spent
class PostViewTracker extends StatefulWidget {
  final PostModel post;
  final Widget child;

  const PostViewTracker({
    super.key,
    required this.post,
    required this.child,
  });

  @override
  State<PostViewTracker> createState() => _PostViewTrackerState();
}

class _PostViewTrackerState extends State<PostViewTracker> {
  DateTime? _viewStartTime;
  bool _hasTrackedView = false;
  late final PostsFeedController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PostsFeedController>();
  }

  @override
  void dispose() {
    _trackTimeSpentIfNeeded();
    super.dispose();
  }

  void _trackTimeSpentIfNeeded() {
    if (_viewStartTime != null) {
      final timeSpent = DateTime.now().difference(_viewStartTime!);
      _controller.trackTimeSpent(widget.post.id, timeSpent);
    }
  }

  void _onPostVisible() {
    if (!_hasTrackedView) {
      _hasTrackedView = true;
      _viewStartTime = DateTime.now();
      
      // Track the view
      _controller.trackPostView(widget.post.id);
    }
  }

  void _onPostInvisible() {
    _trackTimeSpentIfNeeded();
    _viewStartTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('post_${widget.post.id}'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction;
        
        // Consider post visible if at least 50% is visible
        if (visiblePercentage >= 0.5) {
          _onPostVisible();
        } else if (visiblePercentage < 0.3) {
          _onPostInvisible();
        }
      },
      child: widget.child,
    );
  }
}

/// Simple visibility detector implementation
class VisibilityDetector extends StatefulWidget {
  final Key key;
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    required this.key,
    required this.child,
    required this.onVisibilityChanged,
  }) : super(key: key);

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  final GlobalKey _widgetKey = GlobalKey();
  double _lastVisibleFraction = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;

    final RenderBox? renderBox = 
        _widgetKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // Calculate visible area
    final visibleTop = position.dy < 0 ? 0 : position.dy;
    final visibleBottom = position.dy + size.height > screenSize.height 
        ? screenSize.height 
        : position.dy + size.height;
    
    final visibleHeight = visibleBottom - visibleTop;
    final visibleFraction = visibleHeight > 0 
        ? (visibleHeight / size.height).clamp(0.0, 1.0)
        : 0.0;

    // Only notify if visibility changed significantly
    if ((visibleFraction - _lastVisibleFraction).abs() > 0.1) {
      _lastVisibleFraction = visibleFraction;
      widget.onVisibilityChanged(VisibilityInfo(visibleFraction));
    }

    // Schedule next check
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) _checkVisibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _widgetKey,
      child: widget.child,
    );
  }
}

/// Information about widget visibility
class VisibilityInfo {
  final double visibleFraction;

  VisibilityInfo(this.visibleFraction);
}

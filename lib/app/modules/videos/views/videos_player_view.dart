import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';

import 'package:yapster/app/data/models/post_model.dart';

/// Full-screen vertical video feed similar to Instagram Reels / TikTok
class VideosPlayerView extends StatefulWidget {
  final List<PostModel> videos;
  final int initialIndex;

  const VideosPlayerView({
    Key? key,
    required this.videos,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<VideosPlayerView> createState() => _VideosPlayerViewState();
}

class _VideosPlayerViewState extends State<VideosPlayerView> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videos.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) => _VideoFeedItem(
          post: widget.videos[index],
          isActive: index == _currentPage,
        ),
      ),
    );
  }
}

class _VideoFeedItem extends StatefulWidget {
  final PostModel post;
  final bool isActive;

  const _VideoFeedItem({Key? key, required this.post, required this.isActive})
      : super(key: key);

  @override
  State<_VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<_VideoFeedItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When active state toggles, play or pause accordingly
    if (widget.isActive && !oldWidget.isActive) {
      _controller?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  Future<void> _setupVideo() async {
    final rawUrl = widget.post.videoUrl?.isNotEmpty == true
        ? widget.post.videoUrl!
        : widget.post.metadata['video_url'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) return;

    _controller = VideoPlayerController.network(
      rawUrl,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      await _controller!.initialize();
      _controller!
        ..setLooping(true)
        ..setVolume(1.0);

      if (widget.isActive) _controller!.play();

      setState(() => _initialized = true);

      // Smooth looping + error logging
      _controller!.addListener(() {
        final ctl = _controller!;
        if (ctl.value.isInitialized &&
            ctl.value.position >=
                ctl.value.duration - const Duration(milliseconds: 100)) {
          ctl.seekTo(Duration.zero);
        }
        if (ctl.value.hasError) {
          debugPrint('Video error: ${ctl.value.errorDescription}');
        }
      });
    } catch (e) {
      debugPrint('Video init failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = widget.post.metadata['video_thumbnail'] as String?;

    return Stack(
      fit: StackFit.expand,
      children: [
        _initialized && _controller != null
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            : _buildShimmer(thumbUrl),

        // Simple overlay with caption/user etc can be extended
        Positioned(
          bottom: 40,
          left: 16,
          right: 16,
          child: Text(
            widget.post.content,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer(String? thumb) {
    return thumb != null && thumb.isNotEmpty
        ? Image.network(
            thumb,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => _placeholder(),
          )
        : _placeholder();
  }

  Widget _placeholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(color: Colors.grey.shade800),
    );
  }
}

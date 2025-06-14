import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// A lightweight widget that generates and displays a thumbnail frame
/// for the provided [videoUrl]. This prevents blank placeholders when
/// showing videos in a grid or list.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;
  final int? timeMs;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.timeMs,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  // Reactive thumbnail data
  final Rxn<Uint8List> _thumb = Rxn<Uint8List>();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (widget.videoUrl.isEmpty) return;
    try {
      // Ensure remote URLs are properly encoded – avoids connection NPE
      final encoded =
          Uri.tryParse(widget.videoUrl)?.isAbsolute == true
              ? Uri.encodeFull(widget.videoUrl)
              : widget.videoUrl;

      final data = await VideoThumbnail.thumbnailData(
        video: encoded,
        imageFormat: ImageFormat.JPEG,
        timeMs: widget.timeMs ?? 0, // nullable allowed
        quality: 75,
      );
      _thumb.value = data;
    } catch (e) {
      // Handle error
      debugPrint('Error generating thumbnail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = _thumb.value;
      if (data != null) {
        return Image.memory(data, fit: widget.fit);
      }
      return Container(color: Colors.black26);
    });
  }

  @override
  void dispose() {
    _thumb.close();
    super.dispose();
  }
}

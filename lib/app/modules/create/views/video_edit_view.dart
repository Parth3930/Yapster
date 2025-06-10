import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoEditView extends StatefulWidget {
  const VideoEditView({super.key});

  @override
  State<VideoEditView> createState() => _VideoEditViewState();
}

class _VideoEditViewState extends State<VideoEditView> {
  late File videoFile;
  final Trimmer _trimmer = Trimmer();
  VideoPlayerController? _controller;
  bool isLoading = false;
  double _startValue = 0.0;
  double _endValue = 0.0;

  @override
  void initState() {
    super.initState();

    // Get arguments
    final Map<String, dynamic> args = Get.arguments;
    videoFile = args['videoFile'] as File;

    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _trimmer.loadVideo(videoFile: videoFile);
      _controller = VideoPlayerController.file(videoFile);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      Get.snackbar('Error', 'Failed to load video');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit Video', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed:
                isLoading
                    ? null
                    : () {
                      // Save the trimmed video
                      _saveTrimmedVideo();
                    },
            child: const Text(
              'Next',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoViewer(trimmer: _trimmer),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "Max 1 minute",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.black,
                    child: TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 50.0,
                      viewerWidth: MediaQuery.of(context).size.width,
                      maxVideoLength: const Duration(minutes: 1),
                      onChangeStart: (value) {
                        _startValue = value;
                      },
                      onChangeEnd: (value) {
                        _endValue = value;
                      },
                      onChangePlaybackState: (value) {},
                    ),
                  ),
                ],
              ),
    );
  }

  Future<void> _saveTrimmedVideo() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Use the values captured from the trim slider
      double startValue = _startValue;
      double endValue = _endValue;

      // If values are still zero, default to entire video up to 1 minute
      if (startValue == 0.0 && endValue == 0.0) {
        startValue = 0.0;
        // Get video duration and cap it at 1 minute
        try {
          final videoDuration =
              _controller?.value.duration.inMilliseconds.toDouble() ?? 60000.0;
          endValue = videoDuration > 60000.0 ? 60000.0 : videoDuration;
        } catch (e) {
          debugPrint('Error getting video duration: $e');
          endValue = 60000.0;
        }
      }

      // Ensure video is not longer than 1 minute (60000 milliseconds)
      if (endValue - startValue > 60000) {
        endValue = startValue + 60000;
        Get.snackbar(
          'Video Trimmed',
          'Video has been trimmed to 1 minute maximum',
          backgroundColor: Colors.black.withOpacity(0.7),
          colorText: Colors.white,
        );
      }

      await _trimmer.saveTrimmedVideo(
        startValue: startValue,
        endValue: endValue,
        onSave: (outputPath) {
          setState(() {
            isLoading = false;
          });

          if (outputPath != null) {
            // Return the trimmed video
            Get.back(result: {'editedVideo': File(outputPath)});
          } else {
            Get.snackbar('Error', 'Failed to save video');
          }
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error saving trimmed video: $e');
      Get.snackbar('Error', 'Failed to save video');
    }
  }
}

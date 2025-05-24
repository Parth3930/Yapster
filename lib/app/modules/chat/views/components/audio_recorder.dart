import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/chat/services/audio_services.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/audio_controller.dart';

class AudioRecorder extends StatefulWidget {
  final Function(String) onStopRecording;
  final VoidCallback onCancelRecording;
  final String chatId;

  const AudioRecorder({
    super.key,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.chatId,
  });

  @override
  State<AudioRecorder> createState() => _AudioRecorderState();
}

class _AudioRecorderState extends State<AudioRecorder>
    with TickerProviderStateMixin {
  final audioService = Get.find<AudioService>();
  final controller = Get.find<ChatController>();
  late final AudioMessageController audioController;
  late AnimationController deleteAnimController;
  late Animation<double> deleteScaleAnimation;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Get the audio controller for this chat
    audioController = Get.find<AudioMessageController>(
      tag: 'recording_${widget.chatId}',
    );

    // Initialize delete button animation
    deleteAnimController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    deleteScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: deleteAnimController, curve: Curves.easeInOut),
    );

    isInitialized = audioController.isRecording.value;
  }

  Future<void> stopRecording() async {
    if (!audioController.isRecording.value) {
      Get.snackbar('Error', 'No active recording');
      return;
    }

    try {
      final path = await audioController.stopRecording();
      if (path != null && path.isNotEmpty) {
        widget.onStopRecording(path);
      } else {
        throw Exception('Failed to save recording');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      Get.snackbar('Error', 'Failed to save recording');
      widget.onCancelRecording();
    }
  }

  void cancelRecording() async {
    // Animate delete button
    deleteAnimController.forward().then((_) {
      deleteAnimController.reverse();
    });

    try {
      await audioController.cancelRecording();
      widget.onCancelRecording();
    } catch (e) {
      debugPrint('Error canceling recording: $e');
      Get.snackbar('Error', 'Failed to cancel recording');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          // Delete button with animation
          AnimatedBuilder(
            animation: deleteScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: deleteScaleAnimation.value,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                    onPressed: cancelRecording,
                    splashColor: Colors.red.withOpacity(0.1),
                    highlightColor: Colors.red.withOpacity(0.05),
                  ),
                ),
              );
            },
          ),

          // Audio wave visualizer
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Obx(() {
                final isRecording = audioController.isRecording.value;
                final hasController =
                    audioController.recorderController != null;
                final duration = audioController.recordingDuration.value;

                if (!isRecording || !hasController) {
                  return Center(
                    child: Text(
                      'Recording... ${_formatDuration(duration)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: AudioWaveforms(
                        enableGesture: true,
                        size: Size(MediaQuery.of(context).size.width * 0.5, 50),
                        recorderController: audioController.recorderController!,
                        waveStyle: WaveStyle(
                          waveColor: Colors.blue.shade400,
                          extendWaveform: true,
                          showMiddleLine: false,
                          spacing: 4.0,
                          showTop: true,
                          showBottom: true,
                          waveCap: StrokeCap.round,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          // Send button
          Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.blue, size: 24),
              onPressed: stopRecording,
              splashColor: Colors.blue.withOpacity(0.1),
              highlightColor: Colors.blue.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    deleteAnimController.dispose();
    // Only stop if we're still recording when disposed
    if (audioController.isRecording.value) {
      audioController.cancelRecording();
    }
    super.dispose();
  }
}

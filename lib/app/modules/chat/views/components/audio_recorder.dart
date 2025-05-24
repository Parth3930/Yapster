import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/chat/services/audio_services.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../controllers/chat_controller.dart';

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

class _AudioRecorderState extends State<AudioRecorder> {
  final audioService = Get.find<AudioService>();
  final controller = Get.find<ChatController>();
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Check if we're already recording
    isInitialized =
        audioService.isRecording.value &&
        audioService.currentRecordingPath.value.isNotEmpty;
  }

  Future<void> stopRecording() async {
    if (!audioService.isRecording.value) {
      Get.snackbar('Error', 'No active recording');
      return;
    }

    try {
      final path = await audioService.stopRecording();
      if (path != null) {
        // Upload and send the audio message
        await controller.uploadAndSendAudio(widget.chatId, path);
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
    try {
      await audioService.stopRecording();
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
          // Delete button
          Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 24),
              onPressed: cancelRecording,
              splashColor: Colors.red.withOpacity(0.1),
              highlightColor: Colors.red.withOpacity(0.05),
            ),
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
                final isRecording = audioService.isRecording.value;
                final hasController = audioService.recorderController != null;

                if (!isRecording || !hasController) {
                  return const Center(
                    child: Text(
                      'Recording...',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  );
                }

                return AudioWaveforms(
                  enableGesture: true,
                  size: Size(MediaQuery.of(context).size.width * 0.6, 50),
                  recorderController: audioService.recorderController!,
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

  @override
  void dispose() {
    // Only stop if we're still recording when disposed
    if (audioService.isRecording.value) {
      audioService.stopRecording();
    }
    super.dispose();
  }
}

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
    // Initialize the recorder controller if not already initialized
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    if (!isInitialized && !audioService.isRecording.value) {
      await audioService.startRecording();
    }
    setState(() {
      isInitialized = true;
    });
  }

  Future<void> stopRecording() async {
    if (!audioService.isRecording.value) {
      Get.snackbar('Error', 'No active recording');
      return;
    }

    try {
      final recordingData = await audioService.stopRecording(); // This now returns a Map
      if (recordingData != null) {
        final String path = recordingData['path'] as String;
        final Duration duration = recordingData['duration'] as Duration;

        // Upload and send the audio message with duration
        await controller.uploadAndSendAudio(widget.chatId, path, duration: duration);
        widget.onStopRecording(path); // This callback might need adjustment if it expects duration too
      } else {
        // audioService.stopRecording() returning null means it handled user feedback
        // or an error occurred that it already reported.
        // So, we might not need to throw another exception or show another snackbar here.
        // However, to maintain previous behavior of onCancelRecording being called:
        widget.onCancelRecording(); // Or simply return if snackbars are handled in AudioService
        // For now, let's assume if null, it's an error/cancel scenario from AudioService's POV
        // and AudioRecorder should reflect that by calling its onCancelRecording.
        debugPrint('AudioRecorder: audioService.stopRecording returned null. Treating as cancellation/failure.');
        // Get.snackbar('Error', 'Failed to save recording'); // This might be redundant
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      Get.snackbar('Error', 'Failed to save recording');
      widget.onCancelRecording();
    }
  }

  void cancelRecording() async {
    try {
      // Stop recording and discard the result.
      // The AudioService's stopRecording now handles cleanup and state reset.
      await audioService.stopRecording(); 
      widget.onCancelRecording(); // Notify parent about cancellation.
    } catch (e) {
      // This catch block might be redundant if audioService.stopRecording() handles its own errors.
      // However, keeping it for safety in case of unexpected exceptions from the call itself.
      debugPrint('Error canceling recording in AudioRecorder: $e');
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
                if (!audioService.isRecording.value || audioService.recorderController == null) {
                  return const Center(
                    child: Text(
                      'Starting recording...',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // Waveform visualization
                    AudioWaveforms(
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
                    ),
                    // Recording indicator
                    if (audioService.isRecording.value)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
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

  @override
  void dispose() {
    // Don't stop recording here - let the parent handle it
    // This prevents the recording from being stopped when the widget is rebuilt
    super.dispose();
  }
}

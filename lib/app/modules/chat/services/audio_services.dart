import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart' as record_plugin;
import 'package:path_provider/path_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService extends GetxService {
  static AudioService get to => Get.find();

  late final record_plugin.AudioRecorder recorder;

  // Remove just_audio player since we're using audio_waveforms
  final RxBool isRecording = false.obs;
  final RxBool isPlaying = false.obs;
  final RxString currentPlayingId = ''.obs;
  final RxString currentRecordingPath = ''.obs;
  final RxMap<String, File> audioFiles = <String, File>{}.obs;

  // For waveform visualization during recording
  RecorderController? recorderController;
  Timer? _waveformTimer;
  DateTime? _recordingStartTime; // To calculate duration

  Future<AudioService> init() async {
    recorder = record_plugin.AudioRecorder();
    recorderController = await _setupRecorderController();
    return this;
  }

  Future<RecorderController> _setupRecorderController() async {
    final controller =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100
          ..bitRate = 128000;
    return controller;
  }

  Future<void> _disposeCurrentController() async {
    _waveformTimer?.cancel();
    _waveformTimer = null;
    await recorderController?.stop();
    recorderController?.dispose();
    recorderController = null;
  }

  Future<String?> startRecording() async {
    // First check if we already have permission and recording state
    if (isRecording.value) {
      debugPrint('Already recording');
      return currentRecordingPath.value;
    }

    var status = await Permission.microphone.status;

    // Only request if not already granted
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    // If permission is denied or restricted, show error and return
    if (!status.isGranted) {
      Get.snackbar(
        'Permission Required',
        'Microphone permission is required to record audio. Please enable it in your device settings.',
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    // Permission is granted, proceed with recording
    try {
      final appDir = await getTemporaryDirectory();
      final filePath =
          '${appDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Set up new recorder controller
      await _disposeCurrentController();
      recorderController = await _setupRecorderController();
      await recorderController?.record();

      // Start recording with main recorder
      await recorder.start(
        const record_plugin.RecordConfig(
          encoder: record_plugin.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      isRecording.value = true;
      currentRecordingPath.value = filePath;

      // Start updating waveform
      _waveformTimer?.cancel();
      _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        recorderController?.refresh();
      });

      _recordingStartTime = DateTime.now(); // Start timer
      return filePath;
    } catch (e) {
      _recordingStartTime = null; // Reset on error
      debugPrint('Error starting recording: $e');
      Get.snackbar('Error', 'Failed to start recording');
      await _disposeCurrentController();
      return null;
    }
  }

  Future<Map<String, dynamic>?> stopRecording() async {
    // Check if recording and if startTime is available
    if (!isRecording.value || _recordingStartTime == null) {
      debugPrint('AudioService: stopRecording called but not recording or startTime is null.');
      // Ensure state is reset if it's inconsistent
      if (isRecording.value) {
        isRecording.value = false;
        currentRecordingPath.value = '';
      }
      return null;
    }

    final Duration duration = DateTime.now().difference(_recordingStartTime!);

    try {
      // Stop the waveform refresh timer explicitly. _disposeCurrentController also cancels it,
      // but doing it here ensures it's stopped before recorder.stop().
      _waveformTimer?.cancel();

      // Stop the visual waveform recorder.
      // This should ideally not throw if called multiple times or on an uninitialized controller,
      // but defensive coding with null check is good.
      if (recorderController != null && recorderController!.isRecording) {
         await recorderController?.stop();
      }

      // Stop the main audio recorder. This is what writes the file.
      final String? path = await recorder.stop();
      
      // Path from recorder.stop() is the source of truth.
      // currentRecordingPath.value was set at start, can be used for reference or cleared.

      if (path == null || path.isEmpty) {
        throw Exception('Recorder returned null or empty path.');
      }
      if (!File(path).existsSync()) {
        throw Exception('Recorded file not found at path: $path');
      }
      
      // Successfully stopped and file exists.
      // isRecording and currentRecordingPath will be reset in finally.
      return {'path': path, 'duration': duration};
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      Get.snackbar('Error', 'Failed to stop recording: ${e.toString()}');
      return null;
    } finally {
      // Reset state and dispose resources
      _recordingStartTime = null;
      isRecording.value = false; // Ensure recording state is reset
      currentRecordingPath.value = ''; // Clear the stored path
      await _disposeCurrentController(); // Clean up waveform controller and its timer
    }
  }

  // Simplified playAudio - just manages state, actual playback handled by AudioMessage widgets
  Future<void> playAudio(String url, String messageId) async {
    debugPrint('AudioService: Playing audio for message $messageId');

    // Stop any currently playing audio
    if (isPlaying.value && currentPlayingId.value != messageId) {
      await stopAudio();
    }

    // Update state
    isPlaying.value = true;
    currentPlayingId.value = messageId;

    debugPrint(
      'AudioService: State updated - playing: ${isPlaying.value}, currentId: ${currentPlayingId.value}',
    );
  }

  Future<void> stopAudio() async {
    debugPrint(
      'AudioService: Stopping audio for message ${currentPlayingId.value}',
    );

    isPlaying.value = false;
    currentPlayingId.value = '';

    debugPrint(
      'AudioService: State updated - playing: ${isPlaying.value}, currentId: ${currentPlayingId.value}',
    );
  }

  Future<void> pauseAudio() async {
    debugPrint(
      'AudioService: Pausing audio for message ${currentPlayingId.value}',
    );

    isPlaying.value = false;
    // Don't clear currentPlayingId for pause, keep it for resume

    debugPrint(
      'AudioService: State updated - playing: ${isPlaying.value}, currentId: ${currentPlayingId.value}',
    );
  }

  bool isPlayingMessage(String messageId) {
    final result = isPlaying.value && currentPlayingId.value == messageId;
    debugPrint(
      'AudioService: isPlayingMessage($messageId) = $result (playing: ${isPlaying.value}, currentId: ${currentPlayingId.value})',
    );
    return result;
  }

  @override
  void onClose() {
    _waveformTimer?.cancel(); // Cancel timer
    recorderController?.dispose(); // Dispose controller
    recorder.dispose(); // Dispose main recorder
    _recordingStartTime = null; // Clear start time
    super.onClose();
  }
}

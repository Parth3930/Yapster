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

  record_plugin.AudioRecorder? _recorder;
  record_plugin.AudioRecorder get recorder {
    if (_recorder == null) {
      _recorder = record_plugin.AudioRecorder();
    }
    return _recorder!;
  }

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
    // Initialize recorder lazily when first used
    _recorder = record_plugin.AudioRecorder();
    recorderController = await _setupRecorderController();
    return this;
  }

  Future<RecorderController> _setupRecorderController() async {
    // Dispose of any existing controller first
    await _disposeCurrentController();
    
    final controller = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100
      ..bitRate = 128000
      ..onRecorderStateChanged.listen((state) {
        debugPrint('Recorder state changed: $state');
        if (state == RecorderState.stopped) {
          isRecording.value = false;
        }
      });
      
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
    // Check if already recording
    if (isRecording.value) {
      debugPrint('Already recording');
      return currentRecordingPath.value;
    }
    
    // Ensure recorder controller is initialized
    recorderController ??= await _setupRecorderController();
    
    // If still null after setup, return
    if (recorderController == null) {
      debugPrint('Failed to initialize recorder controller');
      return null;
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
      if (_recorder == null) {
        _recorder = record_plugin.AudioRecorder();
      }
      
      await _recorder!.start(
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
    if (!isRecording.value) {
      debugPrint('Not currently recording');
      return null;
    }

    try {
      debugPrint('Stopping recording...');
      
      // Stop the waveform timer
      _waveformTimer?.cancel();
      _waveformTimer = null;
      
      final path = currentRecordingPath.value;
      final duration = DateTime.now().difference(_recordingStartTime!);
      
      // Stop both recorders
      await recorderController?.stop();
      try {
        // Check if the recorder is not null and is currently recording
        if (_recorder != null && await _recorder!.isRecording()) {
          await _recorder!.stop();
        }
      } catch (e) {
        debugPrint('Error checking recorder state: $e');
      }
      
      // Update state
      isRecording.value = false;
      _recordingStartTime = null;
      
      debugPrint('Recording stopped. Path: $path, Duration: ${duration.inSeconds} seconds');
      
      if (path.isNotEmpty) {
        return {
          'path': path,
          'duration': duration,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      isRecording.value = false;
      _recordingStartTime = null;
      return null;
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
    _waveformTimer?.cancel();
    _waveformTimer = null;
    _disposeCurrentController();
    try {
      _recorder?.dispose();
    } catch (e) {
      debugPrint('Error disposing recorder: $e');
    }
    _recorder = null;
    super.onClose();
  }
}

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:yapster/app/modules/chat/services/audio_services.dart';

class AudioMessageController extends GetxController
    with GetTickerProviderStateMixin {
  final String? url;
  final String? messageId;
  final Duration? duration;

  AudioMessageController({this.url, this.messageId, this.duration});

  final audioService = Get.find<AudioService>();
  PlayerController? playerController;
  RecorderController? recorderController;

  // Observable states for playback
  final isInitialized = false.obs;
  final isLoading = false.obs;
  final hasError = false.obs;
  final isPlaying = false.obs; // Single source of truth for playing state
  final currentPosition = Duration.zero.obs;
  final totalDuration = Duration.zero.obs;

  // Observable states for recording
  final isRecording = false.obs;
  final recordingDuration = Duration.zero.obs;
  final currentRecordingPath = ''.obs;
  final isRecordingInitialized = false.obs;

  StreamSubscription<int>? positionSubscription;
  StreamSubscription<PlayerState>? playerStateSubscription;
  StreamSubscription<RecorderState>? recorderStateSubscription;
  Timer? recordingTimer;
  Worker? audioServiceWorker;
  bool _isToggling = false; // Prevent double toggles

  late AnimationController playPauseAnimController;
  late AnimationController waveAnimController;
  late AnimationController recordingAnimController;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();

    // Only initialize player if we have playback data
    if (url != null && messageId != null) {
      _initializePlayer();

      // Listen to audio service state changes
      audioServiceWorker = ever(audioService.currentPlayingId, (playingId) {
        final shouldBePlaying = playingId == messageId;
        if (isPlaying.value != shouldBePlaying) {
          isPlaying.value = shouldBePlaying;
          _updateAnimations();
        }
      });
    }

    // Initialize recorder for recording functionality
    _initializeRecorder();
  }

  void _initializeAnimations() {
    playPauseAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    waveAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    recordingAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  void _updateAnimations() {
    if (isPlaying.value) {
      playPauseAnimController.forward();
      waveAnimController.repeat(reverse: true);
    } else {
      playPauseAnimController.reverse();
      waveAnimController.stop();
    }
  }

  void _updateRecordingAnimations() {
    if (isRecording.value) {
      recordingAnimController.repeat(reverse: true);
    } else {
      recordingAnimController.stop();
      recordingAnimController.reset();
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      recorderController = RecorderController();
      isRecordingInitialized.value = true;
    } catch (e) {
      debugPrint('Error initializing recorder: $e');
      isRecordingInitialized.value = false;
    }
  }

  Future<void> _initializePlayer() async {
    if (url == null || messageId == null) return;

    isLoading.value = true;

    // Cancel any existing subscriptions
    positionSubscription?.cancel();
    playerStateSubscription?.cancel();

    // Create new controller
    playerController = PlayerController();

    try {
      final cachedFile = await _getCachedFile();
      if (cachedFile != null) {
        await playerController?.preparePlayer(
          path: cachedFile.path,
          noOfSamples: 100,
        );

        // Get total duration
        final durationMs = await playerController?.getDuration();
        if (durationMs != null) {
          totalDuration.value = Duration(milliseconds: durationMs);
        } else if (duration != null) {
          totalDuration.value = duration!;
        }

        // Listen to position changes
        positionSubscription = playerController?.onCurrentDurationChanged
            .listen((durationMs) {
              currentPosition.value = Duration(milliseconds: durationMs);
            });

        // Listen to player state changes
        playerStateSubscription = playerController?.onPlayerStateChanged.listen(
          (state) {
            _handlePlayerStateChange(state);
          },
        );

        isInitialized.value = true;
        isLoading.value = false;
        hasError.value = false;
      } else {
        throw Exception('Failed to cache audio file');
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      hasError.value = true;
      isLoading.value = false;
    }
  }

  void _handlePlayerStateChange(PlayerState state) {
    if (messageId == null) return;

    debugPrint('Player state changed: $state for message: $messageId');

    switch (state) {
      case PlayerState.playing:
        // Don't change isPlaying here, let audio service manage it
        break;

      case PlayerState.paused:
        // Only update if we're supposed to be playing according to audio service
        if (audioService.currentPlayingId.value != messageId) {
          isPlaying.value = false;
          _updateAnimations();
        }
        break;
      case PlayerState.stopped:
        // Audio finished playing
        isPlaying.value = false;
        currentPosition.value = Duration.zero;
        _updateAnimations();

        // Stop audio service if this was the playing message
        if (audioService.currentPlayingId.value == messageId) {
          audioService.stopAudio();
        }

        // Reset everything for next play
        playerController?.dispose();
        playerController = null;
        isInitialized.value = false;
        _initializePlayer();
        break;

      default:
        break;
    }
  }

  Future<void> _reinitializePlayer() async {
    if (url == null || messageId == null) return;

    try {
      // Dispose current controller
      playerController?.dispose();

      // Create new controller
      playerController = PlayerController();

      // Re-prepare with cached file
      final cachedFile = await _getCachedFile();
      if (cachedFile != null) {
        await playerController?.preparePlayer(
          path: cachedFile.path,
          noOfSamples: 100,
        );

        // Re-setup listeners
        positionSubscription?.cancel();
        playerStateSubscription?.cancel();

        positionSubscription = playerController?.onCurrentDurationChanged
            .listen((durationMs) {
              currentPosition.value = Duration(milliseconds: durationMs);
            });

        playerStateSubscription = playerController?.onPlayerStateChanged.listen(
          (state) {
            _handlePlayerStateChange(state);
          },
        );

        debugPrint('Player controller reinitialized successfully');
      }
    } catch (e) {
      debugPrint('Error reinitializing player: $e');
      hasError.value = true;
    }
  }

  Future<File?> _getCachedFile() async {
    if (url == null || messageId == null) return null;

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$messageId.m4a');

      if (await file.exists()) {
        return file;
      }

      final response = await http.get(Uri.parse(url!));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('Error caching audio file: $e');
    }
    return null;
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> togglePlayback() async {
    if (!isInitialized.value ||
        playerController == null ||
        _isToggling ||
        url == null ||
        messageId == null) {
      return;
    }

    _isToggling = true;

    try {
      final currentlyPlaying = audioService.currentPlayingId.value == messageId;

      debugPrint(
        'Toggle playback - Currently playing: $currentlyPlaying, Message: $messageId',
      );

      if (currentlyPlaying) {
        // Stop playing
        debugPrint('Stopping audio...');
        await audioService.stopAudio();
        await playerController?.pausePlayer();
      } else {
        // Start playing
        debugPrint('Starting audio...');

        // Check if player controller is in a good state
        final duration = await playerController?.getDuration();
        if (duration == null || duration <= 0) {
          debugPrint('Player controller not ready, reinitializing...');
          await _reinitializePlayer();

          // Double check after reinit
          if (!isInitialized.value || playerController == null) {
            debugPrint('Failed to reinitialize player controller');
            return;
          }
        }

        // First update audio service
        await audioService.playAudio(url!, messageId!);

        // Wait a bit for audio service to update
        await Future.delayed(const Duration(milliseconds: 50));

        // Then start the waveform player if we're the active audio
        if (audioService.currentPlayingId.value == messageId) {
          try {
            await playerController?.startPlayer();
            debugPrint('Started player controller');
          } catch (e) {
            debugPrint('Error starting player controller: $e');
            // Try to reinitialize and start again
            await _reinitializePlayer();
            if (isInitialized.value && playerController != null) {
              await playerController?.startPlayer();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
      // Try to recover by reinitializing
      await _reinitializePlayer();
    } finally {
      _isToggling = false;
    }
  }

  // Recording methods
  Future<bool> startRecording() async {
    if (!isRecordingInitialized.value || recorderController == null) {
      debugPrint('Recorder not initialized');
      return false;
    }

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/recording_$timestamp.m4a';

      await recorderController!.record(path: filePath);

      currentRecordingPath.value = filePath;
      isRecording.value = true;
      recordingDuration.value = Duration.zero;

      // Listen to recording state changes
      recorderStateSubscription?.cancel();
      recorderStateSubscription = recorderController!.onRecorderStateChanged
          .listen((state) {
            debugPrint('Recorder state changed: $state');
            if (state == RecorderState.stopped) {
              isRecording.value = false;
              _updateRecordingAnimations();
            }
          });

      // Start a timer to track recording duration manually
      _startRecordingTimer();

      _updateRecordingAnimations();
      debugPrint('Started recording to: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      isRecording.value = false;
      return false;
    }
  }

  void _startRecordingTimer() {
    recordingTimer?.cancel();
    final startTime = DateTime.now();

    recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isRecording.value) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(startTime);
      recordingDuration.value = elapsed;
    });
  }

  Future<String?> stopRecording() async {
    if (!isRecording.value || recorderController == null) {
      return null;
    }

    try {
      final path = await recorderController!.stop();
      isRecording.value = false;
      _updateRecordingAnimations();

      recordingTimer?.cancel();
      recorderStateSubscription?.cancel();

      debugPrint('Stopped recording, saved to: $path');
      return path ?? currentRecordingPath.value;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      isRecording.value = false;
      _updateRecordingAnimations();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!isRecording.value || recorderController == null) {
      return;
    }

    try {
      await recorderController!.stop();

      // Delete the recording file
      if (currentRecordingPath.value.isNotEmpty) {
        final file = File(currentRecordingPath.value);
        if (await file.exists()) {
          await file.delete();
        }
      }

      isRecording.value = false;
      currentRecordingPath.value = '';
      recordingDuration.value = Duration.zero;
      _updateRecordingAnimations();

      recordingTimer?.cancel();
      recorderStateSubscription?.cancel();

      debugPrint('Cancelled recording');
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
      isRecording.value = false;
      _updateRecordingAnimations();
    }
  }

  @override
  void onClose() {
    audioServiceWorker?.dispose();
    positionSubscription?.cancel();
    playerStateSubscription?.cancel();
    recorderStateSubscription?.cancel();
    recordingTimer?.cancel();
    playPauseAnimController.dispose();
    waveAnimController.dispose();
    recordingAnimController.dispose();
    playerController?.dispose();
    recorderController?.dispose();
    super.onClose();
  }
}

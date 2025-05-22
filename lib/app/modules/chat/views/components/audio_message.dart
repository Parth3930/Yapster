import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/modules/chat/controllers/audio_controller.dart';
import 'dart:math' as matm;

class AudioMessage extends StatelessWidget {
  final String url;
  final String messageId;
  final bool isMe;
  final Duration? duration;

  const AudioMessage({
    super.key,
    required this.url,
    required this.messageId,
    required this.isMe,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    // Create or get controller with unique tag
    final controller = Get.put(
      AudioMessageController(
        url: url,
        messageId: messageId,
        duration: duration,
      ),
      tag: messageId,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.togglePlayback,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
              minWidth: 200,
            ),
            decoration: BoxDecoration(
              gradient:
                  isMe
                      ? LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : LinearGradient(
                        colors: [Colors.grey.shade700, Colors.grey.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildContent(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AudioMessageController controller) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPlayButton(controller),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWaveform(controller),
              const SizedBox(height: 8),
              _buildTimeDisplay(controller),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildMicIcon(),
      ],
    );
  }

  Widget _buildPlayButton(AudioMessageController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        );
      }

      if (controller.hasError.value) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: Colors.white, size: 20),
        );
      }

      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              controller.isPlaying.value
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              key: ValueKey(controller.isPlaying.value),
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildWaveform(AudioMessageController controller) {
    return Obx(() {
      if (!controller.isInitialized.value ||
          controller.playerController == null) {
        return _buildLoadingWaveform(controller);
      }

      return SizedBox(
        height: 32,
        child: AudioFileWaveforms(
          size: Size(Get.width * 0.45, 32),
          playerController: controller.playerController!,
          enableSeekGesture: true,
          waveformType: WaveformType.fitWidth,
          playerWaveStyle: PlayerWaveStyle(
            fixedWaveColor: Colors.white.withOpacity(0.4),
            liveWaveColor: Colors.white,
            spacing: 4,
            waveThickness: 2,
            waveCap: StrokeCap.round,
            showSeekLine: true,
            seekLineColor: Colors.white,
            seekLineThickness: 2,
          ),
        ),
      );
    });
  }

  Widget _buildLoadingWaveform(AudioMessageController controller) {
    return AnimatedBuilder(
      animation: controller.waveAnimController,
      builder: (context, child) {
        return Obx(() {
          final isPlaying = controller.isPlaying.value;
          return SizedBox(
            height: 32,
            child: Row(
              children: List.generate(20, (index) {
                final animValue = controller.waveAnimController.value;
                final waveHeight =
                    2.0 +
                    (20.0 *
                        ((1.0 + matm.sin((index * 0.5) + (animValue * 6.28))) /
                            2.0));

                return Container(
                  width: 3,
                  height: isPlaying ? waveHeight : 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
          );
        });
      },
    );
  }

  Widget _buildTimeDisplay(AudioMessageController controller) {
    return Obx(() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            controller.formatDuration(controller.currentPosition.value),
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            controller.formatDuration(controller.totalDuration.value),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMicIcon() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 14),
    );
  }
}

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
    final controller = Get.put(
      AudioMessageController(
        url: url,
        messageId: messageId,
        duration: duration,
      ),
      tag: messageId,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.togglePlayback,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
              minWidth: 120,
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
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
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
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWaveform(controller),
              const SizedBox(height: 4),
              _buildTimeDisplay(controller),
            ],
          ),
        ),
        const SizedBox(width: 4),
        _buildMicIcon(),
      ],
    );
  }

  Widget _buildPlayButton(AudioMessageController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: Colors.white, size: 18),
        );
      }
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.transparent,
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
              size: 20,
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
        height: 20,
        child: AudioFileWaveforms(
          size: Size(Get.width * 0.32, 20),
          playerController: controller.playerController!,
          enableSeekGesture: true,
          waveformType: WaveformType.fitWidth,
          playerWaveStyle: PlayerWaveStyle(
            fixedWaveColor: Colors.white.withOpacity(0.4),
            liveWaveColor: Colors.white,
            spacing: 2,
            waveThickness: 1.5,
            waveCap: StrokeCap.round,
            showSeekLine: true,
            seekLineColor: Colors.white,
            seekLineThickness: 1.5,
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
            height: 20,
            child: Row(
              children: List.generate(16, (index) {
                final animValue = controller.waveAnimController.value;
                // Slow down the animation and reduce frequency
                final waveHeight =
                    2.0 +
                    (12.0 *
                        ((1.0 + matm.sin((index * 0.25) + (animValue * 3.14))) /
                            2.0));
                return Container(
                  width: 2.2,
                  height: isPlaying ? waveHeight : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(1),
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
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            controller.formatDuration(controller.totalDuration.value),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMicIcon() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 11),
    );
  }
}

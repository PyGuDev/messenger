import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/network/voice_recorder_service.dart';
import '../../../../core/di/injection_container.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final void Function(String filePath, Duration duration) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> with SingleTickerProviderStateMixin {
  final VoiceRecorderService _recorderService = sl<VoiceRecorderService>();
  late AnimationController _pulseController;
  Timer? _timer;
  Duration _duration = Duration.zero;
  final List<double> _amplitudes = [];
  StreamSubscription? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      await _recorderService.start();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _duration = Duration(seconds: timer.tick);
        });
      });

      _amplitudeSubscription = _recorderService.amplitudeStream.listen((amp) {
        setState(() {
          _amplitudes.add(amp);
          if (_amplitudes.length > 30) {
            _amplitudes.removeAt(0);
          }
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        widget.onCancel();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          top: BorderSide(color: AppColors.borderDefault, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Trash Icon (Cancel)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () async {
                await _recorderService.cancel();
                widget.onCancel();
              },
            ),
            const SizedBox(width: 8),
            // Recording Field
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    // Red Dot (Pulse)
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timer
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Waveform
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _amplitudes.map((amp) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 3,
                            height: 4 + (amp * 20),
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            GestureDetector(
              onTap: () async {
                final path = await _recorderService.stop();
                if (path != null) {
                  widget.onSend(path, _duration);
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.accentBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  color: AppColors.textOnAccent,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

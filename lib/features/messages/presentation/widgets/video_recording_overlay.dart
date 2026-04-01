import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/camera_service.dart';
import '../../../../core/di/injection_container.dart';

class VideoRecordingOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSwitchCamera;
  final VoidCallback onSend;

  const VideoRecordingOverlay({
    super.key,
    required this.onCancel,
    required this.onSwitchCamera,
    required this.onSend,
  });

  @override
  State<VideoRecordingOverlay> createState() => _VideoRecordingOverlayState();
}

class _VideoRecordingOverlayState extends State<VideoRecordingOverlay> {
  final CameraService _cameraService = sl<CameraService>();
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: timer.tick);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    final controller = _cameraService.controller;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Outer ring and viewfinder
              Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF573AFE), width: 4),
                ),
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: (_cameraService.isSwitching ||
                          controller == null ||
                          !controller.value.isInitialized)
                      ? Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: 100,
                              height: 100 * controller.value.aspectRatio,
                              child: CameraPreview(controller),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // Timer Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Controls Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Cancel
                    GestureDetector(
                      onTap: _cameraService.isSwitching ? null : widget.onCancel,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _cameraService.isSwitching
                              ? const Color(0x33FF3B30)
                              : const Color(0x80FF3B30),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.close,
                          color: _cameraService.isSwitching
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Stop / Send
                    GestureDetector(
                      onTap: _cameraService.isSwitching ? null : widget.onSend,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _cameraService.isSwitching
                              ? const Color(0x33573AFE)
                              : const Color(0xFF573AFE),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _cameraService.isSwitching
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Switch Camera
                    GestureDetector(
                      onTap: _cameraService.isSwitching ? null : widget.onSwitchCamera,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _cameraService.isSwitching
                              ? const Color(0x33000000)
                              : const Color(0x66000000),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.flip_camera_ios,
                          color: _cameraService.isSwitching
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

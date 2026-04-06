import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/cache/media_cache_service.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String accessKey;
  final String? localPath;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.accessKey,
    this.localPath,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  final MediaCacheService _mediaCache = sl<MediaCacheService>();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.accessKey.isEmpty) {
        foundation.debugPrint(
          'VoiceMessageBubble: Warning: accessKey is empty!',
        );
        return;
      }

      // 1. Check localPath first (for fast optimistic UI playback)
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        final localFile = File(widget.localPath!);
        if (await localFile.exists()) {
          foundation.debugPrint(
            'VoiceMessageBubble: Playing from localPath: ${localFile.path}',
          );
          await _player.setAudioSource(
            AudioSource.uri(Uri.file(localFile.path)),
          );
          _setupPlayerListeners();
          return;
        }
      }

      // 2. Try MediaCacheService
      foundation.debugPrint(
        'VoiceMessageBubble: Loading audio from MediaCacheService',
      );
      final fileInfo = await _mediaCache.downloadFile(widget.accessKey);

      String finalPath = fileInfo.file.path;
      if (!finalPath.toLowerCase().endsWith('.m4a') && 
          !finalPath.toLowerCase().endsWith('.mp4') && 
          !finalPath.toLowerCase().endsWith('.mp3')) {
        final newFile = File('$finalPath.m4a');
        if (!await newFile.exists()) {
          await fileInfo.file.copy(newFile.path);
        }
        finalPath = newFile.path;
      }

      await _player.setAudioSource(
        AudioSource.uri(Uri.file(finalPath)),
      );
      _setupPlayerListeners();
    } catch (e) {
      foundation.debugPrint('VoiceMessageBubble: Error loading audio: $e');
    }
  }

  void _setupPlayerListeners() {
    _durationSubscription = _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });

    _positionSubscription = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
        if (state.processingState == ProcessingState.completed) {
          _player.stop();
          _player.seek(Duration.zero);
        }
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
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
    final color = widget.isMe ? AppColors.textOnAccent : AppColors.textPrimary;
    final secondaryColor = widget.isMe
        ? AppColors.textOnAccent.withValues(alpha: 0.7)
        : AppColors.textTertiary;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Play/Pause Button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: color,
            ),
            onPressed: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
          ),
          // Progress Slider + Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: color,
                    inactiveTrackColor: color.withValues(alpha: 0.3),
                    thumbColor: color,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                      0,
                      _duration.inMilliseconds.toDouble(),
                    ),
                    max: _duration.inMilliseconds.toDouble(),
                    onChanged: (val) {
                      _player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _formatDuration(_duration - _position),
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

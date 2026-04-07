import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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

  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _checkLocalState();
  }

  Future<void> _checkLocalState() async {
    try {
      if (widget.accessKey.isEmpty) {
        foundation.debugPrint('VoiceMessageBubble: Warning: accessKey is empty!');
        return;
      }

      // 1. Check localPath first (for fast optimistic UI playback)
      if (widget.localPath != null && widget.localPath!.isNotEmpty) {
        final localFile = File(widget.localPath!);
        if (await localFile.exists()) {
          foundation.debugPrint('VoiceMessageBubble: Playing from localPath: ${localFile.path}');
          _isDownloaded = true;
          await _initPlayback(localFile);
          return;
        }
      }

      // 2. Try MediaCacheService
      foundation.debugPrint('VoiceMessageBubble: Checking cache from MediaCacheService');
      final fileInfo = await _mediaCache.getFileFromCache(widget.accessKey);
      if (fileInfo != null) {
        _isDownloaded = true;
        await _initPlayback(fileInfo.file);
        return;
      }

      // Not downloaded yet. Wait for manual trigger.
      if (mounted) {
        setState(() {
          _isDownloaded = false;
          _isDownloading = false;
        });
      }
    } catch (e) {
      foundation.debugPrint('VoiceMessageBubble: Error checking local state: $e');
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      _downloadSubscription = _mediaCache
          .getFileStream(widget.accessKey)
          .listen(
            (response) {
              if (response is DownloadProgress) {
                if (mounted) {
                  setState(() {
                    _downloadProgress = response.progress ?? 0.0;
                  });
                }
              } else if (response is FileInfo) {
                if (mounted) {
                  setState(() {
                    _isDownloading = false;
                    _isDownloaded = true;
                  });
                  _initPlayback(response.file);
                }
              }
            },
            onError: (e) {
              foundation.debugPrint('VoiceMessageBubble download error: $e');
              if (mounted) {
                setState(() {
                  _isDownloading = false;
                });
              }
            },
          );
    } catch (e) {
      foundation.debugPrint('VoiceMessageBubble download error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _initPlayback(File file) async {
    try {
      String finalPath = file.path;
      if (!finalPath.toLowerCase().endsWith('.m4a') && 
          !finalPath.toLowerCase().endsWith('.mp4') && 
          !finalPath.toLowerCase().endsWith('.mp3')) {
        final newFile = File('$finalPath.m4a');
        if (!await newFile.exists()) {
          await file.copy(newFile.path);
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
    _downloadSubscription?.cancel();
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
          // Play/Pause/Download Button
          if (!_isDownloaded)
            IconButton(
              icon: _isDownloading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(Icons.download, color: color),
              onPressed: _isDownloading ? null : _startDownload,
            )
          else
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
                      _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1,
                    ),
                    max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1,
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

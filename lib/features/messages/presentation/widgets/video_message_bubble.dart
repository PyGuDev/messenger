import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/cache/media_cache_service.dart';
import 'video_fullscreen_viewer.dart';

class VideoMessageBubble extends StatefulWidget {
  final String accessKey;
  final String? localPath;
  final bool isMe;

  const VideoMessageBubble({
    super.key,
    required this.accessKey,
    this.localPath,
    required this.isMe,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  File? _localFile;
  final MediaCacheService _mediaCache = sl<MediaCacheService>();

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
    // 1. Check optimistic localPath first
    if (widget.localPath != null && widget.localPath!.isNotEmpty) {
      final local = File(widget.localPath!);
      if (await local.exists()) {
        _localFile = local;
        _isDownloaded = true;
        await _initController(local);
        return;
      }
    }

    // 2. Check cache
    final fileInfo = await _mediaCache.getFileFromCache(widget.accessKey);
    if (fileInfo != null) {
      _localFile = fileInfo.file;
      _isDownloaded = true;
      await _initController(fileInfo.file);
      return;
    }

    // Not downloaded yet. Wait for manual trigger.
    if (mounted) {
      setState(() {
        _isDownloaded = false;
        _isDownloading = false;
      });
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
                    _localFile = response.file;
                  });
                  _initController(response.file);
                }
              }
            },
            onError: (e) {
              debugPrint('VideoMessageBubble download error: $e');
              if (mounted) {
                setState(() {
                  _isDownloading = false;
                });
              }
            },
          );
    } catch (e) {
      debugPrint('VideoMessageBubble download error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _initController(File file) async {
    try {
      String finalPath = file.path;
      if (!finalPath.toLowerCase().endsWith('.mp4') &&
          !finalPath.toLowerCase().endsWith('.mov')) {
        final newFile = File('$finalPath.mp4');
        if (!await newFile.exists()) {
          await file.copy(newFile.path);
        }
        finalPath = newFile.path;
        _localFile = newFile;
      }

      final f = File(finalPath);
      final size = await f.length();
      debugPrint(
        'VideoMessageBubble: initializing video from $finalPath, size: $size bytes',
      );

      _controller = VideoPlayerController.file(f);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Autoplay muted

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('VideoMessageBubble init error: $e');
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isMe ? AppColors.accentBlue : AppColors.borderDefault,
          width: 2,
        ),
      ),
      child: ClipOval(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_isDownloaded && _isInitialized && _controller != null) {
      return GestureDetector(
        onTap: () {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
            _controller!.setVolume(1.0);
          }
          setState(() {});
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            if (!_controller!.value.isPlaying)
              GestureDetector(
                onTap: () {
                  if (_localFile != null) {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            VideoFullscreenViewer(videoFile: _localFile!),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // Not downloaded or downloading
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: _isDownloading
              ? CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: _startDownload,
                ),
        ),
      );
    }
  }
}

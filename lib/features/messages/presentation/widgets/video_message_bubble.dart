import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/network/file_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/security/token_storage.dart';
import 'video_fullscreen_viewer.dart';

class VideoMessageBubble extends StatefulWidget {
  final String accessKey;
  final bool isMe;

  const VideoMessageBubble({
    super.key,
    required this.accessKey,
    required this.isMe,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  File? _localFile;
  final FileService _fileService = sl<FileService>();
  final TokenStorage _tokenStorage = sl<TokenStorage>();

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final url = _fileService.getDownloadUrl(widget.accessKey);
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/video_${widget.accessKey}.mp4');
      _localFile = localFile;

      if (!await localFile.exists()) {
        final token = await _tokenStorage.getAccessToken();
        final dio = Dio();
        await dio.download(
          url,
          localFile.path,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }

      _controller = VideoPlayerController.file(localFile);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Autoplay muted like Telegram
      // Removed _controller!.play() here so it doesn't autoplay

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('VideoMessageBubble error: $e');
    }
  }

  @override
  void dispose() {
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
      child: ClipOval(
        child: _isInitialized && _controller != null
            ? GestureDetector(
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
                            // Navigate to fullscreen viewer
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: false,
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        VideoFullscreenViewer(
                                          videoFile: _localFile!,
                                        ),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
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
                            color: Colors.black54,
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
              )
            : Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
      ),
    );
  }
}

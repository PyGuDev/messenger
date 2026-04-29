import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'video_merger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  final List<String> _videoChunks = [];
  bool _isSwitching = false;

  bool get isSwitching => _isSwitching;

  Future<void> initialize() async {
    final allCameras = await availableCameras();
    if (allCameras.isNotEmpty) {
      CameraDescription? frontCamera;
      CameraDescription? backCamera;

      for (var camera in allCameras) {
        if (frontCamera == null &&
            camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
        }
        if (backCamera == null &&
            camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
        }
      }

      _cameras = [];
      if (frontCamera != null) _cameras!.add(frontCamera);
      if (backCamera != null) _cameras!.add(backCamera);

      if (_cameras!.isEmpty) {
        _cameras = allCameras;
      }

      _selectedCameraIndex = 0;
      await _initController(_cameras![_selectedCameraIndex]);
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  Future<void> switchCamera() async {
    if (_cameras == null ||
        _cameras!.length < 2 ||
        _controller == null ||
        _isSwitching) {
      return;
    }

    _isSwitching = true;
    final wasRecording = isRecording;

    try {
      if (wasRecording) {
        final chunk = await _controller!.stopVideoRecording();
        _videoChunks.add(chunk.path);
        // Wait for OS to finish file I/O
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      final newCamera = _cameras![_selectedCameraIndex];

      // Fully dispose BEFORE initializing new one to avoid hardware conflict
      await _controller?.dispose();
      _controller = null;
      // Hardware cooldown
      await Future.delayed(const Duration(milliseconds: 200));

      await _initController(newCamera);

      if (wasRecording) {
        // Another short wait before resuming recording
        await Future.delayed(const Duration(milliseconds: 100));
        await _controller!.startVideoRecording();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Camera switch error: $e');
      }
    } finally {
      _isSwitching = false;
    }
  }

  Future<void> startRecording() async {
    if (_isSwitching) return;
    _videoChunks.clear();
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.startVideoRecording();
    }
  }

  Future<XFile?> stopRecording() async {
    if (_isSwitching) return null;
    if (_controller != null && _controller!.value.isRecordingVideo) {
      final chunk = await _controller!.stopVideoRecording();
      _videoChunks.add(chunk.path);
    }

    if (_videoChunks.isEmpty) return null;
    if (_videoChunks.length == 1) return XFile(_videoChunks.first);

    // Merge chunks using Native MethodChannel
    final Directory tempDir = await getTemporaryDirectory();
    final String outputPath =
        '${tempDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final String? resultPath = await VideoMerger.mergeChunks(
      _videoChunks,
      outputPath,
    );

    if (resultPath != null) {
      // Cleanup chunks
      for (var path in _videoChunks) {
        try {
          File(path).delete();
        } catch (_) {}
      }
      _videoChunks.clear();
      return XFile(resultPath);
    }

    // Fallback to the first chunk if merge fails
    return XFile(_videoChunks.first);
  }

  CameraController? get controller => _controller;

  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  void dispose() {
    if (_isSwitching) return;
    _controller?.dispose();
    _controller = null;
    _videoChunks.clear();
  }
}

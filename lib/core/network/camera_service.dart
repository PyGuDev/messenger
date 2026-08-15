import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'video_merger.dart';

abstract interface class ChatCameraService {
  bool get isSwitching;
  CameraController? get controller;
  bool get isRecording;

  Future<void> initialize();
  Future<void> switchCamera();
  Future<void> startRecording();
  Future<XFile?> stopRecording();
  Future<void> reset();
  Future<void> dispose();
}

class CameraService implements ChatCameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  final List<String> _videoChunks = [];
  bool _isSwitching = false;
  int _sessionGeneration = 0;

  @override
  bool get isSwitching => _isSwitching;

  @override
  Future<void> initialize() async {
    final generation = _sessionGeneration;
    final allCameras = await availableCameras();
    if (generation != _sessionGeneration) return;
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
      await _initController(_cameras![_selectedCameraIndex], generation);
    }
  }

  Future<void> _initController(CameraDescription camera, int generation) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    if (generation != _sessionGeneration) {
      await controller.dispose();
      return;
    }
    _controller = controller;
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras == null ||
        _cameras!.length < 2 ||
        _controller == null ||
        _isSwitching) {
      return;
    }

    _isSwitching = true;
    final generation = _sessionGeneration;
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
      if (generation != _sessionGeneration) return;
      // Hardware cooldown
      await Future.delayed(const Duration(milliseconds: 200));
      if (generation != _sessionGeneration) return;

      await _initController(newCamera, generation);

      if (wasRecording && generation == _sessionGeneration) {
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

  @override
  Future<void> startRecording() async {
    if (_isSwitching) return;
    _videoChunks.clear();
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.startVideoRecording();
    }
  }

  @override
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

  @override
  CameraController? get controller => _controller;

  @override
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  @override
  Future<void> reset() async {
    _sessionGeneration++;
    _isSwitching = false;
    final controller = _controller;
    _controller = null;
    if (controller?.value.isRecordingVideo ?? false) {
      try {
        final chunk = await controller!.stopVideoRecording();
        _videoChunks.add(chunk.path);
      } catch (_) {}
    }
    await controller?.dispose();
    for (final path in _videoChunks) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _videoChunks.clear();
  }

  @override
  Future<void> dispose() => reset();
}

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract interface class VoiceRecordingService {
  Future<void> start();
  Future<String?> stop();
  Future<void> cancel();
  Stream<double> get amplitudeStream;
  Future<bool> isRecording();
  Future<void> dispose();
}

class VoiceRecorderService implements VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _activePath;
  int _sessionGeneration = 0;

  @override
  Future<void> start() async {
    final generation = _sessionGeneration;
    if (await _recorder.hasPermission()) {
      if (generation != _sessionGeneration) return;
      final tempDir = await getTemporaryDirectory();
      if (generation != _sessionGeneration) return;
      final path =
          '${tempDir.path}/voice_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1);

      await _recorder.start(config, path: path);
      _activePath = path;
      if (generation != _sessionGeneration) {
        await _cancelActiveRecording();
      }
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  @override
  Future<String?> stop() async {
    final path = await _recorder.stop();
    _activePath = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    _sessionGeneration++;
    await _cancelActiveRecording();
  }

  Future<void> _cancelActiveRecording() async {
    final path = await _recorder.isRecording()
        ? await _recorder.stop()
        : _activePath;
    _activePath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Stream<double> get amplitudeStream {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).map((
      amp,
    ) {
      // Normalize amplitude for waveform visualization
      // Typical range is -160 to 0 dB.
      // We want 0.0 to 1.0
      final value = (amp.current + 160) / 160;
      return value.clamp(0.0, 1.0);
    });
  }

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}

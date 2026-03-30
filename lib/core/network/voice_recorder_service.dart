import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<void> start() async {
    if (await _recorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
      );

      await _recorder.start(config, path: path);
    } else {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    return path;
  }

  Future<void> cancel() async {
    final path = await _recorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Stream<double> get amplitudeStream {
    return _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .map((amp) {
      // Normalize amplitude for waveform visualization
      // Typical range is -160 to 0 dB.
      // We want 0.0 to 1.0
      final value = (amp.current + 160) / 160;
      return value.clamp(0.0, 1.0);
    });
  }

  Future<bool> isRecording() => _recorder.isRecording();

  void dispose() {
    _recorder.dispose();
  }
}

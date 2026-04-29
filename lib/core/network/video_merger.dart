import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoMerger {
  static const MethodChannel _channel = MethodChannel(
    'com.example.messenger/video_merger',
  );

  /// Merges multiple video chunks into a single video file using native APIs.
  /// Returns the path to the merged file, or null if it fails.
  static Future<String?> mergeChunks(
    List<String> chunkPaths,
    String outputPath,
  ) async {
    try {
      final String? result = await _channel.invokeMethod('mergeVideos', {
        'paths': chunkPaths,
        'outputPath': outputPath,
      });
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Error merging videos natively: ${e.message}');
      }
      return null;
    }
  }
}

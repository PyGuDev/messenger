import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // After super.application, the registrar is available and GeneratedPluginRegistrant has already run
    if let registrar = self.registrar(forPlugin: "VideoMerger") {
      let videoMergerChannel = FlutterMethodChannel(name: "com.example.messenger/video_merger",
                                                    binaryMessenger: registrar.messenger())
      
      videoMergerChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "mergeVideos" {
          guard let args = call.arguments as? [String: Any],
                let paths = args["paths"] as? [String],
                let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Paths or outputPath missing", details: nil))
            return
          }
          self.mergeVideos(paths: paths, outputPath: outputPath, result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func mergeVideos(paths: [String], outputPath: String, result: @escaping FlutterResult) {
    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      result(FlutterError(code: "TRACK_ERROR", message: "Could not create composition tracks", details: nil))
      return
    }

    var currentTime = CMTime.zero
    var firstTransform: CGAffineTransform?

    for path in paths {
      let url = URL(fileURLWithPath: path)
      let asset = AVAsset(url: url)
      
      let videoAssetTracks = asset.tracks(withMediaType: .video)
      let audioAssetTracks = asset.tracks(withMediaType: .audio)

      guard let assetVideoTrack = videoAssetTracks.first else { continue }
      
      // Store transform from first clip to maintain orientation
      if firstTransform == nil {
          firstTransform = assetVideoTrack.preferredTransform
      }

      let duration = asset.duration
      let timeRange = CMTimeRange(start: .zero, duration: duration)

      do {
        try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
        if let assetAudioTrack = audioAssetTracks.first {
          try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
        }
        currentTime = CMTimeAdd(currentTime, duration)
      } catch {
        print("Error inserting track: \(error)")
      }
    }
    
    if let transform = firstTransform {
        videoTrack.preferredTransform = transform
    }

    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Remove existing file if any
    if FileManager.default.fileExists(atPath: outputPath) {
      try? FileManager.default.removeItem(at: outputURL)
    }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      result(FlutterError(code: "EXPORT_ERROR", message: "Could not create export session", details: nil))
      return
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true

    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        switch exportSession.status {
        case .completed:
          result(outputPath)
        case .failed:
          result(FlutterError(code: "EXPORT_FAILED", message: exportSession.error?.localizedDescription, details: nil))
        case .cancelled:
          result(FlutterError(code: "EXPORT_CANCELLED", message: "Export was cancelled", details: nil))
        default:
          result(FlutterError(code: "EXPORT_UNKNOWN", message: "Unknown export status", details: nil))
        }
      }
    }
  }
}

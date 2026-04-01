package com.example.messenger

import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.media3.common.MediaItem
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.Transformer.Listener
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.messenger/video_merger"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "mergeVideos") {
                val paths = call.argument<List<String>>("paths")
                val outputPath = call.argument<String>("outputPath")
                if (paths != null && outputPath != null) {
                    mergeVideos(paths, outputPath, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Paths or outputPath missing", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun mergeVideos(paths: List<String>, outputPath: String, result: MethodChannel.Result) {
        val mediaItems = mutableListOf<EditedMediaItem>()
        for (path in paths) {
            val mediaItem = MediaItem.fromUri(Uri.fromFile(File(path)))
            mediaItems.add(EditedMediaItem.Builder(mediaItem).build())
        }

        val sequence = EditedMediaItemSequence(mediaItems)
        val composition = Composition.Builder(listOf(sequence)).build()

        val transformer = Transformer.Builder(this)
            .build()

        val listener = object : Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                runOnUiThread {
                    result.success(outputPath)
                }
            }

            override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                runOnUiThread {
                    result.error("EXPORT_FAILED", exportException.message, null)
                }
            }
        }

        transformer.addListener(listener)
        
        try {
            val outputFile = File(outputPath)
            if (outputFile.exists()) {
                outputFile.delete()
            }
            transformer.start(composition, outputPath)
        } catch (e: Exception) {
            result.error("TRANSFORM_START_FAILED", e.message, null)
        }
    }
}

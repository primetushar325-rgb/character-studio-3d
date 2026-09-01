package com.characterstudio.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.MediaStore

class MainActivity : FlutterActivity() {
    private val channel = "characterstudio/mediastore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToMovies" -> {
                    val fileName = call.argument<String>("fileName") ?: return@setMethodCallHandler result.error("ARG", "fileName missing", null)
                    val mime = call.argument<String>("mime") ?: "video/mp4"
                    val bytes = call.argument<ByteArray>("bytes") ?: return@setMethodCallHandler result.error("ARG", "bytes missing", null)
                    try {
                        val values = ContentValues().apply {
                            put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                            put(MediaStore.Video.Media.MIME_TYPE, mime)
                            if (Build.VERSION.SDK_INT >= 29) {
                                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/2DCharacterStudio")
                                put(MediaStore.Video.Media.IS_PENDING, 1)
                            } else {
                                @Suppress("DEPRECATION")
                                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
                                put(MediaStore.Video.Media.DATA, java.io.File(dir, "2DCharacterStudio/$fileName").absolutePath)
                            }
                        }
                        val resolver = contentResolver
                        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return@setMethodCallHandler result.error("IO", "insert failed", null)
                        resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return@setMethodCallHandler result.error("IO", "stream failed", null)
                        if (Build.VERSION.SDK_INT >= 29) {
                            val done = ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }
                            resolver.update(uri, done, null, null)
                        }
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("IO", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

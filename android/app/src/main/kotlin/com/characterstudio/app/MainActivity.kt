package com.characterstudio.app

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native bridge for Character Studio 3D.
 *
 * Responsibilities:
 *  - Real on-device screen recording (MediaProjection) used for video export.
 *  - Saving poster frames (PNG) into the MediaStore gallery.
 *  - Opening / sharing / deleting exported media.
 *
 * Everything runs locally; no network access happens here.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "app.characterstudio/native"
        private const val REQUEST_PROJECTION = 4201
        private const val REQUEST_NOTIFICATIONS = 4202
    }

    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingRecordingArgs: MutableMap<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isScreenRecordingSupported" -> result.success(true)

                    "startScreenRecording" -> {
                        val args = mutableMapOf<String, Any>()
                        (call.arguments as? Map<*, *>)?.forEach { (k, v) ->
                            if (k is String && v != null) args[k] = v
                        }
                        beginRecording(args, result)
                    }

                    "stopScreenRecording" -> {
                        ExportRecordingService.stop(this)
                        result.success(true)
                    }

                    "saveImageToGallery" -> {
                        val base64 = call.argument<String>("base64")
                        val name = call.argument<String>("name") ?: "poster"
                        if (base64.isNullOrBlank()) {
                            result.error("INVALID", "Empty image data", null)
                        } else {
                            try {
                                val uri = saveImage(base64, name)
                                result.success(uri.toString())
                            } catch (t: Throwable) {
                                result.error("SAVE_FAILED", t.message ?: "Could not save image", null)
                            }
                        }
                    }

                    "openMedia" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("INVALID", "Missing uri", null)
                        } else {
                            openMedia(uri)
                            result.success(true)
                        }
                    }

                    "deleteMedia" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("INVALID", "Missing uri", null)
                        } else {
                            try {
                                contentResolver.delete(Uri.parse(uri), null, null)
                                result.success(true)
                            } catch (t: Throwable) {
                                result.error("DELETE_FAILED", t.message ?: "Could not delete", null)
                            }
                        }
                    }

                    "shareMedia" -> {
                        val uri = call.argument<String>("uri")
                        val mime = call.argument<String>("mime") ?: "video/mp4"
                        if (uri == null) {
                            result.error("INVALID", "Missing uri", null)
                        } else {
                            try {
                                shareMedia(Uri.parse(uri), mime)
                                result.success(true)
                            } catch (t: Throwable) {
                                result.error("SHARE_FAILED", t.message ?: "Could not share", null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }
        ExportRecordingService.resultChannel = channel
    }

    // ---------------------------------------------------------------------
    // Screen recording flow
    // ---------------------------------------------------------------------

    private fun beginRecording(
        args: Map<String, Any>,
        result: MethodChannel.Result
    ) {
        if (pendingResult != null) {
            result.error("BUSY", "A recording request is already in progress", null)
            return
        }
        pendingRecordingArgs = args.toMutableMap()
        pendingResult = result

        // Android 13+: ask for the notification permission so the
        // "Recording…" notification is visible. Recording works without it.
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATIONS
            )
            return
        }
        askProjectionPermission()
    }

    private fun askProjectionPermission() {
        val manager =
            getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        try {
            startActivityForResult(
                manager.createScreenCaptureIntent(),
                REQUEST_PROJECTION
            )
        } catch (t: Throwable) {
            finishPending(null, "PROJECTION_FAILED", t.message ?: "Screen capture unavailable")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            // Continue with the projection prompt regardless of the choice —
            // the FGS notification is optional.
            askProjectionPermission()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PROJECTION) return

        val args = pendingRecordingArgs ?: return finishPending(null, "INVALID", "No pending export")
        if (resultCode != RESULT_OK || data == null) {
            finishPending(null, "PERMISSION_DENIED", "Screen recording permission was denied")
            return
        }

        try {
            val service = Intent(this, ExportRecordingService::class.java).apply {
                action = ExportRecordingService.ACTION_START
                putExtra(ExportRecordingService.EXTRA_CODE, resultCode)
                putExtra(ExportRecordingService.EXTRA_DATA, data)
                putExtra(ExportRecordingService.EXTRA_WIDTH, (args["width"] as? Number)?.toInt() ?: 1280)
                putExtra(ExportRecordingService.EXTRA_HEIGHT, (args["height"] as? Number)?.toInt() ?: 720)
                putExtra(ExportRecordingService.EXTRA_FPS, (args["fps"] as? Number)?.toInt() ?: 30)
                putExtra(ExportRecordingService.EXTRA_SECONDS, (args["seconds"] as? Number)?.toInt() ?: 10)
            }
            androidx.core.content.ContextCompat.startForegroundService(this, service)
            finishPending(mapOf("started" to true), null, null)
        } catch (t: Throwable) {
            finishPending(null, "START_FAILED", t.message ?: "Could not start recording")
        }
    }

    private fun finishPending(
        value: Map<String, Any?>?,
        errorCode: String?,
        errorMessage: String?
    ) {
        val result = pendingResult ?: return
        pendingResult = null
        pendingRecordingArgs = null
        if (errorCode != null) {
            result.error(errorCode, errorMessage, null)
        } else {
            result.success(value)
        }
    }

    // ---------------------------------------------------------------------
    // Media store helpers
    // ---------------------------------------------------------------------

    private fun saveImage(base64Data: String, displayName: String): Uri {
        val data = if (base64Data.contains(",")) base64Data.substringAfter(",") else base64Data
        val bytes = Base64.decode(data, Base64.DEFAULT)
        val bitmap: Bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalStateException("Invalid image data")

        val values = android.content.ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "${displayName}_${System.currentTimeMillis()}.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Character Studio 3D")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore rejected the image")

        contentResolver.openOutputStream(uri)?.use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        } ?: throw IllegalStateException("Could not open output stream")

        val done = android.content.ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
        contentResolver.update(uri, done, null, null)
        bitmap.recycle()
        return uri
    }

    private fun openMedia(uriString: String) {
        val uri = Uri.parse(uriString)
        val isVideo = uriString.contains("video", ignoreCase = true)
        val mime = if (isVideo) "video/mp4" else "image/png"
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // No viewer installed — silently ignore, the UI still shows the uri.
        }
    }

    private fun shareMedia(uri: Uri, mime: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(
            Intent.createChooser(intent, "Share exported animation")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    // ---------------------------------------------------------------------
    // Optional: share a local file through the Android share sheet.
    // (share_plus handles most cases; this is a fallback for raw paths.)
    // ---------------------------------------------------------------------

    private fun shareFile(path: String, mime: String) {
        val file = File(path)
        if (!file.exists()) return
        val uri = FileProvider.getUriForFile(
            this, "$packageName.fileprovider", file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, null))
    }
}

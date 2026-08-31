package com.characterstudio.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.util.DisplayMetrics
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Real on-device video export.
 *
 * Because the 3D scene is rendered by a WebView (model-viewer / three.js),
 * frame buffers are not directly accessible from Dart. The closest *real*
 * capture pipeline is Android's MediaProjection: it mirrors the app window
 * into a hardware encoder and writes an actual MP4 straight into MediaStore
 * (Movies/Character Studio 3D). Nothing is simulated — if this service fails,
 * Dart is notified and the UI reports an error.
 */
class ExportRecordingService : Service() {

    companion object {
        const val ACTION_START = "com.characterstudio.app.action.START_RECORD"
        const val ACTION_STOP = "com.characterstudio.app.action.STOP_RECORD"
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        const val EXTRA_WIDTH = "width"
        const val EXTRA_HEIGHT = "height"
        const val EXTRA_FPS = "fps"
        const val EXTRA_SECONDS = "seconds"

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "character_studio_export"

        /** Set by MainActivity so the service can push events back to Dart. */
        @Volatile
        var resultChannel: MethodChannel? = null

        fun stop(context: Context) {
            val intent = Intent(context, ExportRecordingService::class.java)
                .setAction(ACTION_STOP)
            try {
                context.startService(intent)
            } catch (_: Exception) {
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var recorder: MediaRecorder? = null
    private var outputUri: Uri? = null
    private var pfd: ParcelFileDescriptor? = null
    private var stopRunnable: Runnable? = null

    @Volatile
    private var stopping = false
    @Volatile
    private var recording = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRecording()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                if (recording) {
                    notifyError("Another recording is already running")
                    return START_NOT_STICKY
                }
                val code = intent.getIntExtra(EXTRA_CODE, 0)
                val data: Intent? = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_DATA)
                }
                val width = intent.getIntExtra(EXTRA_WIDTH, 1280)
                val height = intent.getIntExtra(EXTRA_HEIGHT, 720)
                val fps = intent.getIntExtra(EXTRA_FPS, 30)
                val seconds = intent.getIntExtra(EXTRA_SECONDS, 10)

                if (data == null || code == 0) {
                    notifyError("Recording permission data is missing")
                    return START_NOT_STICKY
                }
                startCapture(code, data, width, height, fps, seconds)
            }
        }
        return START_NOT_STICKY
    }

    private fun startCapture(
        code: Int,
        data: Intent,
        targetWidth: Int,
        targetHeight: Int,
        fps: Int,
        seconds: Int
    ) {
        try {
            startInForeground()

            val manager =
                getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = manager.getMediaProjection(code, data)
            this.projection = projection
            projection.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    if (recording) stopRecording()
                }
            }, handler)

            // Match the physical display but never exceed the requested size.
            val metrics: DisplayMetrics = resources.displayMetrics
            val screenW = metrics.widthPixels.coerceAtLeast(1)
            val screenH = metrics.heightPixels.coerceAtLeast(1)
            val scale = minOf(
                1f,
                minOf(
                    screenW.toFloat() / targetWidth,
                    screenH.toFloat() / targetHeight
                )
            )
            val w = ((targetWidth * scale).toInt() / 2 * 2).coerceAtLeast(2)
            val h = ((targetHeight * scale).toInt() / 2 * 2).coerceAtLeast(2)

            val values = ContentValues().apply {
                put(
                    MediaStore.Video.Media.DISPLAY_NAME,
                    "CharacterStudio_${System.currentTimeMillis()}.mp4"
                )
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Character Studio 3D")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values
            ) ?: throw IllegalStateException("MediaStore rejected the video")
            outputUri = uri

            val fd = contentResolver.openFileDescriptor(uri, "rw")
                ?: throw IllegalStateException("Could not open video output")
            pfd = fd

            val mr: MediaRecorder = if (Build.VERSION.SDK_INT >= 34) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            mr.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mr.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            mr.setVideoSize(w, h)
            mr.setVideoFrameRate(fps.coerceIn(1, 60))
            mr.setVideoEncodingBitRate(if (w >= 1000) 16_000_000 else 8_000_000)
            mr.setOutputFile(fd.fileDescriptor)
            mr.prepare()
            mr.start()
            recorder = mr

            display = projection.createVirtualDisplay(
                "character-studio-capture",
                w, h, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mr.surface, null, handler
            )

            recording = true
            notifyFlutter(
                "recordingStarted",
                mapOf(
                    "width" to w, "height" to h,
                    "fps" to fps, "seconds" to seconds,
                    "uri" to uri.toString()
                )
            )

            val r = Runnable { stopRecording() }
            stopRunnable = r
            handler.postDelayed(r, seconds * 1000L + 400L)
        } catch (t: Throwable) {
            fail(t.message ?: "Recording failed")
        }
    }

    private fun stopRecording() {
        if (stopping) return
        stopping = true
        stopRunnable?.let { handler.removeCallbacks(it) }
        stopRunnable = null

        val hadRecording = recording
        recording = false

        try { display?.release() } catch (_: Exception) {}
        display = null
        try { recorder?.stop() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        try { projection?.stop() } catch (_: Exception) {}
        projection = null
        try { pfd?.close() } catch (_: Exception) {}
        pfd = null

        val uri = outputUri
        outputUri = null
        var size = 0L
        if (uri != null) {
            try {
                val done = ContentValues().apply {
                    put(MediaStore.Video.Media.IS_PENDING, 0)
                }
                contentResolver.update(uri, done, null, null)
                size = contentResolver.openAssetFileDescriptor(uri, "r")?.use { it.length } ?: 0L
            } catch (_: Exception) {}
        }

        @Suppress("DEPRECATION")
        stopForeground(true)
        stopSelf()

        if (hadRecording && uri != null) {
            notifyFlutter(
                "recordingFinished",
                mapOf("uri" to uri.toString(), "sizeBytes" to size)
            )
        } else if (uri != null) {
            // Started flag never went out — treat as failure.
            try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
            notifyFlutter("recordingError", mapOf("message" to "Recording stopped too early"))
        }
        stopping = false
    }

    private fun fail(message: String) {
        try { display?.release() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        try { projection?.stop() } catch (_: Exception) {}
        try { pfd?.close() } catch (_: Exception) {}
        display = null; recorder = null; projection = null; pfd = null
        outputUri?.let { uri ->
            try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
        }
        outputUri = null
        recording = false
        @Suppress("DEPRECATION")
        stopForeground(true)
        stopSelf()
        notifyError(message)
    }

    private fun notifyError(message: String) =
        notifyFlutter("recordingError", mapOf("message" to message))

    private fun notifyFlutter(method: String, args: Map<String, Any?>) {
        handler.post {
            try {
                resultChannel?.invokeMethod(method, args)
            } catch (_: Exception) {
            }
        }
    }

    private fun startInForeground() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Animation export",
                    NotificationManager.IMPORTANCE_LOW
                ).apply { description = "Shows while an animation video is being exported" }
            )
        }

        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, ExportRecordingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_record)
            .setContentTitle("Recording animation…")
            .setContentText("Character Studio 3D is exporting your video")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, "Stop", stopIntent)
            .build()

        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        stopRunnable?.let { handler.removeCallbacks(it) }
        if (recording) stopRecording()
        super.onDestroy()
    }
}

import 'dart:async';

import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

/// Events pushed from the native recording service.
class RecordingEvent {
  const RecordingEvent.started({
    required this.width,
    required this.height,
    required this.fps,
    required this.seconds,
    required this.uri,
  })  : finished = false,
        errorMessage = null,
        sizeBytes = 0;

  const RecordingEvent.finished({required this.uri, required this.sizeBytes})
      : finished = true,
        width = 0,
        height = 0,
        fps = 0,
        seconds = 0,
        errorMessage = null;

  const RecordingEvent.error(String message)
      : finished = false,
        width = 0,
        height = 0,
        fps = 0,
        seconds = 0,
        uri = null,
        sizeBytes = 0,
        errorMessage = message;

  final bool finished;
  final int width;
  final int height;
  final int fps;
  final int seconds;
  final String? uri;
  final int sizeBytes;
  final String? errorMessage;
}

/// Method-channel bridge to the native Android layer:
///  - MediaProjection screen recording (real video export)
///  - MediaStore gallery insert for poster frames
///  - open / delete exported media
class ExportService {
  ExportService() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const MethodChannel _channel = MethodChannel(AppConstants.nativeChannel);

  final _events = StreamController<RecordingEvent>.broadcast();
  Stream<RecordingEvent> get events => _events.stream;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'recordingStarted':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _events.add(RecordingEvent.started(
          width: (args['width'] as num?)?.toInt() ?? 0,
          height: (args['height'] as num?)?.toInt() ?? 0,
          fps: (args['fps'] as num?)?.toInt() ?? 30,
          seconds: (args['seconds'] as num?)?.toInt() ?? 10,
          uri: args['uri'] as String? ?? '',
        ));
        break;
      case 'recordingFinished':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _events.add(RecordingEvent.finished(
          uri: args['uri'] as String? ?? '',
          sizeBytes: (args['sizeBytes'] as num?)?.toInt() ?? 0,
        ));
        break;
      case 'recordingError':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _events.add(RecordingEvent.error(
            args['message'] as String? ?? 'Recording failed'));
        break;
    }
    return null;
  }

  Future<bool> get isScreenRecordingSupported async {
    try {
      return await _channel.invokeMethod<bool>('isScreenRecordingSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the user for projection permission and starts the recorder.
  /// Throws [PlatformException] with code PERMISSION_DENIED when cancelled.
  Future<void> startScreenRecording({
    required int width,
    required int height,
    required int fps,
    required int seconds,
  }) async {
    await _channel.invokeMethod('startScreenRecording', {
      'width': width,
      'height': height,
      'fps': fps,
      'seconds': seconds,
    });
  }

  Future<void> stopScreenRecording() async {
    try {
      await _channel.invokeMethod('stopScreenRecording');
    } catch (_) {}
  }

  /// Saves a PNG data-URL into the gallery; returns the content URI.
  Future<String> saveImageToGallery(String dataUrl, String name) async {
    final uri = await _channel.invokeMethod<String>('saveImageToGallery', {
      'base64': dataUrl,
      'name': name,
    });
    return uri ?? '';
  }

  Future<void> openMedia(String uri) async {
    try {
      await _channel.invokeMethod('openMedia', {'uri': uri});
    } catch (_) {}
  }

  Future<void> deleteMedia(String uri) async {
    await _channel.invokeMethod('deleteMedia', {'uri': uri});
  }

  /// Shares a MediaStore content URI through the Android share sheet.
  Future<void> shareMedia(String uri, {String mime = 'video/mp4'}) async {
    try {
      await _channel.invokeMethod('shareMedia', {'uri': uri, 'mime': mime});
    } catch (_) {}
  }

  void dispose() {
    _events.close();
  }
}

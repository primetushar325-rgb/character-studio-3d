import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../services/export_service.dart';

enum ExportPhase { idle, requesting, recording, done, error }

/// State of the on-device video-export pipeline (real MediaProjection).
class ExportProvider extends ChangeNotifier {
  ExportProvider(this._service) {
    _subscription = _service.events.listen(_onEvent);
  }

  final ExportService _service;
  StreamSubscription<RecordingEvent>? _subscription;

  ExportPhase _phase = ExportPhase.idle;
  RecordingEvent? _lastEvent;
  String? _error;
  DateTime? _startedAt;
  int _plannedSeconds = 0;

  ExportPhase get phase => _phase;
  RecordingEvent? get lastEvent => _lastEvent;
  String? get error => _error;
  DateTime? get startedAt => _startedAt;
  int get plannedSeconds => _plannedSeconds;
  ExportService get service => _service;

  bool get isBusy => _phase == ExportPhase.requesting || _phase == ExportPhase.recording;

  Future<bool> get isSupported => _service.isScreenRecordingSupported;

  Future<void> startRecording({
    required int width,
    required int height,
    required int fps,
    required int seconds,
  }) async {
    _phase = ExportPhase.requesting;
    _error = null;
    _lastEvent = null;
    _plannedSeconds = seconds;
    notifyListeners();
    try {
      await _service.startScreenRecording(
        width: width,
        height: height,
        fps: fps,
        seconds: seconds,
      );
      // The native side returns after the service was launched; the
      // recordingStarted event flips us into `recording`.
    } catch (e) {
      _phase = ExportPhase.error;
      if (e is PlatformException && e.code == 'PERMISSION_DENIED') {
        _error = 'Screen recording permission was denied.';
      } else if (e is PlatformException) {
        _error = e.message ?? 'Recording could not be started.';
      } else {
        _error = 'Recording could not be started.';
      }
      notifyListeners();
    }
  }

  Future<void> stopRecording() => _service.stopScreenRecording();

  void _onEvent(RecordingEvent event) {
    switch (event.errorMessage) {
      case null:
        break;
      default:
        _phase = ExportPhase.error;
        _error = event.errorMessage;
        notifyListeners();
        return;
    }

    if (event.finished) {
      _phase = ExportPhase.done;
      _lastEvent = event;
      _startedAt = null;
      notifyListeners();
      return;
    }

    // started event
    _phase = ExportPhase.recording;
    _startedAt = DateTime.now();
    _lastEvent = event;
    notifyListeners();
  }

  /// Acknowledge the result (after showing the success dialog).
  void reset() {
    _phase = ExportPhase.idle;
    _lastEvent = null;
    _error = null;
    _startedAt = null;
    notifyListeners();
  }

  Future<String> savePoster(String dataUrl, String name) =>
      _service.saveImageToGallery(dataUrl, name);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

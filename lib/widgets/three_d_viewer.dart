import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/character.dart';
import '../models/viewer_enums.dart';
import '../services/viewer_server_service.dart';

/// Lifecycle of a model inside the viewer.
enum ViewerLoadState { idle, loading, ready, error }

/// Events emitted by the underlying 3D engine (via the JS bridge).
class ViewerEvent {
  ViewerEvent.progress(this.value)
      : type = 'progress',
        animations = const [],
        currentTime = 0,
        duration = 0;

  ViewerEvent.loaded(this.animations, this.duration)
      : type = 'load',
        value = 1.0,
        currentTime = 0;

  ViewerEvent.failed()
      : type = 'error',
        value = 0,
        animations = const [],
        currentTime = 0,
        duration = 0;

  ViewerEvent.tick(this.currentTime, this.duration)
      : type = 'tick',
        value = 0,
        animations = const [];

  final String type;
  final double value;
  final List<String> animations;
  final double currentTime;
  final double duration;
}

/// The reusable, fully generic animation player.
///
///   playAnimation(modelPath, animationName, loop: true)
///   pause / resume / stop / restart / setPlaybackSpeed / setLoop
///   getAvailableAnimations(modelPath)
///
/// It works for *any* GLB — no character-specific code anywhere. The
/// underlying renderer is the bundled model-viewer engine (three.js) hosted
/// in a WebView and served from the on-device loopback server.
class ThreeDController extends ChangeNotifier {
  ThreeDController() {
    _events = StreamController<ViewerEvent>.broadcast();
  }

  WebViewController? _web;
  bool _pageReady = false;
  final List<String> _jsQueue = [];

  ViewerLoadState _state = ViewerLoadState.idle;
  double _progress = 0;
  List<String> _discoveredAnimations = [];
  double _currentTime = 0;
  double _duration = 0;
  bool _isPlaying = false;
  bool _loop = true;
  double _speed = 1.0;
  String? _currentAnimationName;
  Character? _character;

  // Playback verification: detect a stalled clip.
  double _lastTickTime = 0;
  DateTime _lastAdvance = DateTime.now();

  late StreamController<ViewerEvent> _events;
  Stream<ViewerEvent> get events => _events.stream;

  Completer<String?>? _thumbnailCompleter;

  // ---- state getters ------------------------------------------------------
  ViewerLoadState get state => _state;
  double get progress => _progress;
  List<String> get discoveredAnimations => List.unmodifiable(_discoveredAnimations);
  double get currentTime => _currentTime;
  double get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get loop => _loop;
  double get speed => _speed;
  String? get currentAnimationName => _currentAnimationName;
  Character? get character => _character;
  bool get isReady => _state == ViewerLoadState.ready;
  bool get hasAnimationSelected => _currentAnimationName != null;

  // ---- bootstrap ------------------------------------------------------------
  Future<void> _ensureWebView() async {
    if (_web != null) return;

    final server = ViewerServerService.instance;
    final port = await server.start();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0D12))
      ..addJavaScriptChannel('StudioBridge', onMessageReceived: _onBridgeMessage)
      ..loadRequest(Uri.parse('http://127.0.0.1:$port/viewer/index.html'));

    _web = controller;
    // The viewer widget rebuilds once the controller exists.
    notifyListeners();
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      if (data is! Map<String, dynamic>) return;
      final type = data['type'] as String? ?? '';

      switch (type) {
        case 'pageReady':
          _pageReady = true;
          _flushQueue();
          break;
        case 'progress':
          _progress = ((data['value'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
          if (_state == ViewerLoadState.loading) notifyListeners();
          _events.add(ViewerEvent.progress(_progress));
          break;
        case 'load':
          _discoveredAnimations =
              (data['animations'] as List? ?? []).whereType<String>().toList();
          _duration = (data['duration'] as num?)?.toDouble() ?? 0;
          _state = ViewerLoadState.ready;
          _progress = 1;
          notifyListeners();
          _events.add(ViewerEvent.loaded(_discoveredAnimations, _duration));
          break;
        case 'error':
          _state = ViewerLoadState.error;
          notifyListeners();
          _events.add(ViewerEvent.failed());
          break;
        case 'tick':
          final t = (data['time'] as num?)?.toDouble() ?? 0;
          final d = (data['duration'] as num?)?.toDouble() ?? 0;
          if (t != _lastTickTime) {
            _lastAdvance = DateTime.now();
            _lastTickTime = t;
          }
          _currentTime = t;
          if (d > 0) _duration = d;
          _isPlaying = hasAnimationSelected &&
              DateTime.now().difference(_lastAdvance).inMilliseconds < 600;
          notifyListeners();
          _events.add(ViewerEvent.tick(t, d));
          break;
        case 'thumbnail':
          _thumbnailCompleter?.complete(data['data'] as String?);
          _thumbnailCompleter = null;
          break;
      }
    } catch (_) {
      // Malformed bridge payloads must never crash the app.
    }
  }

  // ---- JS plumbing -------------------------------------------------------------
  Future<void> _eval(String js) async {
    await _ensureWebView();
    if (!_pageReady) {
      _jsQueue.add(js);
      return;
    }
    try {
      await _web!.runJavaScript(js);
    } catch (_) {}
  }

  void _flushQueue() {
    final queue = List<String>.from(_jsQueue);
    _jsQueue.clear();
    for (final js in queue) {
      _web?.runJavaScript(js).catchError((_) {});
    }
  }

  // ---- public API ----------------------------------------------------------------
  /// Loads a character (any GLB) into the viewer.
  Future<void> loadCharacter(Character c) async {
    _character = c;
    _state = ViewerLoadState.loading;
    _progress = 0;
    _discoveredAnimations = [];
    _currentTime = 0;
    _duration = 0;
    _currentAnimationName = null;
    _isPlaying = false;
    notifyListeners();

    await _eval('studio.setModel(${jsonEncode(serverModelUrl(c))})');
  }

  String serverModelUrl(Character c) =>
      'http://127.0.0.1:${ViewerServerService.instance.port}${c.serverModelPath}';

  /// The generic animation entry point: play `animationName` from `modelPath`.
  Future<void> playAnimation(
    String modelPath,
    String? animationName, {
    bool loop = true,
  }) async {
    _loop = loop;
    _currentAnimationName = animationName;
    await _eval('studio.setLoop(${jsonEncode(loop)})');
    if (animationName != null && animationName.isNotEmpty) {
      await _eval('studio.setAnimation(${jsonEncode(animationName)})');
    }
    await _eval('studio.play()');
    _isPlaying = animationName != null && animationName.isNotEmpty;
    _lastAdvance = DateTime.now();
    notifyListeners();
  }

  Future<void> pauseAnimation() async {
    await _eval('studio.pause()');
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resumeAnimation() async {
    await _eval('studio.play()');
    _isPlaying = hasAnimationSelected;
    _lastAdvance = DateTime.now();
    notifyListeners();
  }

  Future<void> stopAnimation() async {
    await _eval('studio.stop()');
    _isPlaying = false;
    _currentTime = 0;
    notifyListeners();
  }

  Future<void> restartAnimation() async {
    await _eval('studio.restart()');
    _currentTime = 0;
    _isPlaying = hasAnimationSelected;
    _lastAdvance = DateTime.now();
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed;
    await _eval('studio.setSpeed(${jsonEncode(speed)})');
    notifyListeners();
  }

  Future<void> setLoop(bool enabled) async {
    _loop = enabled;
    await _eval('studio.setLoop(${jsonEncode(enabled)})');
    notifyListeners();
  }

  Future<void> seekTo(double seconds) async {
    _currentTime = seconds;
    await _eval('studio.seek(${jsonEncode(seconds)})');
    notifyListeners();
  }

  Future<void> selectAnimation(String? animationName) async {
    _currentAnimationName = animationName;
    await _eval(
        'studio.setAnimation(${jsonEncode(animationName ?? '')})');
    notifyListeners();
  }

  Future<void> setAutoRotateCamera(bool enabled) =>
      _eval('studio.setAutoRotate(${jsonEncode(enabled)})');

  Future<void> setCameraOrbit(String orbit) =>
      _eval('studio.setOrbit(${jsonEncode(orbit)})');

  Future<void> resetCamera() => _eval('studio.resetCamera()');

  Future<void> applyLighting(LightingPreset preset) => _eval(
      'studio.setLighting(${preset.exposure}, ${preset.shadowIntensity}, ${preset.shadowSoftness})');

  Future<void> applyBackground(BackgroundPreset preset, {String? customHex}) => _eval(
      'studio.setBackground(${jsonEncode(backgroundCss(preset, customHex: customHex))})');

  /// Animation names discovered from the live scene (the Dart GLB parser is
  /// the primary source; this verifies/extends it at runtime).
  Future<List<String>> getAvailableAnimations(Character character) async {
    if (_character?.id != character.id) {
      await loadCharacter(character);
      // Wait (bounded) for the load event.
      final completer = Completer<List<String>>();
      late StreamSubscription sub;
      sub = events.listen((e) {
        if (e.type == 'load' && !completer.isCompleted) {
          completer.complete(_discoveredAnimations);
        }
        if (e.type == 'error' && !completer.isCompleted) {
          completer.complete(const []);
        }
      });
      Future.delayed(const Duration(seconds: 45), () {
        if (!completer.isCompleted) completer.complete(_discoveredAnimations);
      });
      await completer.future;
      await sub.cancel();
    }
    return _discoveredAnimations;
  }

  /// Captures the current frame as a PNG data-URL (thumbnails / posters).
  Future<String?> captureThumbnail({Duration timeout = const Duration(seconds: 6)}) async {
    if (_state != ViewerLoadState.ready) return null;
    _thumbnailCompleter = Completer<String?>();
    await _eval('studio.capture()');
    try {
      return await _thumbnailCompleter!.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// Releases GPU resources for the loaded model (call when leaving screen).
  Future<void> disposeModel() async {
    try {
      await _eval('studio.dispose()');
    } catch (_) {}
    _state = ViewerLoadState.idle;
    _character = null;
    notifyListeners();
  }

  @override
  void dispose() {
    try {
      _web?.runJavaScript('studio.dispose()').catchError((_) {});
    } catch (_) {}
    _events.close();
    super.dispose();
  }
}

/// The 3D viewport widget. Owns nothing — renders the WebView belonging to
/// [controller]. Create the controller in the screen and dispose it there.
class ThreeDViewer extends StatelessWidget {
  const ThreeDViewer({super.key, required this.controller});

  final ThreeDController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final web = controller._web;
        if (web == null) {
          return const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        return WebViewWidget(controller: web);
      },
    );
  }
}

/// Exposes the private webview controller to ThreeDViewer safely.
extension ThreeDControllerWeb on ThreeDController {
  WebViewController? get webView => _web;
}

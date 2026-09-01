import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../backgrounds/backgrounds.dart';
import '../characters2d/character2d_model.dart';
import '../characters2d/engine/face_rig.dart';
import '../characters2d/puppet_controller.dart';
import '../state/library2d_provider.dart';

/// Canvas presets (always true 16:9).
class SceneLayer {
  SceneLayer(this.id, this.name, {this.visible = true, this.locked = false});
  final String id;
  final String name;
  bool visible;
  bool locked;
}

/// One composition layer entry for the Layers panel (ordered bottom→top).
/// Character always renders above background regardless of reordering of the
/// overlay layers; [order] only sorts shadow/effects/foreground overlays.
/// Transform of the character inside the composition.
class CharacterTransform {
  CharacterTransform({
    this.x = 0.5,
    this.y = 0.78,
    this.scale = 1,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.opacity = 1,
  });

  double x; // 0..1 of canvas width
  double y; // 0..1 of canvas height (ground line)
  double scale; // 1 = default height
  double rotation; // degrees
  bool flipH;
  bool flipV;
  double opacity; // 0..1
}

/// The whole 16:9 editor state: character + transform + background + layers +
/// playback. Persistence-ready via [toJson]/[fromJson].
class EditorProvider extends ChangeNotifier {
  EditorProvider(this._library);

  final Library2DProvider _library;
  PuppetController? controller;
  Character2D? character;

  final CharacterTransform transform = CharacterTransform();
  BgConfig background = BgConfig();
  ui.Image? bgImage;

  final List<SceneLayer> layers = [
    SceneLayer('background', 'Background'),
    SceneLayer('shadow', 'Character Shadow'),
    SceneLayer('character', 'Character'),
    SceneLayer('effects', 'Effects (vignette)'),
    SceneLayer('foreground', 'Foreground haze'),
  ];

  String projectName = 'My Animation';
  int canvasWidth = 1920;
  int canvasHeight = 1080;

  bool effectsVignette = false;
  bool foregroundHaze = false;

  void setEffects(bool v) {
    effectsVignette = v;
    notifyListeners();
  }

  void setForegroundHaze(bool v) {
    foregroundHaze = v;
    notifyListeners();
  }

  PuppetController? loadCharacter(String characterId) {
    final c = _library.byId(characterId);
    if (c == null) return controller;
    controller?.dispose();
    character = c;
    final ctl = PuppetController(spec: c.spec, palette: c.colors, accessories: {...c.accessories});
    controller = ctl;
    _library.recordUsage(characterId);
    notifyListeners();
    return ctl;
  }

  void setTransform(void Function(CharacterTransform t) fn) {
    fn(transform);
    notifyListeners();
  }

  void setBackground(BgConfig cfg) {
    background = cfg;
    notifyListeners();
  }

  Future<void> loadBgImage(String path) async {
    final data = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    bgImage = frame.image;
    background.imagePath = path;
    background.kind = BgKind.image;
    notifyListeners();
  }

  void setLayerVisible(String id, bool v) {
    for (final l in layers) {
      if (l.id == id && !l.locked) l.visible = v;
    }
    notifyListeners();
  }

  void toggleLayerLock(String id) {
    for (final l in layers) {
      if (l.id == id) l.locked = !l.locked;
    }
    notifyListeners();
  }

  void moveLayer(int oldIndex, int newIndex) {
    // Never move the character below the background.
    if (oldIndex < 2 || newIndex < 2) return;
    final item = layers.removeAt(oldIndex);
    layers.insert(newIndex.clamp(2, layers.length), item);
    notifyListeners();
  }

  // ---- Playback passthrough ------------------------------------------------
  void play() {
    controller?.setPlaying(true);
    notifyListeners();
  }

  void pause() {
    controller?.setPlaying(false);
    notifyListeners();
  }

  void stop() {
    final c = controller;
    if (c == null) return;
    c.setPlaying(false);
    c.setAction(c.actionId);
    notifyListeners();
  }

  void stepFrame(int delta) {
    final c = controller;
    if (c == null) return;
    c.setPlaying(false);
    final fps = 30.0;
    final t = (c.animator.clipTime + delta / fps) % c.animator.clipDuration;
    c.animator.scrub(t);
    notifyListeners();
  }

  void scrub(double t) {
    controller?.setPlaying(false);
    controller?.animator.scrub(t);
    notifyListeners();
  }

  void setSpeed(double s) {
    controller?.setSpeed(s);
    notifyListeners();
  }

  void setLoop(bool v) {
    controller?.loop = v;
    notifyListeners();
  }

  void setAction(String id) {
    controller?.setAction(id);
    notifyListeners();
  }

  void setExpression(Expr e) {
    controller?.setExpression(e);
    notifyListeners();
  }

  void setTalking(bool on) {
    controller?.setTalking(on);
    notifyListeners();
  }

  void setDirection(bool left) {
    controller?.setDirection(left ? -1 : 1);
    notifyListeners();
  }

  void setCanvasSize(int w, int h) {
    canvasWidth = w;
    canvasHeight = h;
    notifyListeners();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

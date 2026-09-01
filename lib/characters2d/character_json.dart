import 'dart:convert';

import 'engine/clips.dart';
import 'engine/keyframes.dart';
import 'engine/part2d.dart';
import 'engine/rig2d.dart';
import 'engine/shapes.dart';
import 'art/character_catalog.dart';
import 'art/palettes.dart';

/// Portable character.json builder (spec §CHARACTER FILE FORMAT):
/// name/version/type/canvas/bones/layers/animations — fully reusable.
Map<String, dynamic> buildCharacterJson(
  Character2DSpec spec,
  PaletteColors palette, {
  int fps = 30,
  List<String>? animationIds,
}) {
  final rig = Rig2D.byKind(spec.rigKind);
  final resolver = palette.toResolver();
  final clips = ClipLibrary.forRig(spec.rigKind);
  final ids = animationIds ??
      const [
        'idle', 'walk', 'run', 'sit', 'sit_idle', 'sleep', 'sleep_loop', 'talk',
        'jump', 'wave', 'action', 'happy', 'sad', 'think', 'turn', 'fall',
        'walk_start', 'walk_stop', 'run_start', 'run_stop',
        'stand_to_sit', 'sit_to_stand', 'to_sleep', 'wake_up',
      ];
  final faceView = const FaceView();

  return {
    'name': spec.name,
    'version': '1.0',
    'type': '2D_RIGGED_CHARACTER',
    'rigKind': spec.rigKind,
    'canvas': {'width': 1080, 'height': 1080},
    'palette': resolver.slots.map((k, v) => MapEntry(k, '#${v.value.toRadixString(16).padLeft(8, '0').substring(2)}')),
    'faceStyle': spec.faceStyle == null
        ? null
        : {
            'eyeDx': spec.faceStyle!.eyeDx,
            'eyeY': spec.faceStyle!.eyeY,
            'eyeRx': spec.faceStyle!.eyeRx,
            'eyeRy': spec.faceStyle!.eyeRy,
            'browY': spec.faceStyle!.browY,
            'browLen': spec.faceStyle!.browLen,
            'browThick': spec.faceStyle!.browThick,
            'mouthY': spec.faceStyle!.mouthY,
            'mouthW': spec.faceStyle!.mouthW,
            'lash': spec.faceStyle!.lash,
          },
    'faceStyleKind': spec.rigKind == 'quadruped_v1' ? 'animal' : 'human',
    'bones': [
      for (final b in rig.bones)
        {
          'name': b.name,
          'parent': b.parent,
          'x': b.attach.x,
          'y': b.attach.y,
          'rotation': b.restAngle,
          'pivotX': 0,
          'pivotY': 0,
          'length': b.length,
        }
    ],
    'layers': [
      for (final part in orderParts(spec.build({})))
        {
          'bone': part.bone,
          'z': part.z,
          'layer': part.layer.name,
          'dynamic': _isDynamic(part),
          'shapes': _isDynamic(part)
              ? const <Map<String, dynamic>>[]
              : [
                  for (final s in part.build(ShapeCtx(colors: resolver, extras: const {}, face: faceView)))
                    _shapeToJson(s, resolver),
                ],
        }
    ],
    'animations': [
      for (final id in ids)
        if (clips[id] != null)
          bakeClip(id, id, clips[id]!.duration, clips[id]!.loop, rig, clips[id]!.sample, fps).toJson(),
      // 'sleep' composite: settle (to_sleep) then loop the breathing sleep
      // pose — exported as one portable animation.
      // 'sit' composite for rigs that store sit as a transition + hold.
      if (clips['sit'] == null && clips['stand_to_sit'] != null && clips['sit_idle'] != null)
        bakeClip('sit', 'sit', clips['stand_to_sit']!.duration + 2.0, false, rig, (t) {
          final settle = clips['stand_to_sit']!;
          final hold = clips['sit_idle']!;
          return t < settle.duration
              ? settle.sample(t)
              : hold.sample((t - settle.duration) % hold.duration);
        }, fps).toJson(),
      if (clips['sleep'] == null && clips['to_sleep'] != null && clips['sleep_loop'] != null)
        bakeClip('sleep', 'sleep', clips['to_sleep']!.duration + 3.0, false, rig, (t) {
          final settle = clips['to_sleep']!;
          final loop = clips['sleep_loop']!;
          return t < settle.duration
              ? settle.sample(t)
              : loop.sample((t - settle.duration) % loop.duration);
        }, fps).toJson(),
    ],
  };
}

bool _isDynamic(Part2D part) => part.bone == 'head' && _headIsDynamic(part);

bool _headIsDynamic(Part2D part) {
  // Face-bearing head parts rebuild with live face params (eyes/blink).
  return true;
}

Map<String, dynamic> _shapeToJson(Shape s, dynamic resolver) {
  return {
    'kind': s.kind.name,
    'args': s.args,
    'points': [for (final p in s.points) [p.dx, p.dy]],
    'ops': s is DynShape ? s.ops : const <String>[],
    'fill': s.fill is ConstFill ? {'const': '#${(s.fill as ConstFill).value.value.toRadixString(16).padLeft(8, '0').substring(2)}'} : {'slot': (s.fill as SolidFillSlot).slot},
    'stroke': s.stroke,
    'strokeWidth': s.strokeWidth,
    'opacity': s.opacity,
  };
}

String characterJsonString(Character2DSpec spec, PaletteColors palette) =>
    const JsonEncoder.withIndent('  ').convert(buildCharacterJson(spec, palette));

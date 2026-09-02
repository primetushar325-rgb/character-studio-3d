// Visual regression probe: renders the Fox (and a legacy baseline) to PNGs in
// the system temp dir and asserts real coverage — catches 'parts not painted',
// 'all-black silhouette' and 'sleep off-canvas' class regressions.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:character_studio_3d/characters2d/art/character_catalog.dart';
import 'package:character_studio_3d/characters2d/engine/animator2d.dart';
import 'package:character_studio_3d/characters2d/engine/puppet.dart';
import 'package:character_studio_3d/characters2d/engine/rig2d.dart';

Future<void> _save(PainterWrapper w, String path, Size size) async {
  final boundary = w.boundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  File(path).writeAsBytesSync(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
}

class PainterWrapper extends StatelessWidget {
  const PainterWrapper(this.painter, this.size, {super.key});
  final CustomPainter painter;
  final Size size;
  final GlobalKey key2 = const GlobalObjectKey('probe');
  RenderRepaintBoundary get boundary =>
      key2.currentContext!.findRenderObject() as RenderRepaintBoundary;
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: key2,
      child: CustomPaint(painter: painter, size: size),
    );
  }
}

void main() {
  testWidgets('fox visual probe', (tester) async {
    final spec = CharacterCatalog.byId('fox')!;
    final an = PuppetAnimator(rig: Rig2D.byKind(spec.rigKind), seed: 7);

    Future<void> snap(String clip, double t, String name) async {
      an.play(clip);
      an.scrub(t, faceTime: t);
      an.update(0);
      final w = PainterWrapper(
        PuppetPainter(
          spec: spec,
          resolver: spec.defaultResolver(),
          accessories: const {'scarf'},
          frameGetter: () => an.update(0),
        ),
        const Size(300, 360),
      );
      await tester.pumpWidget(MaterialApp(
        color: const Color(0xFF20242B),
        home: Scaffold(
          backgroundColor: const Color(0xFF20242B),
          body: Center(child: w),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        await _save(w, '${Directory.systemTemp.path}/fox_$name.png', const Size(300, 360));
        final img = await w.boundary.toImage(pixelRatio: 1);
        final bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final px = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        var minX = 9999.0, maxX = -1.0, minY = 9999.0, maxY = -1.0, count = 0;
        for (var y = 0; y < 360; y++) {
          for (var x = 0; x < 300; x++) {
            final i = (y * 300 + x) * 4;
            final a = px[i + 3];
            if (a > 40) {
              count++;
              if (x < minX) minX = x.toDouble();
              if (x > maxX) maxX = x.toDouble();
              if (y < minY) minY = y.toDouble();
              if (y > maxY) maxY = y.toDouble();
            }
          }
        }
        // ignore: avoid_print
        print('STAT $name count=$count bbox=$minX,$minY..$maxX,$maxY');
      });
    }

    await snap('idle', 0.6, 'idle');
    await snap('walk', 0.35, 'walk');
    await snap('run', 0.25, 'run');
    await snap('wave', 0.5, 'wave');
    await snap('sleep_loop', 1.2, 'sleep');
    an.setTalking(true);
    await snap('idle', 0.8, 'talk');

    // Baseline: the tiger under identical conditions.
    var tSpec = CharacterCatalog.byId('tiger')!;
    final tAn = PuppetAnimator(rig: Rig2D.byKind(tSpec.rigKind), seed: 7);
    await tester.pumpWidget(Container());
    Future<void> tSnap(String clip, double t, String name) async {
      tAn.play(clip);
      tAn.scrub(t, faceTime: t);
      tAn.update(0);
      final w = PainterWrapper(
        PuppetPainter(
          spec: tSpec,
          resolver: tSpec.defaultResolver(),
          accessories: const {},
          frameGetter: () => tAn.update(0),
        ),
        const Size(300, 360),
      );
      await tester.pumpWidget(MaterialApp(
        color: const Color(0xFF20242B),
        home: Scaffold(backgroundColor: const Color(0xFF20242B), body: Center(child: w)),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        await _save(w, '${Directory.systemTemp.path}/tiger_$name.png', const Size(300, 360));
        final img = await w.boundary.toImage(pixelRatio: 1);
        final bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final px = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        var minX = 9999.0, maxX = -1.0, minY = 9999.0, maxY = -1.0, count = 0;
        for (var y = 0; y < 360; y++) {
          for (var x = 0; x < 300; x++) {
            final i = (y * 300 + x) * 4;
            if (px[i + 3] > 40) {
              count++;
              if (x < minX) minX = x.toDouble();
              if (x > maxX) maxX = x.toDouble();
              if (y < minY) minY = y.toDouble();
              if (y > maxY) maxY = y.toDouble();
            }
          }
        }
        // ignore: avoid_print
        print('TSTAT $name count=$count bbox=$minX,$minY..$maxX,$maxY');
      });
    }

    await tSnap('idle', 0.6, 'tiger_idle');
    tSpec = CharacterCatalog.byId('bd_farmer_male')!;
    tAn.play('sleep_loop');
    await tSnap('sleep_loop', 1.2, 'farmer_sleep');
    tAn.play('idle');
    await tSnap('idle', 0.6, 'farmer_idle');
    tAn.play('wave');
    await tSnap('wave', 0.5, 'farmer_wave');
  });
}

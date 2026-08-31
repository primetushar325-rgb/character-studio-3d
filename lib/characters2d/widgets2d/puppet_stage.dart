import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/puppet.dart';
import '../engine/rig2d.dart';
import '../art/palettes.dart';
import '../art/character_catalog.dart';
import '../puppet_controller.dart';

/// Live 2D puppet stage. Owns the ticker, drives [PuppetController.tick] and
/// repaints through the painter's `repaint` listenable — no setState per
/// frame, and the ticker auto-mutes when off-screen (lazy performance).
class PuppetStage extends StatefulWidget {
  const PuppetStage({
    super.key,
    required this.controller,
    this.background = const Color(0xFF171B26),
    this.showShadow = true,
  });

  final PuppetController controller;
  final Color background;
  final bool showShadow;

  @override
  State<PuppetStage> createState() => _PuppetStageState();
}

class _PuppetStageState extends State<PuppetStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    _last = elapsed;
    widget.controller.tick(dt.clamp(0.0, 0.05));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ClipRect(
      child: CustomPaint(
        size: Size.infinite,
        painter: PuppetPainter(
          spec: c.spec,
          palette: c.palette,
          accessories: c.accessories,
          frameGetter: () => c.frame,
          directionLeft: c.directionLeft,
          background: widget.background,
          showGroundShadow: widget.showShadow,
          repaint: c,
        ),
      ),
    );
  }
}

/// Static, cheap thumbnail rendered straight from the vector rig (full body,
/// neutral pose, clean background — always matches customization).
class PuppetThumbnail extends StatelessWidget {
  const PuppetThumbnail({super.key, required this.spec, required this.palette, this.accessories = const {}, this.background});

  final Character2DSpec spec;
  final PaletteColors palette;
  final Set<String> accessories;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final source = StaticFrameSource(Rig2D.humanoidV1());
    return CustomPaint(
      size: Size.infinite,
      painter: PuppetPainter(
        spec: spec,
        palette: palette,
        accessories: accessories,
        frameGetter: source.call,
        directionLeft: false,
        background: background,
        showGroundShadow: false,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/character_catalog.dart';
import '../engine/puppet.dart';
import '../engine/rig2d.dart';
import '../puppet_controller.dart';

/// Live 2D puppet stage: owns the ticker, drives [PuppetController.tick] and
/// repaints via the painter's `repaint` listenable. Tickers auto-mute when
/// off-screen (no wasted frames, no leaks).
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
          resolver: c.resolver,
          accessories: c.accessories,
          frameGetter: () => c.frame,
          directionLeft: c.directionLeft,
          background: widget.background,
          showGroundShadow: widget.showShadow,
          designSpace: Size(c.spec.designWidth, 340),
          repaint: c,
        ),
      ),
    );
  }
}

/// Static thumbnail rendered straight from the vector rig.
class PuppetThumbnail extends StatelessWidget {
  const PuppetThumbnail({super.key, required this.spec, required this.resolver, this.accessories = const {}, this.background});

  final Character2DSpec spec;
  final dynamic resolver;
  final Set<String> accessories;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final source = StaticFrameSource(Rig2D.byKind(spec.rigKind));
    return CustomPaint(
      size: Size.infinite,
      painter: PuppetPainter(
        spec: spec,
        resolver: resolver as dynamic,
        accessories: accessories,
        frameGetter: source.call,
        directionLeft: false,
        background: background,
        showGroundShadow: false,
        designSpace: Size(spec.designWidth, 340),
      ),
    );
  }
}

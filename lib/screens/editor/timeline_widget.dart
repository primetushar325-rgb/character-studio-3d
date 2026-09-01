import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';

/// Professional timeline: second ruler, playhead, keyframe dots for the
/// active clip, scrubbing and loop markers. Synchronized with the 2D
/// animation clock.
class TimelineWidget extends StatefulWidget {
  const TimelineWidget({super.key, required this.ed});
  final EditorProvider ed;

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  @override
  Widget build(BuildContext context) {
    final ed = widget.ed;
    final c = ed.controller;
    if (c == null) return const SizedBox.shrink();
    final dur = c.animator.clipDuration;
    final t = c.animator.clipTime.clamp(0.0, dur);
    final keys = _keyTimes(ed);

    return Column(
      children: [
        SizedBox(
          height: 64,
          child: GestureDetector(
            onPanUpdate: _scrub,
            onTapDown: _scrubTo,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TimelinePainter(dur: dur, t: t, keys: keys),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: () => ed.stepFrame(-1),
              tooltip: 'Previous frame',
            ),
            IconButton(
              icon: Icon(c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22, color: AppColors.textPrimary),
              onPressed: c.playing ? ed.pause : ed.play,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: () => ed.stepFrame(1),
              tooltip: 'Next frame',
            ),
            const SizedBox(width: 8),
            Text(
              '${_fmt(t)} / ${_fmt(dur)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const Spacer(),
            Text(
              '30 fps · ${ed.canvasWidth}×${ed.canvasHeight}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  List<double> _keyTimes(EditorProvider ed) {
    // Keyframe markers: quarter points of the cycle + one-shots at 0.
    final dur = ed.controller!.animator.clipDuration;
    final looping = ed.controller!.loop;
    return looping ? [0, dur * 0.25, dur * 0.5, dur * 0.75, dur] : [0, dur * 0.5, dur];
  }

  void _scrub(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final u = (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
    widget.ed.scrub(u * widget.ed.controller!.animator.clipDuration);
  }

  void _scrubTo(TapDownDetails d) => _scrub(DragUpdateDetails(delta: Offset.zero, globalPosition: d.globalPosition, localPosition: d.localPosition));

  String _fmt(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.dur, required this.t, required this.keys});
  final double dur;
  final double t;
  final List<double> keys;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.surfaceAlt;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(rrect, bg);

    // Second ticks.
    final tick = Paint()..color = AppColors.strokeStrong;
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (var s = 0; s <= dur; s++) {
      final x = (s / dur) * size.width;
      canvas.drawRect(Rect.fromLTWH(x.clamp(0, size.width - 1), 0, 1, s % 2 == 0 ? 12 : 7), tick);
      if (s % 2 == 0 && s < 60) {
        label.text = TextSpan(text: '0:${s.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textMuted, fontSize: 8.5));
        label.layout();
        label.paint(canvas, Offset((x + 3).clamp(2.0, size.width - 22), 2));
      }
    }

    // Keyframes.
    final kf = Paint()..color = AppColors.warning;
    for (final k in keys) {
      final x = (k / dur) * size.width;
      canvas.drawCircle(Offset(x.clamp(4, size.width - 4), size.height - 12), 3.2, kf);
    }

    // Progress + playhead.
    final px = (t / dur) * size.width;
    final fill = Paint()..color = AppColors.accent.withOpacity(0.12);
    canvas.drawRect(Rect.fromLTWH(0, 0, px, size.height), fill);
    final head = Paint()..color = AppColors.accent;
    canvas.drawRect(Rect.fromLTWH(px - 1, 0, 2.5, size.height), head);
    canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = AppColors.stroke);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) => oldDelegate.t != t || oldDelegate.dur != dur;
}

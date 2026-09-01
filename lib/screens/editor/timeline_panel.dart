import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../characters2d/puppet_controller.dart';
import '../../scene/scene_object.dart';
import '../../state/editor_provider.dart';
import '../../timeline/playback_clock.dart';
import '../../timeline/story_timeline.dart';

/// PHASE 3 — the story timeline: ruler, playhead, per-object tracks with
/// animation clips + keyframes + visibility ranges, playback controls, zoom,
/// snap, AUTO KEY and timeline undo/redo. Pure UI — all behavior lives in the
/// data model + evaluator (spec §1: "Do NOT hard-code timeline behavior into
/// widgets").
class TimelinePanel extends StatefulWidget {
  const TimelinePanel({super.key, required this.ed});
  final EditorProvider ed;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  static const List<double> _zoomLevels = [0.25, 0.5, 1, 2];
  double _zoom = 1; // 100% = 44 px per second
  bool _collapsed = false;
  bool _draggingClip = false; // suppress playhead-seek while editing clips

  EditorProvider get ed => widget.ed;

  double get pxPerMs => 0.044 * _zoom; // 44 px/s at 100%
  double msToX(int ms) => ms * pxPerMs;
  int xToMs(double x) => (x / pxPerMs).round();

  static const Duration _fade = Duration(milliseconds: 160);
  static const Color _bg = Color(0xFF10131C);
  static const Color _bg2 = Color(0xFF171B27);
  static const Color _line = Color(0xFF252A3A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: const Border(top: BorderSide(color: _line, width: 1)),
      ),
      child: AnimatedSize(
        duration: _fade,
        alignment: Alignment.bottomCenter,
        child: _collapsed
            ? _header(expanded: false)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                _header(expanded: true),
                SizedBox(
                  height: 240,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([ed, ed.clock]),
                    builder: (_, __) => _tracksArea(),
                  ),
                ),
              ]),
      ),
    );
  }

  // ---------------------------------------------------------------- controls
  Widget _header({required bool expanded}) {
    final clock = ed.clock;
    return Container(
      height: 46,
      color: _bg2,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.first_page, size: 20, color: Colors.white70),
          onPressed: () => clock.seek(0),
          tooltip: 'To start',
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            clock.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 24,
            color: const Color(0xFF6CF2C4),
          ),
          onPressed: () =>
              clock.isPlaying ? clock.pause() : clock.play(),
          tooltip: 'Play / pause',
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.last_page, size: 20, color: Colors.white70),
          onPressed: () => clock.seek(clock.durationMs),
          tooltip: 'To end',
        ),
        Expanded(
          child: Text(
            '${_fmt(clock.currentTimeMs)} / ${_fmt(clock.durationMs)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontFeatures: []),
          ),
        ),
        _speedMenu(clock),
        const SizedBox(width: 4),
        _durationMenu(),
        const SizedBox(width: 4),
        FilterChip(
          visualDensity: VisualDensity.compact,
          selected: ed.autoKey,
          onSelected: (v) => setState(() => ed.autoKey = v),
          label: Text('AUTO KEY',
              style: TextStyle(
                  fontSize: 9,
                  color: ed.autoKey ? Colors.black : Colors.white70)),
          backgroundColor: _bg,
          selectedColor: const Color(0xFFFFD166),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 2),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.undo, size: 16, color: Colors.white70),
          onPressed: ed.canUndo ? ed.undoTimelineEdit : null,
          tooltip: 'Undo',
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.redo, size: 16, color: Colors.white70),
          onPressed: ed.canRedo ? ed.redoTimelineEdit : null,
          tooltip: 'Redo',
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(expanded ? Icons.keyboard_double_arrow_down : Icons.keyboard_double_arrow_up,
              size: 16, color: Colors.white54),
          onPressed: () => setState(() => _collapsed = !_collapsed),
          tooltip: expanded ? 'Collapse timeline' : 'Expand timeline',
        ),
      ]),
    );
  }

  Widget _speedMenu(PlaybackClock clock) {
    return PopupMenuButton<double>(
      initialValue: clock.speed,
      color: _bg2,
      tooltip: 'Playback speed',
      onSelected: clock.setSpeed,
      itemBuilder: (_) => [
        for (final s in PlaybackClock.supportedSpeeds)
          PopupMenuItem(
              value: s,
              child: Text('${s}x',
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(8)),
        child: Text('${clock.speed}x',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ),
    );
  }

  Widget _durationMenu() {
    return PopupMenuButton<int>(
      color: _bg2,
      tooltip: 'Scene duration',
      onSelected: (v) => ed.setDurationMs(v),
      itemBuilder: (_) => [
        for (final s in const [10000, 15000, 20000, 30000, 60000])
          PopupMenuItem(
              value: s,
              child: Text('${s ~/ 1000}s',
                  style: const TextStyle(color: Colors.white, fontSize: 12))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(8)),
        child: Text('${ed.durationMs ~/ 1000}s',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ),
    );
  }

  // ------------------------------------------------------------------ tracks
  Widget _tracksArea() {
    final rows = <_RowSpec>[
      _RowSpec.background(),
      for (final o in [...ed.objects]..sort((a, b) => b.zIndex.compareTo(a.zIndex)))
        _RowSpec.object(o),
    ];
    final contentWidth = msToX(ed.durationMs) + 60;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: SizedBox(
              width: contentWidth,
              child: Column(children: [
                _ruler(),
                for (final r in rows) _row(r),
              ]),
            ),
          ),
        ),
      ),
      _zoomRow(),
    ]);
  }

  Widget _zoomRow() {
    return Container(
      height: 30,
      decoration: const BoxDecoration(
          color: _bg2, border: Border(top: BorderSide(color: _line))),
      child: Row(children: [
        const SizedBox(width: 8),
        const Icon(Icons.zoom_in, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        for (final z in _zoomLevels)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text('${(z * 100).round()}%',
                  style: TextStyle(
                      fontSize: 10,
                      color: _zoom == z ? Colors.black : Colors.white70)),
              selected: _zoom == z,
              onSelected: (_) => setState(() => _zoom = z),
              selectedColor: const Color(0xFF6CF2C4),
              backgroundColor: _bg,
            ),
          ),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.repeat,
              size: 16,
              color: ed.clock.loop ? const Color(0xFF6CF2C4) : Colors.white38),
          onPressed: () => setState(() => ed.clock.loop = !ed.clock.loop),
          tooltip: 'Loop playback',
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  // ---- ruler + playhead ----------------------------------------------------
  Widget _ruler() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _draggingClip
          ? null
          : (d) => ed.clock.seek(
              ed.clock.currentTimeMs + xToMs(d.delta.dx).clamp(-4000, 4000)),
      onTapDown: (d) => ed.clock.seek(xToMs(d.localPosition.dx)),
      child: SizedBox(
        height: 22,
        child: CustomPaint(
          painter: _RulerPainter(ed, pxPerMs),
          size: Size(msToX(ed.durationMs) + 60, 22),
        ),
      ),
    );
  }

  // ---- one track row --------------------------------------------------------
  Widget _row(_RowSpec r) {
    final track = ed.timeline.trackOf(r.id);
    final rowHeight = r.isCharacter ? 54.0 : 34.0;
    final width = msToX(ed.durationMs) + 60;
    final hasContent = track != null &&
        (track.clips.isNotEmpty ||
            track.keyframes.isNotEmpty ||
            track.visClips.isNotEmpty);

    return SizedBox(
      height: rowHeight,
      width: width,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 86,
          child: GestureDetector(
            onTap: () => _rowMenu(r),
            child: Container(
              decoration: const BoxDecoration(
                  color: _bg2,
                  border: Border(bottom: BorderSide(color: _line))),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.centerLeft,
              child: Row(children: [
                Icon(r.icon,
                    size: 12,
                    color: hasContent
                        ? const Color(0xFF6CF2C4)
                        : Colors.white38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: Stack(children: [
            Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(
                        painter: _PlayheadPainter(ed, pxPerMs),
                        size: Size.infinite))),
            Positioned.fill(child: _visLane(r, track)),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (r.isCharacter)
                SizedBox(width: double.infinity, child: _clipsLane(r, track)),
              SizedBox(width: double.infinity, child: _kfLane(r, track)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _clipsLane(_RowSpec r, TimelineTrack? track) {
    final clips = track?.clips ?? const <AnimClip>[];
    return SizedBox(
      height: 26,
      child: Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _rowMenu(r),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
                color: _bg,
                border: Border(
                    top: BorderSide(color: _line),
                    bottom: BorderSide(color: _line))),
          ),
        ),
        for (final c in clips)
          Positioned(
            left: msToX(c.startMs),
            width: (c.durationMs * pxPerMs).clamp(12, double.infinity),
            top: 1,
            bottom: 1,
            child: _clipWidget(r.id, c),
          ),
      ]),
    );
  }

  Widget _clipWidget(String objectId, AnimClip c) {
    final color = clipColor(c.animId);
    return LayoutBuilder(builder: (_, b) {
      final showHandles = b.maxWidth > 34;
      return GestureDetector(
        onTap: () => _clipSheet(objectId, c),
        onLongPress: () => ed.duplicateAnimClip(objectId, c.id),
        onHorizontalDragStart: (_) {
          ed.beginTimelineEdit();
          setState(() => _draggingClip = true);
        },
        onHorizontalDragUpdate: (d) {
          setState(() {
            final dm = xToMs(d.delta.dx);
            c.startMs = (c.startMs + dm).clamp(0, ed.durationMs - 50);
            c.endMs = (c.endMs + dm).clamp(c.startMs + 50, ed.durationMs);
          });
          _snapClip(c);
          ed.timeline.trackOf(objectId)?.sortAll();
          ed.refreshRuntime();
        },
        onHorizontalDragEnd: (_) {
          _snapClip(c);
          ed.timeline.trackOf(objectId)?.sortAll();
          ed.refreshRuntime();
          setState(() => _draggingClip = false);
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(.85),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white.withOpacity(.15)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(children: [
            if (showHandles) _edgeHandle(objectId, c, left: true),
            Expanded(
              child: Text(
                '${c.animId.toUpperCase()}${c.loop ? ' ↻' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
            ),
            if (showHandles) _edgeHandle(objectId, c, left: false),
          ]),
        ),
      );
    });
  }

  Widget _edgeHandle(String objectId, AnimClip c, {required bool left}) {
    return GestureDetector(
      onHorizontalDragStart: (_) {
        ed.beginTimelineEdit();
        setState(() => _draggingClip = true);
      },
      onHorizontalDragUpdate: (d) {
        setState(() {
          final dm = xToMs(d.delta.dx);
          if (left) {
            c.startMs = (c.startMs + dm).clamp(0, c.endMs - 50);
          } else {
            c.endMs = (c.endMs + dm).clamp(c.startMs + 50, ed.durationMs);
          }
        });
        ed.refreshRuntime();
      },
      onHorizontalDragEnd: (_) {
        _snapClip(c);
        ed.refreshRuntime();
        setState(() => _draggingClip = false);
      },
      child: Container(width: 10, color: Colors.black26),
    );
  }

  void _snapClip(AnimClip c) {
    final snappedStart = snapMs(c.startMs,
        timeline: ed.timeline,
        thresholdMs: (12 / pxPerMs).round(),
        exceptIds: {c.id});
    final snappedEnd = snapMs(c.endMs,
        timeline: ed.timeline,
        thresholdMs: (12 / pxPerMs).round(),
        exceptIds: {c.id});
    if (snappedEnd > snappedStart + 50) {
      c.startMs = snappedStart;
      c.endMs = snappedEnd;
    }
  }

  Widget _kfLane(_RowSpec r, TimelineTrack? track) {
    final kfs = track?.keyframes ?? const <TransformKeyframe>[];
    return SizedBox(
      height: 26,
      child: Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _rowMenu(r),
          child: Container(width: double.infinity, height: double.infinity, color: _bg2),
        ),
        for (final k in kfs)
          Positioned(
            left: (msToX(k.timeMs) - 6).clamp(0, double.infinity),
            child: _kfWidget(r.id, k),
          ),
      ]),
    );
  }

  Widget _kfWidget(String objectId, TransformKeyframe k) {
    return GestureDetector(
      onTap: () => _kfSheet(objectId, k),
      onHorizontalDragStart: (_) {
        ed.beginTimelineEdit();
        setState(() => _draggingClip = true);
      },
      onHorizontalDragUpdate: (d) {
        k.timeMs = (k.timeMs + xToMs(d.delta.dx)).clamp(0, ed.durationMs);
        ed.timeline.trackOf(objectId)?.sortAll();
        ed.refreshRuntime();
      },
      onHorizontalDragEnd: (_) {
        k.timeMs = snapMs(k.timeMs,
            timeline: ed.timeline,
            thresholdMs: (10 / pxPerMs).round(),
            exceptIds: {k.id});
        ed.timeline.trackOf(objectId)?.sortAll();
        ed.refreshRuntime();
        setState(() => _draggingClip = false);
      },
      child: Container(
        width: 12,
        height: 26,
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD166),
              border: Border.all(color: Colors.white.withOpacity(.5), width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _visLane(_RowSpec r, TimelineTrack? track) {
    final vis = track?.visClips ?? const <VisibilityClip>[];
    return IgnorePointer(
      child: Stack(children: [
        for (final v in vis)
          Positioned(
            left: msToX(v.startMs),
            width: (v.durationMs * pxPerMs).clamp(4, double.infinity),
            top: r.isCharacter ? 28.0 : 4.0,
            bottom: 2,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4DA3FF).withOpacity(.18),
                border:
                    Border.all(color: const Color(0xFF4DA3FF).withOpacity(.5)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------------ sheets
  void _rowMenu(_RowSpec r) {
    final track = ed.timeline.trackOf(r.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg2,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(r.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          if (r.isCharacter)
            ListTile(
              leading: const Icon(Icons.movie, color: Color(0xFF6CF2C4), size: 20),
              title: const Text('Add animation clip at playhead',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                _chooseAnim(r);
              },
            ),
          ListTile(
            leading: const Icon(Icons.diamond, color: Color(0xFFFFD166), size: 20),
            title: Text(
                'Add keyframe at playhead (${_fmt(ed.playheadMs)})',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            onTap: () {
              Navigator.pop(ctx);
              ed.upsertKeyframe(r.id, atMs: ed.playheadMs);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility, color: Color(0xFF4DA3FF), size: 20),
            title: const Text('Visibility range…',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            onTap: () {
              Navigator.pop(ctx);
              _visSheet(r, track);
            },
          ),
          if (track != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              title: const Text('Clear track',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                ed.clearTrack(r.id);
              },
            ),
        ]),
      ),
    );
  }

  void _chooseAnim(_RowSpec r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg2,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Animation clip',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            for (final a in PuppetController.actionOrder)
              ListTile(
                dense: true,
                leading: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: clipColor(a), shape: BoxShape.circle)),
                title: Text(a,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  final start = ed.playheadMs;
                  final dur =
                      (PuppetController.cycleLengthSeconds(a) * 1000).round();
                  ed.addAnimClip(r.id, a,
                      startMs: start,
                      endMs: (start + dur).clamp(start + 200, ed.durationMs));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _clipSheet(String objectId, AnimClip c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg2,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: clipColor(c.animId), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('${c.animId.toUpperCase()}  ${_fmt(c.startMs)} – ${_fmt(c.endMs)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text('local duration ${(c.durationMs / 1000).toStringAsFixed(2)}s',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              SwitchListTile(
                value: c.loop,
                activeColor: const Color(0xFF6CF2C4),
                title: const Text('Loop animation inside clip',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                onChanged: (v) {
                  setSheet(() => c.loop = v);
                  ed.refreshRuntime();
                },
              ),
              Row(children: [
                const Text('Speed', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                DropdownButton<double>(
                  dropdownColor: _bg2,
                  value: c.speed.clamp(0.25, 2.0),
                  items: [
                    for (final s in const [0.25, 0.5, 1.0, 1.5, 2.0])
                      DropdownMenuItem(value: s, child: Text('${s}x', style: const TextStyle(color: Colors.white70, fontSize: 12)))
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setSheet(() => c.speed = v);
                    ed.refreshRuntime();
                  },
                ),
              ]),
              _blendRow('Blend in', c.blendInMs,
                  (v) { setSheet(() => c.blendInMs = v); ed.refreshRuntime(); }),
              _blendRow('Blend out', c.blendOutMs,
                  (v) { setSheet(() => c.blendOutMs = v); ed.refreshRuntime(); }),
              Row(children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFF6CF2C4)),
                    label: const Text('Duplicate',
                        style: TextStyle(color: Color(0xFF6CF2C4), fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ed.duplicateAnimClip(objectId, c.id);
                    },
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ed.deleteAnimClip(objectId, c.id);
                    },
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _blendRow(String label, int value, void Function(int) onChange) {
    return Row(children: [
      SizedBox(
          width: 92,
          child: Text('$label  ${value}ms',
              style: const TextStyle(color: Colors.white70, fontSize: 12))),
      Expanded(
        child: Slider(
          value: value.clamp(0, 600).toDouble(),
          max: 600,
          divisions: 12,
          activeColor: const Color(0xFF6CF2C4),
          onChanged: (v) => onChange(v.round()),
        ),
      ),
    ]);
  }

  void _kfSheet(String objectId, TransformKeyframe k) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg2,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Keyframe @ ${_fmt(k.timeMs)}',
                    style: const TextStyle(
                        color: Color(0xFFFFD166), fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'props: ${k.props.entries.map((e) => '${e.key}=${e.value.toStringAsFixed(2)}').join(', ')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Color(0xFF6CF2C4), size: 20),
                title: const Text('Move playhead here',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  ed.clock.seek(k.timeMs);
                },
              ),
              ListTile(
                leading: const Icon(Icons.linear_scale, color: Colors.white38, size: 20),
                title: const Text('Easing',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                trailing: DropdownButton<KfEase>(
                  dropdownColor: _bg2,
                  value: k.ease,
                  items: [
                    for (final e in KfEase.values)
                      DropdownMenuItem(value: e, child: Text(e.label, style: const TextStyle(color: Colors.white70, fontSize: 12)))
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    k.ease = v;
                    ed.refreshRuntime();
                    Navigator.pop(ctx);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                title: const Text('Delete keyframe',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  ed.deleteKeyframe(objectId, k.id);
                },
              ),
            ]),
      ),
    );
  }

  void _visSheet(_RowSpec r, TimelineTrack? track) {
    final v = track?.visClips.isNotEmpty == true
        ? track!.visClips.first
        : null;
    final startCtrl = TextEditingController(
        text: ((v?.startMs ?? 0) / 1000).toStringAsFixed(1));
    final endCtrl = TextEditingController(
        text: ((v?.endMs ?? ed.durationMs) / 1000).toStringAsFixed(1));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg2,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 14, right: 14, top: 14,
            bottom: 14 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Visible from… to (seconds)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: startCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                    labelText: 'from (s)',
                    labelStyle: TextStyle(color: Colors.white38)),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: endCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(
                    labelText: 'to (s)',
                    labelStyle: TextStyle(color: Colors.white38)),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextButton(
                child: const Text('Always visible',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(ctx);
                  ed.setVisibilityClips(r.id, const []);
                },
              ),
            ),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6CF2C4)),
                child: const Text('Apply',
                    style: TextStyle(color: Colors.black87, fontSize: 13)),
                onPressed: () {
                  final s = (double.tryParse(startCtrl.text) ?? 0) * 1000;
                  final e = (double.tryParse(endCtrl.text) ?? 20) * 1000;
                  Navigator.pop(ctx);
                  if (e > s) {
                    ed.setVisibilityClips(r.id,
                        [VisibilityClip(startMs: s.round(), endMs: e.round().clamp(s.round() + 100, ed.durationMs))]);
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

class _RowSpec {
  _RowSpec.object(SceneObject o)
      : id = o.id,
        name = o.name,
        isCharacter = o.isCharacter,
        icon = switch (o.type) {
          SceneObjectType.character => Icons.person,
          SceneObjectType.image => Icons.image,
          SceneObjectType.text => Icons.text_fields,
          SceneObjectType.shape => Icons.category,
        };
  _RowSpec.background()
      : id = kBackgroundTrackId,
        name = 'Background',
        isCharacter = false,
        icon = Icons.landscape;
  final String id;
  final String name;
  final bool isCharacter;
  final IconData icon;
}

String _fmt(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) / 1000.0;
  return '${m.toString().padLeft(2, '0')}:${s.toStringAsFixed(2).padLeft(5, '0')}';
}

/// Stable color per animation id.
Color clipColor(String animId) {
  const palette = [
    Color(0xFF6CF2C4), Color(0xFFFFD166), Color(0xFF4DA3FF),
    Color(0xFFFF8FA3), Color(0xFFB28DFF), Color(0xFF7CE7FF),
    Color(0xFFA8E6CF), Color(0xFFFFB37C), Color(0xFFF9A1BC),
    Color(0xFFC5E17A), Color(0xFF9AA5FF), Color(0xFFFFD3B6),
    Color(0xFF89E0D8), Color(0xFFE4B1FF),
  ];
  var h = 0;
  for (final c in animId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

// ---------------------------------------------------------------- painters

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.ed, this.pxPerMs);
  final EditorProvider ed;
  final double pxPerMs;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0C0F17);
    canvas.drawRect(Offset.zero & size, bg);
    // adaptive tick step: aim ≥ 52 px between second labels
    final pxPerSec = pxPerMs * 1000;
    final step = pxPerSec >= 104
        ? 1
        : pxPerSec >= 42
            ? 5
            : pxPerSec >= 18
                ? 10
                : 30;
    final totalSec = ed.durationMs / 1000;
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (var s = 0.0; s <= totalSec; s += step) {
      final x = s * pxPerSec;
      final major = s % (step * 5) == 0 || step >= 5;
      final p = Paint()
        ..color = major ? Colors.white38 : Colors.white12
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, major ? 22 : 8), p);
      if (major) {
        label.text = TextSpan(
            text: '${s.toInt()}s',
            style: const TextStyle(color: Colors.white54, fontSize: 8));
        label.layout();
        label.paint(canvas, Offset(x + 2, 8));
      }
    }
    final endP = Paint()..color = Colors.white24;
    canvas.drawLine(Offset(msToX_(ed.durationMs), 0),
        Offset(msToX_(ed.durationMs), 22), endP);
  }

  double msToX_(int ms) => ms * pxPerMs;

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.ed != ed || old.pxPerMs != pxPerMs || old.ed.playheadMs != ed.playheadMs;
}

class _PlayheadPainter extends CustomPainter {
  _PlayheadPainter(this.ed, this.pxPerMs);
  final EditorProvider ed;
  final double pxPerMs;

  @override
  void paint(Canvas canvas, Size size) {
    final x = ed.playheadMs * pxPerMs;
    final p = Paint()
      ..color = const Color(0xFFFF5D5D)
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    final head = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x, 7)
      ..close();
    canvas.drawPath(head, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _PlayheadPainter old) =>
      old.ed.playheadMs != ed.playheadMs || old.pxPerMs != pxPerMs;
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/audio_clip.dart';
import '../../state/editor_provider.dart';
import '../../state/projects_provider.dart';
import 'background_picker.dart' show copyIntoProjectAssets;

/// PHASE 4 — audio import (spec §3/§4): pick a file with the system picker,
/// COPY it into `<project>/assets/audio/`, probe its duration and add an
/// AudioClip at the playhead. Unknown formats fail with a friendly error —
/// never a crash.
Future<void> pickAudioClip(BuildContext context, AudioSourceType type) async {
  final ed = context.read<EditorProvider>();
  final projects = context.read<ProjectsProvider>();

  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.audio, // mp3 / wav / m4a / aac / ogg … (handler decides)
    );
    final path = res?.files.single.path;
    if (path == null) return;

    final supported = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.flac'];
    final ext = path.contains('.')
        ? '.${path.split('.').last.toLowerCase()}'
        : '';
    if (ext.isNotEmpty && !supported.contains(ext)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Audio format "$ext" is not supported. Use MP3, WAV, M4A or AAC.')));
      }
      return;
    }

    // Copy into the project so it survives source moves/deletes (spec §4).
    final (abs, rel) = await copyIntoProjectAssets(projects, path, 'audio');
    final sourceDur = await ed.audio.probeDurationMs(abs);
    if (sourceDur <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not read this audio file on this device. Try MP3, WAV or M4A.')));
      }
      return;
    }

    final start = ed.playheadMs;
    final dur = sourceDur.clamp(50, ed.durationMs - start > 50 ? ed.durationMs - start : sourceDur);
    final base = path.split('/').last;
    ed.addAudioClip(
      name: base.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      relPath: rel,
      sourceType: type,
      startMs: start,
      durationMs: dur,
      sourceDurationMs: sourceDur,
    );
  } catch (e) {
    // Any picker/IO failure → friendly message, no crash (spec §3).
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Audio import failed: $e')));
    }
  }
}

/// Re-links a missing audio clip (spec §16): pick a new file, copy it into
/// the project, keep the clip's timing.
Future<void> relocateAudioClip(BuildContext context, AudioClip clip) async {
  final ed = context.read<EditorProvider>();
  final projects = context.read<ProjectsProvider>();
  try {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = res?.files.single.path;
    if (path == null) return;
    final (abs, rel) = await copyIntoProjectAssets(projects, path, 'audio');
    final dur = await ed.audio.probeDurationMs(abs);
    ed.relinkAudioClip(clip.id, rel, dur > 0 ? dur : clip.sourceDurationMs);
  } catch (_) {}
}

/// Audio clip property sheet (spec §14): play, trim, volume, mute, fades,
/// loop, duplicate, delete. Bottom sheet — never crowds the editor.
Future<void> showAudioClipSheet(BuildContext context, AudioClip clip) async {
  final ed = context.read<EditorProvider>();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF171B27),
    isScrollControlled: true,
    builder: (ctx) => _AudioClipSheet(ed: ed, clip: clip),
  );
}

class _AudioClipSheet extends StatefulWidget {
  const _AudioClipSheet({required this.ed, required this.clip});
  final EditorProvider ed;
  final AudioClip clip;

  @override
  State<_AudioClipSheet> createState() => _AudioClipSheetState();
}

class _AudioClipSheetState extends State<_AudioClipSheet> {
  late AudioClip c = widget.clip;

  void edit(void Function(AudioClip) fn) =>
      widget.ed.updateAudioClip(c.id, fn, undoable: false);

  @override
  Widget build(BuildContext context) {
    final c = this.c;
    final srcLen =
        (c.sourceDurationMs - c.sourceStartMs).clamp(1, 1 << 30) / 1000.0;
    final trimStartS = (c.sourceStartMs / 1000).toStringAsFixed(2);
    final trimDurS = (c.durationMs / 1000).toStringAsFixed(2);
    return Padding(
      padding: EdgeInsets.only(
          left: 14, right: 14, top: 12,
          bottom: 14 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_typeIcon(c.sourceType),
                  size: 16, color: _typeColor(c.sourceType)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${c.name}  ·  ${c.sourceType.label}\n'
                    'timeline ${(c.startMs / 1000).toStringAsFixed(2)}s → ${(c.endMs / 1000).toStringAsFixed(2)}s',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              if (c.missing)
                const Text('FILE UNAVAILABLE',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10)),
            ]),
            const SizedBox(height: 4),
            Text('source length ${srcLen.toStringAsFixed(2)}s',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (c.missing) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Locate File',
                          style: TextStyle(fontSize: 13)),
                      onPressed: () async {
                        Navigator.pop(context);
                        await relocateAudioClip(context, c);
                      }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.redAccent),
                      label: const Text('Remove Clip',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 13)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.ed.deleteAudioClip(c.id);
                      }),
                ),
              ]),
            ],
            _slider('Volume  ${(c.volume * 100).round()}%',
                c.volume / 1.5, (v) => edit((k) => k.volume = v * 1.5)),
            SwitchListTile(
              dense: true,
              activeColor: const Color(0xFF6CF2C4),
              title: const Text('Mute (preview + export)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: c.muted,
              onChanged: (v) => setState(() => edit((k) => k.muted = v)),
            ),
            SwitchListTile(
              dense: true,
              activeColor: const Color(0xFF6CF2C4),
              title: const Text('Loop source to fill clip',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: c.loop,
              onChanged: (v) => setState(() => edit((k) => k.loop = v)),
            ),
            _msSlider('Fade in', c.fadeInMs,
                (v) => setState(() => edit((k) => k.fadeInMs = v))),
            _msSlider('Fade out', c.fadeOutMs,
                (v) => setState(() => edit((k) => k.fadeOutMs = v))),
            _trimRow(trimStartS, trimDurS),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextButton.icon(
                    icon: const Icon(Icons.copy,
                        size: 16, color: Color(0xFF6CF2C4)),
                    label: const Text('Duplicate',
                        style:
                            TextStyle(color: Color(0xFF6CF2C4), fontSize: 13)),
                    onPressed: () {
                      final copy = widget.ed.duplicateAudioClip(c.id);
                      Navigator.pop(context);
                      if (copy != null) showAudioClipSheet(context, copy);
                    }),
              ),
              Expanded(
                child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.redAccent),
                    label: const Text('Delete',
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.ed.deleteAudioClip(c.id);
                    }),
              ),
            ]),
          ]),
    );
  }

  Widget _slider(String label, double value, void Function(double) onChanged) {
    return Row(children: [
      SizedBox(
          width: 120,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12))),
      Expanded(
        child: Slider(
          value: value.clamp(0, 1),
          activeColor: const Color(0xFF6CF2C4),
          onChanged: onChanged,
        ),
      ),
    ]);
  }

  Widget _msSlider(String label, int ms, void Function(int) onChanged) {
    return Row(children: [
      SizedBox(
          width: 120,
          child: Text('$label  ${ms}ms',
              style: const TextStyle(color: Colors.white70, fontSize: 12))),
      Expanded(
        child: Slider(
          value: ms.clamp(0, 5000).toDouble(),
          max: 5000,
          activeColor: const Color(0xFF6CF2C4),
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    ]);
  }

  Widget _trimRow(String startS, String durS) {
    return Row(children: [
      const Icon(Icons.content_cut, size: 14, color: Colors.white38),
      const SizedBox(width: 6),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Trim source (non-destructive)',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: startS,
                key: ValueKey('trim_start_${c.id}_$startS'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'src start (s)',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 11)),
                onFieldSubmitted: (v) => _applyTrim(v, durS),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: durS,
                key: ValueKey('trim_dur_${c.id}_$durS'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'length (s)',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 11)),
                onFieldSubmitted: (v) => _applyTrim(startS, v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check,
                  size: 18, color: Color(0xFF6CF2C4)),
              onPressed: () => _applyTrim(startS, durS),
            ),
          ]),
        ]),
      ),
    ]);
  }

  void _applyTrim(String startS, String durS) {
    final s = ((double.tryParse(startS) ?? 0) * 1000)
        .round()
        .clamp(0, c.sourceDurationMs > 0 ? c.sourceDurationMs - 50 : 1 << 30);
    final d = ((double.tryParse(durS) ?? c.durationMs / 1000) * 1000)
        .round()
        .clamp(50, widget.ed.durationMs - c.startMs > 50
            ? widget.ed.durationMs - c.startMs
            : 50);
    widget.ed.updateAudioClip(c.id, (k) {
      k.sourceStartMs = s;
      k.durationMs = d;
    });
    setState(() {});
  }
}

IconData _typeIcon(AudioSourceType t) => switch (t) {
      AudioSourceType.music => Icons.music_note,
      AudioSourceType.voice => Icons.record_voice_over,
      AudioSourceType.sfx => Icons.graphic_eq,
    };

Color _typeColor(AudioSourceType t) => switch (t) {
      AudioSourceType.music => const Color(0xFFB28DFF),
      AudioSourceType.voice => const Color(0xFF6CF2C4),
      AudioSourceType.sfx => const Color(0xFFFFB37C),
    };

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:character_studio_3d/audio/audio_clip.dart';
import 'package:character_studio_3d/audio/audio_export.dart';
import 'package:character_studio_3d/audio/audio_timeline.dart';
import 'package:character_studio_3d/characters2d/character2d_repository.dart';
import 'package:character_studio_3d/project/project_document.dart';
import 'package:character_studio_3d/state/editor_provider.dart';
import 'package:character_studio_3d/state/library2d_provider.dart';

/// Fake platform player — records seeks/volumes so preview sync (spec §29)
/// can be asserted without audio hardware.
class FakePlayer implements ClipPlayer {
  String? file;
  bool looping = false;
  bool playing = false;
  final List<int> seeks = [];
  int playCalls = 0;
  double vol = 1;

  @override
  Future<void> setFile(String absPath) async => file = absPath;
  @override
  Future<void> setLoop(bool loop) async => looping = loop;
  @override
  Future<void> playFrom(int ms, double volume) async {
    playing = true;
    seeks.add(ms);
    vol = volume;
    playCalls++;
  }
  @override
  Future<void> setVolume(double v) async => vol = v;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> resume() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<Duration?> probeDuration(String absPath) async =>
      const Duration(milliseconds: 30000);
  @override
  bool get isPlaying => playing;
  @override
  void dispose() {}
}

AudioClip music({
  int startMs = 0,
  int durationMs = 20000,
  int sourceStartMs = 0,
  int sourceDurationMs = 60000,
  double volume = 1,
  bool muted = false,
  int fadeInMs = 0,
  int fadeOutMs = 0,
  bool loop = false,
  String path = 'assets/audio/music.mp3',
}) =>
    AudioClip(
      id: 'a_music',
      name: 'Music',
      filePath: path,
      sourceType: AudioSourceType.music,
      startMs: startMs,
      durationMs: durationMs,
      sourceStartMs: sourceStartMs,
      sourceDurationMs: sourceDurationMs,
      volume: volume,
      muted: muted,
      fadeInMs: fadeInMs,
      fadeOutMs: fadeOutMs,
      loop: loop,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AudioClip serialization (§15/§27)', () {
    test('round-trips every field including loop', () {
      final c = AudioClip(
        id: 'aud_1',
        name: 'Theme',
        filePath: 'assets/audio/theme_123.mp3',
        sourceType: AudioSourceType.voice,
        startMs: 2000,
        durationMs: 5000,
        sourceStartMs: 1000,
        sourceDurationMs: 30000,
        volume: .8,
        muted: true,
        fadeInMs: 300,
        fadeOutMs: 700,
        loop: true,
      );
      final back =
          AudioClip.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.id, 'aud_1');
      expect(back.name, 'Theme');
      expect(back.filePath, 'assets/audio/theme_123.mp3');
      expect(back.sourceType, AudioSourceType.voice);
      expect(back.startMs, 2000);
      expect(back.durationMs, 5000);
      expect(back.sourceStartMs, 1000);
      expect(back.sourceDurationMs, 30000);
      expect(back.volume, .8);
      expect(back.muted, true);
      expect(back.fadeInMs, 300);
      expect(back.fadeOutMs, 700);
      expect(back.loop, true);
      expect(back.endMs, 7000);
    });

    test('legacy/missing fields get safe defaults (migration §2)', () {
      final back = AudioClip.fromJson({'id': 'x', 'filePath': 'a.mp3'});
      expect(back.sourceType, AudioSourceType.music);
      expect(back.volume, 1.0);
      expect(back.muted, false);
      expect(back.sourceStartMs, 0);
      expect(back.loop, false);
    });
  });

  group('Trim + source offset (§6/§30) — MANDATORY TRIM TEST', () {
    final c = music(
        startMs: 5000, durationMs: 8000, sourceStartMs: 10000,
        sourceDurationMs: 30000);

    test('timeline 5s → source 10s', () => expect(c.positionAt(5000), 10000));
    test('timeline 12.9s → source 17.9s',
        () => expect(c.positionAt(12900), 17900));
    test('timeline 13s → silent (clip ended)',
        () => expect(c.positionAt(13000), -1));
    test('before start → silent', () => expect(c.positionAt(4999), -1));
    test('trim is non-destructive on the source file (model only)',
        () => expect(c.sourceStartMs, 10000));
  });

  group('Loop (§21)', () {
    test('8s source looped over a 0–20s music clip', () {
      final c = music(durationMs: 20000, sourceDurationMs: 8000, loop: true);
      expect(c.positionAt(0), 0);
      expect(c.positionAt(10000), 2000); // 10 % 8
      expect(c.positionAt(19000), 3000); // 19 % 8
      expect(c.positionAt(20000), -1);
    });

    test('non-loop goes silent when the source runs out', () {
      final c = music(durationMs: 20000, sourceDurationMs: 8000, loop: false);
      expect(c.positionAt(7999), 7999);
      expect(c.positionAt(8000), -1);
    });
  });

  group('Volume / mute / fades (§7/§8/§9)', () {
    test('music 30% with 2s fades — the §28 acceptance numbers', () {
      final c = music(
          startMs: 0, durationMs: 20000, volume: .3,
          fadeInMs: 2000, fadeOutMs: 2000);
      expect(c.gainAt(0), closeTo(0, 1e-9));
      expect(c.gainAt(1000), closeTo(.15, 1e-9)); // half of fade-in
      expect(c.gainAt(2000), closeTo(.3, 1e-9));
      expect(c.gainAt(10000), closeTo(.3, 1e-9));
      expect(c.gainAt(19000), closeTo(.15, 1e-9)); // half of fade-out
      expect(c.gainAt(19999), closeTo(.3 / 2000, 0.001));
    });

    test('overlapping fade in+out multiplies', () {
      final c = music(durationMs: 4000, volume: 1, fadeInMs: 3000, fadeOutMs: 3000);
      // at 2000: fade-in factor 2/3, fade-out factor 2/3
      expect(c.gainAt(2000), closeTo(4 / 9, 1e-9));
    });

    test('muted → gain 0 everywhere, not audible', () {
      final c = music(muted: true);
      expect(c.gainAt(5000), 0);
      expect(c.audibleAt(5000), isFalse);
    });

    test('volume clamps to 150% (§7)', () {
      final c = music(volume: 5);
      expect(c.gainAt(5000), 1.5);
    });
  });

  group('Project duration bounds (§20)', () {
    test('clip starting after project end is excluded from export plan', () {
      final plan = planAudioMix([music(startMs: 25000, durationMs: 10000)],
          20000, '/proj',
          fileExists: (_) => true);
      expect(plan.hasAudio, isFalse);
    });

    test('clip extending past the end is kept; encode -t caps it', () {
      final plan = planAudioMix([music(startMs: 18000, durationMs: 10000)],
          20000, '/proj',
          fileExists: (_) => true);
      expect(plan.hasAudio, isTrue);
      expect(plan.totalMs, 20000);
    });
  });

  group('Multiple overlapping clips (§12/§17)', () {
    test('music + voice + sfx coexist at 6s', () {
      final clips = [
        music(startMs: 0, durationMs: 20000),
        AudioClip(
            id: 'v1', name: 'V1', filePath: 'a.mp3',
            sourceType: AudioSourceType.voice,
            startMs: 2000, durationMs: 5000, sourceDurationMs: 30000),
        AudioClip(
            id: 'sfx', name: 'S', filePath: 'a.mp3',
            sourceType: AudioSourceType.sfx,
            startMs: 5000, durationMs: 500, sourceDurationMs: 30000),
      ];
      expect(clips.every((c) => c.activeAt(5200)), isTrue); // music+voice+sfx window
      final plan = planAudioMix(clips, 20000, '/proj', fileExists: (_) => true);
      expect(plan.clips.length, 3);
      // deterministic order: sorted by start
      expect(plan.clips.map((c) => c.id).toList(), ['a_music', 'v1', 'sfx']);
    });
  });

  group('Export mix args (§18/§19) — MANDATORY EXPORT TEST', () {
    test('no audio → exactly the video-only pipeline (§24)', () {
      final args = buildExportArgs(
        framesPattern: '/f/frame_%04d.png',
        fps: 30,
        plan: AudioMixPlan(clips: [], totalMs: 20000),
        outPath: '/out.mp4',
        videoBitrate: '6M',
        projectDir: '/p',
      );
      expect(args.contains('-filter_complex'), isFalse);
      expect(args.contains('-c:a'), isFalse);
      expect(args.take(5).toList(),
          ['-y', '-framerate', '30', '-i', '/f/frame_%04d.png']);
      expect(args.contains('libx264'), isTrue);
      expect(args.contains('-t'), isTrue);
    });

    test('two clips: per-input trim + volume/fade/adelay + amix + aac', () {
      final c1 = music(
          startMs: 0, durationMs: 20000, volume: .3,
          fadeInMs: 2000, fadeOutMs: 2000, sourceDurationMs: 60000);
      final c2 = AudioClip(
          id: 'v', name: 'V', filePath: 'assets/audio/v.mp3',
          sourceType: AudioSourceType.voice,
          startMs: 2000, durationMs: 5000, sourceStartMs: 1000,
          sourceDurationMs: 30000);
      final args = buildExportArgs(
        framesPattern: '/f/frame_%04d.png',
        fps: 30,
        plan: AudioMixPlan(clips: [c1, c2], totalMs: 20000),
        outPath: '/out.mp4',
        videoBitrate: '6M',
        projectDir: '/p',
      );
      // two audio inputs after the frames input
      expect(args.where((a) => a == '-i').length, 3);
      // trim values present: c2 source start 1s / 5s length
      expect(args.contains('1.000'), isTrue);
      expect(args.contains('5.000'), isTrue);
      final fc = args[args.indexOf('-filter_complex') + 1];
      expect(fc.contains('volume=0.300'), isTrue);
      expect(fc.contains('afade=t=in:st=0:d=2.000'), isTrue);
      expect(fc.contains('afade=t=out:st=18.000:d=2.000'), isTrue);
      expect(fc.contains('adelay=delays=0ms:all=1'), isTrue);
      expect(fc.contains('adelay=delays=2000ms:all=1'), isTrue);
      expect(fc.contains('amix=inputs=2:normalize=0'), isTrue);
      expect(args.contains('[mix]'), isTrue);
      expect(args.contains('aac'), isTrue);
      // project duration bound
      expect(args.contains('20.000'), isTrue);
    });

    test('muted + missing clips never reach the encoder', () {
      final plan = planAudioMix([
        music(muted: true),
        music(path: 'assets/audio/gone.mp3', startMs: 1000)..missing = true,
      ], 20000, '/p', fileExists: (_) => true);
      expect(plan.hasAudio, isFalse);
    });

    test('short looped source uses -stream_loop (§21)', () {
      final args = buildExportArgs(
        framesPattern: '/f/frame_%04d.png',
        fps: 30,
        plan: AudioMixPlan(
            clips: [music(durationMs: 20000, sourceDurationMs: 8000, loop: true)],
            totalMs: 20000),
        outPath: '/out.mp4',
        videoBitrate: '6M',
        projectDir: '/p',
      );
      expect(args.contains('-stream_loop'), isTrue);
      expect(args.contains('-1'), isTrue);
    });
  });

  group('Preview sync (§10/§11/§29) — MANDATORY SEEK TEST', () {
    late AudioTimeline tl;
    late FakePlayer musicP;
    late FakePlayer voiceP;

    setUp(() {
      musicP = FakePlayer();
      voiceP = FakePlayer();
      var n = 0;
      tl = AudioTimeline(playerFactory: () => n++ == 0 ? musicP : voiceP)
        ..resolvePath = (rel) => '/proj/$rel';
      tl.clips.addAll([
        music(startMs: 0, durationMs: 20000, volume: .3),
        AudioClip(
            id: 'v1', name: 'V', filePath: 'assets/audio/v.mp3',
            sourceType: AudioSourceType.voice,
            startMs: 2000, durationMs: 5000, sourceDurationMs: 30000),
      ]);
    });

    test('play at 4s: music + voice both live at correct positions', () async {
      await tl.sync(4000, true);
      expect(musicP.playing, isTrue);
      expect(voiceP.playing, isTrue);
      expect(musicP.seeks.single, 4000);
      expect(voiceP.seeks.single, 2000); // 4s timeline → 2s into voice
      expect(voiceP.vol, closeTo(1, 1e-9));
    });

    test('seek 4s → 10s: voice stops (no stale audio), music repositions',
        () async {
      await tl.sync(4000, true);
      await tl.sync(10000, true);
      expect(voiceP.playing, isFalse); // 10s is outside 2–7s
      expect(musicP.playing, isTrue);
      expect(musicP.seeks.last, 10000); // re-seeked, no desync
      expect(musicP.playCalls, 2);
    });

    test('continuous ticks do not re-trigger playback (no duplicates)',
        () async {
      await tl.sync(4000, true);
      await tl.sync(4016, true); // one frame later
      await tl.sync(4033, true);
      expect(voiceP.playCalls, 1);
      expect(musicP.playCalls, 1);
    });

    test('pause silences everything; resume restarts correctly', () async {
      await tl.sync(4000, true);
      await tl.sync(4000, false);
      expect(musicP.playing, isFalse);
      expect(voiceP.playing, isFalse);
      await tl.sync(5000, true);
      expect(voiceP.playing, isTrue);
      expect(voiceP.seeks.last, 3000);
    });

    test('fade volume reaches the player live', () async {
      tl.clips.clear();
      tl.clips.add(music(volume: .3, fadeInMs: 2000, durationMs: 20000));
      final p = musicP;
      await tl.sync(1000, true);
      expect(p.vol, closeTo(.15, 1e-9));
      await tl.sync(1500, true);
      expect(p.vol, closeTo(.225, 1e-9));
    });
  });

  group('Missing file (§16)', () {
    test('vanished file is marked missing, never audible, never crashes',
        () async {
      final dir = await Directory.systemTemp.createTemp('aud');
      final f = File('${dir.path}/x.mp3');
      await f.writeAsString('x');
      final tl = AudioTimeline(playerFactory: FakePlayer.new)
        ..resolvePath = (rel) => '${dir.path}/x.mp3';
      final c = music(path: 'assets/audio/x.mp3');
      tl.clips.add(c);
      tl.refreshMissing();
      expect(c.missing, isFalse);
      await f.delete();
      tl.refreshMissing();
      expect(c.missing, isTrue);
      expect(c.audibleAt(5000), isFalse);
      // sync with a missing file is a no-op, not an exception
      await tl.sync(5000, true);
    });
  });

  group('Editor integration (§2/§26)', () {
    late EditorProvider ed;

    setUp(() {
      ed = EditorProvider(Library2DProvider(repo: Character2DRepository()));
    });

    test('add → undo → redo keeps id and path', () {
      final c = ed.addAudioClip(
          name: 'Theme',
          relPath: 'assets/audio/theme_1.mp3',
          sourceType: AudioSourceType.music,
          startMs: 0,
          durationMs: 20000,
          sourceDurationMs: 60000);
      expect(ed.audioClips.length, 1);
      ed.undoTimelineEdit();
      expect(ed.audioClips, isEmpty);
      ed.redoTimelineEdit();
      expect(ed.audioClips.single.id, c.id);
      expect(ed.audioClips.single.filePath, 'assets/audio/theme_1.mp3');
    });

    test('delete is reversible', () {
      final c = ed.addAudioClip(
          name: 'V', relPath: 'assets/audio/v.mp3',
          sourceType: AudioSourceType.voice);
      ed.deleteAudioClip(c.id);
      expect(ed.audioClips, isEmpty);
      ed.undoTimelineEdit();
      expect(ed.audioClips.single.id, c.id);
    });

    test('move/trim/mute ride the same undo stack', () {
      final c = ed.addAudioClip(
          name: 'M', relPath: 'assets/audio/m.mp3',
          sourceType: AudioSourceType.music);
      ed.updateAudioClip(c.id, (k) => k
        ..startMs = 9000
        ..muted = true);
      expect(ed.audioClips.single.startMs, 9000);
      ed.undoTimelineEdit();
      expect(ed.audioClips.single.startMs, 0);
      expect(ed.audioClips.single.muted, false);
    });

    test('addAudioClip clamps into the project duration', () {
      final c = ed.addAudioClip(
          name: 'X', relPath: 'a.mp3', sourceType: AudioSourceType.sfx,
          startMs: 19500, durationMs: 10000);
      expect(c.startMs, 19500);
      expect(c.durationMs, lessThanOrEqualTo(20000));
    });
  });

  group('Project persistence (§15/§31) — MANDATORY SAVE/RELOAD', () {
    test('audio clips survive capture → JSON → restore with every property',
        () {
      final ed = EditorProvider(Library2DProvider(repo: Character2DRepository()));
      final doc = ProjectDocument(
          id: 'p9', name: 'Aud', orientation: 'landscape',
          canvasWidth: 1920, canvasHeight: 1080);
      ed.addAudioClip(
          name: 'Theme', relPath: 'assets/audio/theme_1.mp3',
          sourceType: AudioSourceType.music,
          startMs: 0, durationMs: 20000, sourceDurationMs: 60000);
      final v = ed.addAudioClip(
          name: 'Vo', relPath: 'assets/audio/vo_2.wav',
          sourceType: AudioSourceType.voice,
          startMs: 2000, durationMs: 5000, sourceStartMs: 1000,
          sourceDurationMs: 30000);
      ed.updateAudioClip(v.id, (k) => k
        ..volume = .25
        ..fadeInMs = 2000
        ..fadeOutMs = 2000);

      captureEditorIntoProject(ed, doc);
      final json = jsonEncode(doc.toJson());
      final back = ProjectDocument.fromJson(
          jsonDecode(json) as Map<String, dynamic>);

      expect(back.audioClips.length, 2);
      final m = back.audioClips.first;
      expect(m['filePath'], 'assets/audio/theme_1.mp3');
      expect(m['sourceType'], 'music');
      final vv = back.audioClips.last;
      expect(vv['startMs'], 2000);
      expect(vv['durationMs'], 5000);
      expect(vv['sourceStartMs'], 1000);
      expect(vv['volume'], .25);
      expect(vv['fadeInMs'], 2000);
      expect(vv['fadeOutMs'], 2000);
    });

    test('P3 project without audioClips loads with empty list (migration §2)',
        () {
      final doc = ProjectDocument.fromJson({
        'id': 'p3', 'name': 'Old', 'orientation': 'landscape',
        'canvas': {'width': 1920, 'height': 1080},
        'timeline': {'durationMs': 20000, 'tracks': {}},
      });
      expect(doc.audioClips, isEmpty);
    });
  });
}

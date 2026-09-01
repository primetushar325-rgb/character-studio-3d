/// PHASE 4 — audio data model (spec §1): music / voice / sfx clips with trim,
/// volume, mute, fades and loop. Pure Dart — the SAME model drives preview
/// players AND the export mix, so their timing can never drift (spec §25).
library;

enum AudioSourceType { music, voice, sfx }

extension AudioSourceTypeX on AudioSourceType {
  String get json => name;
  static AudioSourceType fromJson(String? s) => AudioSourceType.values
      .firstWhere((e) => e.name == s, orElse: () => AudioSourceType.music);

  String get label => switch (this) {
        AudioSourceType.music => 'Music',
        AudioSourceType.voice => 'Voice',
        AudioSourceType.sfx => 'SFX',
      };
}

class AudioClip {
  AudioClip({
    required this.id,
    required this.name,
    required this.filePath, // project-relative, e.g. assets/audio/a_123.mp3
    required this.sourceType,
    required this.startMs,
    required this.durationMs,
    this.sourceStartMs = 0,
    this.sourceDurationMs = 0, // probed at import; 0 = unknown
    this.volume = 1.0, // 0..1.5
    this.muted = false,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.loop = false,
    this.missing = false, // resolved file not found (spec §16)
  }) : assert(durationMs > 0, 'audio clip duration must be > 0');

  String id;
  String name;
  String filePath;
  AudioSourceType sourceType;

  int startMs; // position on the story timeline
  int durationMs; // how long it plays on the timeline (trim = start+duration)
  int sourceStartMs; // offset into the source file (non-destructive trim)
  int sourceDurationMs; // total length of the source file

  double volume;
  bool muted;
  int fadeInMs;
  int fadeOutMs;
  bool loop;
  bool missing;

  int get endMs => startMs + durationMs;

  bool activeAt(int tMs) => startMs <= tMs && tMs < endMs;

  /// True while the clip should be audible at timeline time [tMs]
  /// (spec §11): inside the clip range, not muted, gain > 0.
  bool audibleAt(int tMs) => !missing && !muted && gainAt(tMs) > 0 && positionAt(tMs) >= 0;

  /// Source-file position for timeline time [tMs], or -1 when silent.
  ///
  /// trim:  position = sourceStart + (t - start)   (spec §30)
  /// loop:  wraps within [sourceStart, sourceEnd)  (spec §21)
  int positionAt(int tMs) {
    if (!activeAt(tMs)) return -1;
    final rel = tMs - startMs;
    final srcLen = sourceDurationMs - sourceStartMs;
    if (srcLen <= 0) return sourceStartMs + rel; // unknown probe → linear
    if (loop) return sourceStartMs + (rel % srcLen);
    if (rel >= srcLen) return -1; // source exhausted → silence
    return sourceStartMs + rel;
  }

  /// Gain 0..volume at timeline time [tMs]: volume × fade-in × fade-out
  /// (spec §9). The SAME calculation is used for preview and export.
  double gainAt(int tMs) {
    if (muted) return 0;
    var g = volume.clamp(0.0, 1.5);
    final rel = tMs - startMs;
    if (fadeInMs > 0 && rel < fadeInMs) {
      g *= (rel / fadeInMs).clamp(0.0, 1.0);
    }
    final toEnd = endMs - tMs;
    if (fadeOutMs > 0 && toEnd < fadeOutMs) {
      g *= (toEnd / fadeOutMs).clamp(0.0, 1.0);
    }
    return g.clamp(0.0, 1.5);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'sourceType': sourceType.json,
        'startMs': startMs,
        'durationMs': durationMs,
        'sourceStartMs': sourceStartMs,
        'sourceDurationMs': sourceDurationMs,
        'volume': volume,
        'muted': muted,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'loop': loop,
      };

  static AudioClip fromJson(Map<String, dynamic> j) => AudioClip(
        id: j['id'] as String? ?? 'audio',
        name: j['name'] as String? ?? 'Audio',
        filePath: j['filePath'] as String? ?? '',
        sourceType: AudioSourceTypeX.fromJson(j['sourceType'] as String?),
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 1000,
        sourceStartMs: (j['sourceStartMs'] as num?)?.toInt() ?? 0,
        sourceDurationMs: (j['sourceDurationMs'] as num?)?.toInt() ?? 0,
        volume: (j['volume'] as num?)?.toDouble() ?? 1.0,
        muted: j['muted'] as bool? ?? false,
        fadeInMs: (j['fadeInMs'] as num?)?.toInt() ?? 0,
        fadeOutMs: (j['fadeOutMs'] as num?)?.toInt() ?? 0,
        loop: j['loop'] as bool? ?? false,
      );

  AudioClip cloneWith({String? id, int? startMs}) => AudioClip.fromJson(toJson())
    ..id = id ?? this.id
    ..startMs = startMs ?? this.startMs;
}

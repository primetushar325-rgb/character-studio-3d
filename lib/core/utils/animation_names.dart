/// Animation-name normalization + standard-action detection.
///
/// Real-world GLB files name their clips in wildly different ways:
///   "Walk", "walk", "WALK", "walking", "Walk_01", "walk_cycle",
///   "Armature|mixamo.com|Take 001|Walk" ...
///
/// This utility provides:
///  - [AnimationNames.normalize]  → friendly display labels (generic)
///  - [StandardActionMatcher]     → the 6 required actions (Stand, Walk,
///    Run, Sit, Sleep, Talk) detected via alias tables with a confidence
///    score, so nothing is claimed to exist when it doesn't.
///
/// The *original* clip identifier is always preserved in the model so the
/// viewer can address the exact clip inside the GLB.
library;

class NormalizedAnimation {
  const NormalizedAnimation({
    required this.display,
    required this.canonical,
    required this.known,
  });

  /// Friendly display label, e.g. "Walk".
  final String display;

  /// Canonical key when recognized (e.g. "walk"), otherwise a prettified key.
  final String canonical;

  /// Whether this clip matched one of the well-known actions.
  final bool known;
}

// ======================================================================
// Required / standard action system
// ======================================================================

/// The six standard actions every character maps against.
class StandardAction {
  static const stand = 'stand';
  static const walk = 'walk';
  static const run = 'run';
  static const sit = 'sit';
  static const sleep = 'sleep';
  static const talk = 'talk';

  static const List<String> all = [stand, walk, run, sit, sleep, talk];

  static String label(String key) => switch (key) {
        stand => 'Stand',
        walk => 'Walk',
        run => 'Run',
        sit => 'Sit',
        sleep => 'Sleep',
        talk => 'Talk',
        _ => key,
      };
}

/// One action-detection candidate for a clip.
class ActionCandidate {
  const ActionCandidate({
    required this.action,
    required this.clipName,
    required this.confidence,
  });
  final String action;
  final String clipName;
  final double confidence;
}

/// Alias-based, case-insensitive, separator/digit-insensitive matcher for
/// the six standard actions.
class StandardActionMatcher {
  const StandardActionMatcher();

  /// Aliases are matched against fully normalized names (lowercase,
  /// alphanumeric only, trailing numbers stripped).
  static const Map<String, List<String>> aliases = {
    StandardAction.stand: [
      'stand', 'standing', 'standup', 'idle', 'idling', 'defaultidle',
      'standby', 'default', 'neutral', 'apose', 'tpose', 'breathing',
      'wait', 'waiting', 'bored', 'idlepose',
    ],
    StandardAction.walk: [
      'walk', 'walking', 'walkcycle', 'locomotionwalk', 'locomotion',
      'walkinplace', 'walkfwd', 'walkforward', 'walkslow',
    ],
    StandardAction.run: [
      'run', 'running', 'runcycle', 'sprint', 'sprinting', 'jog',
      'jogging', 'runinplace', 'runfwd', 'fastwalk',
    ],
    StandardAction.sit: [
      'sit', 'sitting', 'sitidle', 'sitdown', 'seated', 'chair', 'sitchair',
    ],
    StandardAction.sleep: [
      'sleep', 'sleeping', 'lay', 'lying', 'lie', 'liedown', 'laydown',
      'rest', 'resting', 'asleep',
    ],
    StandardAction.talk: [
      'talk', 'talking', 'speak', 'speaking', 'conversation', 'talkingphone',
      'chat', 'chatting', 'gossip',
    ],
  };

  /// Minimum confidence to auto-map an action without user confirmation.
  static const double autoMapThreshold = 0.75;

  /// Minimum confidence to *suggest* an action (⚠️ candidate, user confirms).
  static const double suggestThreshold = 0.40;

  /// Normalize a raw clip name for matching.
  /// "Walk_Cycle_01" → "walkcycle", "walk-cycle" → "walkcycle".
  static String normalize(String raw) {
    // Strip mixamo-style prefixes: "Armature|mixamo.com|Take 001|Walk"
    var source = raw.trim();
    if (source.contains('|')) {
      final parts = source
          .split('|')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty && p.toLowerCase() != 'mixamo.com');
      source = parts.isNotEmpty ? parts.last : source;
    }
    var s = source.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    // Strip trailing numbers: idle01 → idle, take001 → take
    s = s.replaceAll(RegExp(r'\d+$'), '');
    // Strip a leading generation number if any
    s = s.replaceAll(RegExp(r'^\d+'), '');
    return s;
  }

  /// Confidence for one alias against one normalized clip name.
  static double _score(String alias, String normalized) {
    if (normalized.isEmpty) return 0;
    if (normalized == alias) return 0.98; // "Walk_Cycle" → Walk → 98%
    if (normalized.startsWith(alias)) return 0.90; // "walkcycle"… wait, equal
    if (alias.length >= 6 && normalized.contains(alias)) {
      return 0.71; // "humanlocomotion" ⊃ "locomotion" → 71%
    }
    if (alias.length >= 4 && normalized.contains(alias)) return 0.65;
    return 0;
  }

  /// Best action candidate for one clip (may be null when nothing matches).
  ActionCandidate? candidateForClip(String clipName) {
    final normalized = normalize(clipName);
    ActionCandidate? best;
    for (final entry in aliases.entries) {
      for (final alias in entry.value) {
        final c = _score(alias, normalized);
        if (c > 0 && (best == null || c > best.confidence)) {
          best = ActionCandidate(
            action: entry.key,
            clipName: clipName,
            confidence: c,
          );
        }
      }
    }
    return best;
  }

  /// Best clip candidate for one action across all clips in the model.
  ActionCandidate? bestClipFor(
      String action, List<String> clipNames) {
    ActionCandidate? best;
    for (final clip in clipNames) {
      final normalized = normalize(clip);
      for (final alias in aliases[action] ?? const <String>[]) {
        final c = _score(alias, normalized);
        if (c > 0 && (best == null || c > best.confidence)) {
          best = ActionCandidate(action: action, clipName: clip, confidence: c);
        }
      }
    }
    return best;
  }

  /// Full detection pass → auto mapping (≥ autoMapThreshold) and
  /// suggestions (≥ suggestThreshold) per standard action.
  StandardDetection detect(List<String> clipNames) {
    final mapped = <String, ActionCandidate>{};
    final suggested = <String, ActionCandidate>{};

    for (final action in StandardAction.all) {
      final best = bestClipFor(action, clipNames);
      if (best == null) continue;

      // Avoid mapping the same clip to two different actions when a better
      // assignment exists for it (first action wins by higher confidence).
      final alreadyUsed = mapped.values.any((c) => c.clipName == best.clipName);
      if (best.confidence >= autoMapThreshold && !alreadyUsed) {
        mapped[action] = best;
      } else if (best.confidence >= suggestThreshold) {
        suggested[action] = best;
      }
    }
    return StandardDetection(mapped: mapped, suggested: suggested);
  }
}

/// Result of the standard-action detection pass.
class StandardDetection {
  const StandardDetection({required this.mapped, required this.suggested});

  /// action → high-confidence auto-mapped clip.
  final Map<String, ActionCandidate> mapped;

  /// action → low-confidence candidate requiring user confirmation.
  final Map<String, ActionCandidate> suggested;
}

// ======================================================================
// Generic display-name normalization (library-wide, all clips)
// ======================================================================

class AnimationNames {
  AnimationNames._();

  /// Canonical action -> raw-name fragments for friendly display.
  static const Map<String, List<String>> _canonicalMap = {
    'idle': ['idle', 'idling', 'breathing', 'standby', 'default', 'a_pose', 'tpose', 't_pose'],
    'walk': ['walk', 'walking', 'walkinplace', 'walkin_place', 'walkcycle'],
    'run': ['run', 'running', 'runinplace', 'sprint', 'sprinting', 'jog', 'jogging'],
    'jump': ['jump', 'jumping', 'jumpup', 'jump_idle', 'hop', 'hopping'],
    'stand': ['stand', 'standing', 'standup', 'stand_up'],
    'sit': ['sit', 'sitting', 'sitdown', 'sit_down', 'sitidle'],
    'sleep': ['sleep', 'sleeping', 'lay', 'lying', 'lie', 'rest', 'resting'],
    'talk': ['talk', 'talking', 'speak', 'speaking', 'conversation', 'talkingphone'],
    'dance': ['dance', 'dancing', 'dancer', 'danceloop'],
    'attack': ['attack', 'attacking', 'slash', 'stab', 'melee', 'sword', 'combo'],
    'wave': ['wave', 'waving', 'hello', 'greeting', 'greet'],
    'cry': ['cry', 'crying', 'sob', 'sobbing', 'sad', 'tears'],
    'laugh': ['laugh', 'laughing', 'laughter'],
    'fight': ['fight', 'fighting', 'combat', 'boxing', 'spar', 'sparring'],
    'fall': ['fall', 'falling', 'falldown', 'fall_down', 'trip', 'stumble', 'faint'],
    'clap': ['clap', 'clapping', 'applause'],
    'punch': ['punch', 'punching', 'jab'],
    'kick': ['kick', 'kicking'],
    'shout': ['shout', 'shouting', 'yell', 'yelling', 'scream'],
    'die': ['die', 'dying', 'death', 'dead', 'dieing'],
    'fly': ['fly', 'flying', 'float', 'floating', 'hover', 'hovering', 'flyidle'],
    'swim': ['swim', 'swimming'],
    'crawl': ['crawl', 'crawling', 'creep'],
    'crouch': ['crouch', 'crouching', 'crouchidle', 'sneak', 'sneaking'],
    'climb': ['climb', 'climbing'],
    'push': ['push', 'pushing'],
    'pull': ['pull', 'pulling'],
    'throw': ['throw', 'throwing'],
    'eat': ['eat', 'eating', 'drink', 'drinking'],
    'victory': ['victory', 'win', 'winning', 'cheer', 'cheering'],
    'death': ['death', 'dying'],
    'hurt': ['hurt', 'damaged', 'hit', 'hitreact', 'gethit', 'takehit'],
    'spawn': ['spawn', 'spawning', 'respawn', 'appear'],
    'block': ['block', 'blocking', 'guard'],
    'roll': ['roll', 'rolling', 'dodge', 'dodging'],
    'survey': ['survey', 'surveying', 'look', 'looking', 'lookaround', 'scan'],
  };

  static final Map<String, String> _canonicalDisplay = {
    for (final e in _canonicalMap.keys) e: _titleOf(e),
  };

  static String _titleOf(String key) {
    if (key.length <= 1) return key.toUpperCase();
    return key[0].toUpperCase() + key.substring(1);
  }

  /// Noisy fragments stripped from raw clip names.
  static const Set<String> _noiseTokens = {
    'mixamo.com', 'mixamo', 'armature', 'take', 'take001', 'clip',
    'animation', 'anim', 'action', 'base', 'layer', 'loop', 'cycle',
    'inplace', 'in_place', '01', '02', '03', '04', '05', '06', '07',
    '08', '09', '10', '1', '2', '3', '4', '5', '00', '0001',
  };

  /// Normalize a raw clip name from a GLB file into a friendly label.
  static NormalizedAnimation normalize(String raw, {int fallbackIndex = 1}) {
    var source = raw.trim();

    // "Armature|mixamo.com|Take 001|Walk" → "Walk"
    if (source.contains('|')) {
      final parts = source.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty);
      final meaningful = parts.where((p) => !_noiseTokens.contains(p.toLowerCase()));
      source = meaningful.isNotEmpty ? meaningful.last : (parts.isNotEmpty ? parts.last : source);
    }

    // Drop common decorations: Walk_01, walk-cycle(2), Take_001
    source = source.replaceAll(RegExp(r'\(\d+\)'), ' ');
    source = source.replaceAll(RegExp(r'[_\-]+(take|anim|action|clip|layer)?[_\-]*\d+$', caseSensitive: false), '');

    if (source.trim().isEmpty) {
      final display = 'Animation $fallbackIndex';
      return NormalizedAnimation(display: display, canonical: 'animation_$fallbackIndex', known: false);
    }

    final compact = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compact.isEmpty) {
      final display = 'Animation $fallbackIndex';
      return NormalizedAnimation(display: display, canonical: 'animation_$fallbackIndex', known: false);
    }

    // 1) Exact compact match
    for (final entry in _canonicalMap.entries) {
      for (final fragment in entry.value) {
        if (compact == fragment) {
          return NormalizedAnimation(
            display: _canonicalDisplay[entry.key]!,
            canonical: entry.key,
            known: true,
          );
        }
      }
    }

    // 2) Prefix match ("walkcycle", "walkinplace"…)
    for (final entry in _canonicalMap.entries) {
      for (final fragment in entry.value) {
        if (fragment.length >= 4 && compact.startsWith(fragment)) {
          return NormalizedAnimation(
            display: _canonicalDisplay[entry.key]!,
            canonical: entry.key,
            known: true,
          );
        }
      }
    }

    // 3) Token match ("walk_fast", "Sword Attack"…)
    final tokens = source
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    for (final token in tokens) {
      for (final entry in _canonicalMap.entries) {
        if (entry.value.contains(token)) {
          return NormalizedAnimation(
            display: _canonicalDisplay[entry.key]!,
            canonical: entry.key,
            known: true,
          );
        }
      }
    }

    // 4) Unknown clip → prettified display
    final spaced = source
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final display = spaced.isEmpty ? 'Animation $fallbackIndex' : _titleWords(spaced);
    return NormalizedAnimation(display: display, canonical: display.toLowerCase(), known: false);
  }

  static String _titleWords(String s) {
    return s
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

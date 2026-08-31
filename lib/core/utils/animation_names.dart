/// Animation-name normalization.
///
/// Real-world GLB files name their clips in wildly different ways:
///   "Walk", "walk", "WALK", "walking", "Walk_01", "walk_cycle",
///   "Armature|mixamo.com|Take 001|Walk" ...
///
/// This utility converts those raw clip identifiers into:
///   - [NormalizedAnimation.display]  → friendly label for the UI
///   - [NormalizedAnimation.canonical]→ stable key for icons/search/history
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

class AnimationNames {
  AnimationNames._();

  /// Canonical action -> list of raw-name fragments that map to it.
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

  /// Canonical key -> display label (all simple Title Case).
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

  /// Normalize a raw clip name from a GLB file.
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

    // 1) Exact compact match ("walking" → walk? handled by contains below)
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

    // 2) Prefix match ("walkcycle", "walkinplace", "runfwd" ...)
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

    // 3) Token match ("walk_fast", "run-left", "Sword Attack" ...)
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

    // 4) Unknown clip → prettified display ("ZombieAttackSlow" → "Zombie Attack Slow")
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

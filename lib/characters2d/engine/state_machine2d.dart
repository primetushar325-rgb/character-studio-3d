/// Animation states for the 2D character system.
enum CharState { idle, walk, run, sit, sleep, talk }

/// Pure, testable state machine with the exact transition table from the
/// spec. Unnatural jumps (e.g. Sleep → Run) are never direct: [route]
/// returns a multi-hop path through legal transitions instead.
class StateMachine2D {
  StateMachine2D({this.state = CharState.idle});

  CharState state;

  /// Parameters (speed / isTalking / isSitting / isSleeping / expression /
  /// direction are owned by the controller; the machine exposes them for the
  /// transition guards).
  final Map<String, double> params = {};

  /// Trigger queue (wave, greet, point, laugh, cry, surprise, ...).
  final List<String> triggers = [];

  static const Map<CharState, Set<CharState>> transitions = {
    CharState.idle: {CharState.walk, CharState.run, CharState.sit, CharState.talk},
    CharState.walk: {CharState.idle, CharState.run, CharState.talk},
    CharState.run: {CharState.idle, CharState.walk},
    CharState.sit: {CharState.idle, CharState.talk, CharState.sleep},
    CharState.sleep: {CharState.sit, CharState.idle},
    CharState.talk: {CharState.idle, CharState.walk, CharState.sit},
  };

  bool canGoDirect(CharState to) => transitions[state]!.contains(to);

  /// Shortest legal path [current..to] (BFS). Empty when already there.
  List<CharState> route(CharState to) {
    if (state == to) return const [];
    final prev = <CharState, CharState>{};
    final queue = <CharState>[state];
    final seen = <CharState>{state};
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final next in transitions[cur] ?? const <CharState>{}) {
        if (seen.contains(next)) continue;
        seen.add(next);
        prev[next] = cur;
        if (next == to) {
          final path = <CharState>[to];
          var c = to;
          while (prev[c] != null && prev[c] != state) {
            c = prev[c]!;
            path.insert(0, c);
          }
          return path;
        }
        queue.add(next);
      }
    }
    return const [];
  }

  /// Whether a request can be honoured at all (all states are reachable in
  /// this graph, so this is always true — kept for clarity/tests).
  bool isReachable(CharState to) => route(to).isNotEmpty || state == to;

  void force(CharState to) => state = to;

  void fire(String trigger) => triggers.add(trigger);
}

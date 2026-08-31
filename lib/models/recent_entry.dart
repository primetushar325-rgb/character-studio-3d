/// One "recently used" entry: character + animation, persisted locally.
class RecentEntry {
  const RecentEntry({
    required this.characterId,
    required this.animationName,
    required this.animationDisplay,
    required this.timestamp,
  });

  final String characterId;

  /// Original clip identifier (addressed inside the GLB).
  final String animationName;

  /// Friendly display label at time of use.
  final String animationDisplay;
  final DateTime timestamp;

  /// Key used to de-duplicate entries (same character + same animation).
  String get key => '$characterId::$animationName';

  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'animationName': animationName,
        'animationDisplay': animationDisplay,
        'timestamp': timestamp.toIso8601String(),
      };

  static RecentEntry fromJson(Map<String, dynamic> json) => RecentEntry(
        characterId: json['characterId'] as String? ?? '',
        animationName: json['animationName'] as String? ?? '',
        animationDisplay: json['animationDisplay'] as String? ?? '',
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

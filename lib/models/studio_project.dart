import 'viewer_enums.dart';

/// A saved studio project: character + animation + scene setup.
class StudioProject {
  StudioProject({
    required this.id,
    required this.name,
    required this.characterId,
    required this.animationName,
    required this.animationDisplay,
    required this.background,
    required this.lighting,
    required this.cameraOrbit,
    required this.autoRotate,
    required this.durationSeconds,
    required this.createdAt,
    this.customBackgroundHex,
    this.lastOpenedAt,
  });

  final String id;
  String name;
  final String characterId;
  final String animationName;
  final String animationDisplay;

  BackgroundPreset background;
  String? customBackgroundHex;
  LightingPreset lighting;
  String cameraOrbit;
  bool autoRotate;
  int durationSeconds;
  final DateTime createdAt;
  DateTime? lastOpenedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'characterId': characterId,
        'animationName': animationName,
        'animationDisplay': animationDisplay,
        'background': background.name,
        'customBackgroundHex': customBackgroundHex,
        'lighting': lighting.name,
        'cameraOrbit': cameraOrbit,
        'autoRotate': autoRotate,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      };

  static StudioProject fromJson(Map<String, dynamic> json) => StudioProject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Untitled Project',
        characterId: json['characterId'] as String? ?? '',
        animationName: json['animationName'] as String? ?? '',
        animationDisplay: json['animationDisplay'] as String? ?? '',
        background: BackgroundPreset.values.firstWhere(
          (b) => b.name == json['background'],
          orElse: () => BackgroundPreset.studio,
        ),
        customBackgroundHex: json['customBackgroundHex'] as String?,
        lighting: LightingPreset.values.firstWhere(
          (l) => l.name == json['lighting'],
          orElse: () => LightingPreset.studio,
        ),
        cameraOrbit: json['cameraOrbit'] as String? ?? CameraPresets.front,
        autoRotate: json['autoRotate'] as bool? ?? false,
        durationSeconds: json['durationSeconds'] as int? ?? 10,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        lastOpenedAt: json['lastOpenedAt'] == null
            ? null
            : DateTime.tryParse(json['lastOpenedAt'] as String),
      );
}

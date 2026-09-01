import 'package:flutter/material.dart';

import 'art/character_catalog.dart';
import 'art/palettes.dart';

/// A usable 2D character: a catalog spec + optional customization.
/// Built-ins and saved variants share this shape, so the library, preview,
/// editor and persistence treat them identically.
class Character2D {
  Character2D({
    required this.id,
    required this.specId,
    required this.name,
    Map<String, Color>? palette,
    Set<String>? accessories,
    this.isVariant = false,
    this.imagePath,
    this.rigKind,
    this.createdAt,
    this.updatedAt,
    this.lastUsedAt,
    this.usageCount = 0,
  })  : paletteOverrides = palette ?? {},
        accessories = accessories ?? {};

  final String id;

  /// Catalog blueprint id (bd_farmer_male / village_girl / school_teacher).
  final String specId;
  String name;

  /// Slot key -> color overrides on top of the default palette.
  final Map<String, Color> paletteOverrides;

  /// Active accessory keys (gamcha / dupatta / glasses / book ...).
  final Set<String> accessories;

  final bool isVariant;

  /// For imported PNG cutout characters: the copied artwork path.
  final String? imagePath;

  /// Rig kind for imported PNG cutout characters (persisted so the spec can
  /// be re-registered after an app restart).
  final String? rigKind;
  final DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? lastUsedAt;
  int usageCount;

  Character2DSpec get spec {
    final s = CharacterCatalog.byId(specId);
    assert(s != null, 'Unknown character spec: $specId');
    return s ?? CharacterCatalog.farmer;
  }

  PaletteColors get colors => spec.defaultPalette.withOverrides(paletteOverrides);

  bool get isBuiltIn => !isVariant;

  /// The §32 metadata for this character (incl. customization).
  Map<String, dynamic> metadata() {
    final m = spec.metadata();
    m['id'] = id;
    m['name'] = name;
    m['isVariant'] = isVariant;
    m['customization'] = {
      for (final e in paletteOverrides.entries) e.key: '#${e.value.value.toRadixString(16).padLeft(8, '0')}',
    };
    m['accessories'] = accessories.toList();
    m['createdAt'] = createdAt?.toIso8601String();
    m['updatedAt'] = updatedAt?.toIso8601String();
    m['lastUsedAt'] = lastUsedAt?.toIso8601String();
    m['usageCount'] = usageCount;
    return m;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'specId': specId,
        'name': name,
        'palette': {for (final e in paletteOverrides.entries) e.key: e.value.value},
        'accessories': accessories.toList(),
        'imagePath': imagePath,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'lastUsedAt': lastUsedAt?.millisecondsSinceEpoch,
        'usageCount': usageCount,
      };

  static Character2D fromJson(Map<String, dynamic> json) => Character2D(
        id: json['id'] as String,
        specId: json['specId'] as String,
        name: json['name'] as String,
        palette: {
          for (final e in (json['palette'] as Map<String, dynamic>? ?? {}).entries)
            e.key: Color((e.value as num).toInt()),
        },
        accessories: {...?((json['accessories'] as List?)?.cast<String>())},
        isVariant: true,
        imagePath: json['imagePath'] as String?,
        rigKind: json['rigKind'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num?)?.toInt() ?? 0),
        lastUsedAt: json['lastUsedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((json['lastUsedAt'] as num).toInt()),
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      );

  static Character2D builtIn(Character2DSpec spec) => Character2D(
        id: spec.id,
        specId: spec.id,
        name: spec.name,
        accessories: {...spec.defaultAccessories},
        createdAt: DateTime(2026, 1, 1),
        usageCount: 0,
      );

  Character2D copyWith({String? name, Map<String, Color>? palette, Set<String>? accessories}) => Character2D(
        id: id,
        specId: specId,
        name: name ?? this.name,
        palette: palette ?? paletteOverrides,
        accessories: accessories ?? this.accessories,
        isVariant: isVariant,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastUsedAt: lastUsedAt,
        usageCount: usageCount,
      );
}

/// Recent usage entry (persisted separately from character data).
class Recent2DEntry {
  const Recent2DEntry(this.characterId, this.lastUsedAt, this.usageCount);
  final String characterId;
  final DateTime lastUsedAt;
  final int usageCount;

  Map<String, dynamic> toJson() => {
        'id': characterId,
        'at': lastUsedAt.millisecondsSinceEpoch,
        'count': usageCount,
      };

  static Recent2DEntry fromJson(Map<String, dynamic> j) => Recent2DEntry(
        j['id'] as String,
        DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
        (j['count'] as num?)?.toInt() ?? 1,
      );
}

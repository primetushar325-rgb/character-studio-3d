import 'package:flutter/material.dart';

import '../core/utils/animation_names.dart';
import '../models/character.dart' show CharacterReadiness;
import 'glb_parser_service.dart';
import 'humanoid_detector.dart';

enum ValidationStatus { pass, warn, fail, info }

/// One line in the validation report (e.g. "✅ Skeleton detected").
class ValidationCheck {
  const ValidationCheck({
    required this.id,
    required this.label,
    required this.status,
    this.detail,
  });

  final String id;
  final String label;
  final ValidationStatus status;
  final String? detail;
}

/// Status of one standard action for one character.
class ActionStatus {
  const ActionStatus({
    required this.action,
    required this.state,
    this.clipName,
    this.confidence = 0,
    this.suggestedClip,
  });

  final String action; // stand/walk/run/sit/sleep/talk

  /// found  → mapped (auto high-confidence or manually confirmed)
  /// suggested → low-confidence candidate (⚠️ missing — user can confirm)
  /// missing → no candidate at all
  final String state; // 'found' | 'suggested' | 'missing'
  final String? clipName; // original clip identifier when found
  final double confidence;
  final String? suggestedClip;

  bool get isFound => state == 'found';
  bool get isSuggested => state == 'suggested';
}

/// Full validation report for an imported (or scanned) GLB.
class ValidationReport {
  const ValidationReport({
    required this.checks,
    required this.actions,
    required this.readiness,
    required this.autoMapping,
    required this.suggestions,
    this.humanoidRig,
  });

  final List<ValidationCheck> checks;
  final List<ActionStatus> actions;
  final CharacterReadiness readiness;

  /// action → clip (high-confidence auto mappings, ready to save).
  final Map<String, String> autoMapping;

  /// action → clip (low-confidence candidates awaiting user confirmation).
  final Map<String, String> suggestions;

  final HumanoidRig? humanoidRig;

  int get foundActionCount => actions.where((a) => a.isFound).length;

  static String readinessLabel(CharacterReadiness r) => switch (r) {
        CharacterReadiness.ready => 'Ready',
        CharacterReadiness.partial => 'Partial',
        CharacterReadiness.invalid => 'Invalid',
      };

  static Color readinessColor(CharacterReadiness r) => switch (r) {
        CharacterReadiness.ready => const Color(0xFF6BD9A5),
        CharacterReadiness.partial => const Color(0xFFFFC46B),
        CharacterReadiness.invalid => const Color(0xFFFF6B7A),
      };
}

/// Turns raw GLB parse data into a professional, honest validation report.
/// Nothing is claimed to exist when it doesn't — animations either match an
/// alias with a confidence score or are reported missing.
class ValidationService {
  const ValidationService({
    this.humanoidDetector = const HumanoidDetector(),
    this.matcher = const StandardActionMatcher(),
    this.maxBytes = 250 * 1024 * 1024,
    this.warnBytes = 80 * 1024 * 1024,
  });

  final HumanoidDetector humanoidDetector;
  final StandardActionMatcher matcher;
  final int maxBytes;
  final int warnBytes;

  ValidationReport validate({
    required GlbModelData data,
    required int fileBytes,
    bool fileReadable = true,
  }) {
    final checks = <ValidationCheck>[];

    // ---------------- FILE ----------------
    checks.add(ValidationCheck(
      id: 'file.valid',
      label: 'GLB file valid',
      status: ValidationStatus.pass,
      detail: data.generator ?? 'glTF 2.0 binary container',
    ));
    checks.add(ValidationCheck(
      id: 'file.readable',
      label: 'File readable',
      status: fileReadable ? ValidationStatus.pass : ValidationStatus.fail,
      detail: fileReadable ? null : 'The file could not be opened',
    ));
    if (fileBytes > maxBytes) {
      checks.add(ValidationCheck(
        id: 'file.size',
        label: 'File size within limit',
        status: ValidationStatus.fail,
        detail: '${(fileBytes / 1024 / 1024).toStringAsFixed(0)} MB exceeds the 250 MB limit',
      ));
    } else if (fileBytes > warnBytes) {
      checks.add(ValidationCheck(
        id: 'file.size',
        label: 'File size within limit',
        status: ValidationStatus.warn,
        detail:
            'Large model (${(fileBytes / 1024 / 1024).toStringAsFixed(0)} MB) may play slowly',
      ));
    } else {
      checks.add(ValidationCheck(
        id: 'file.size',
        label: 'File size within limit',
        status: ValidationStatus.pass,
        detail: '${(fileBytes / 1024).toStringAsFixed(0)} KB',
      ));
    }

    // ---------------- SCENE ----------------
    checks.add(ValidationCheck(
      id: 'scene.nodes',
      label: 'Scene graph detected',
      status: data.rootNodeCount > 0 ? ValidationStatus.pass : ValidationStatus.warn,
      detail: '${data.nodeCount} nodes · ${data.rootNodeCount} root(s)',
    ));
    checks.add(ValidationCheck(
      id: 'scene.mesh',
      label: '3D mesh detected',
      status: data.meshCount > 0 ? ValidationStatus.pass : ValidationStatus.fail,
      detail: '${data.meshCount} mesh(es) · '
          '${(data.triangleCount / 1000).toStringAsFixed(1)}K triangles',
    ));
    checks.add(ValidationCheck(
      id: 'scene.materials',
      label: 'Materials detected',
      status: data.materialCount > 0 ? ValidationStatus.pass : ValidationStatus.warn,
      detail: data.materialCount > 0
          ? '${data.materialCount} material(s)'
          : 'No materials — the model will render unshaded',
    ));
    checks.add(ValidationCheck(
      id: 'scene.textures',
      label: 'Textures detected',
      status: data.textureCount > 0 ? ValidationStatus.pass : ValidationStatus.warn,
      detail: data.textureCount > 0
          ? '${data.textureCount} texture(s)'
          : 'No textures — colors come from materials only',
    ));
    checks.add(ValidationCheck(
      id: 'scene.camera',
      label: 'Camera node',
      status: ValidationStatus.info,
      detail: data.cameraCount > 0
          ? '${data.cameraCount} embedded (viewer camera used instead)'
          : 'None embedded — viewer camera used',
    ));
    checks.add(ValidationCheck(
      id: 'scene.lights',
      label: 'Light nodes',
      status: ValidationStatus.info,
      detail: data.lightCount > 0
          ? '${data.lightCount} embedded — studio lighting still applied'
          : 'None embedded — studio lighting used',
    ));
    if (data.triangleCount > GlbParserService.warnTriangles) {
      checks.add(ValidationCheck(
        id: 'scene.polygons',
        label: 'Polygon count',
        status: ValidationStatus.warn,
        detail:
            '${(data.triangleCount / 1000000).toStringAsFixed(1)}M triangles — may be slow on low-end devices',
      ));
    }

    // ---------------- CHARACTER / RIG ----------------
    final hasSkeleton = data.hasSkeleton;
    final boneCount = data.totalBoneCount;
    HumanoidRig? rig;
    if (hasSkeleton) {
      rig = humanoidDetector.detect(data.boneNames);
    }

    checks.add(ValidationCheck(
      id: 'char.root',
      label: 'Root node detected',
      status: data.rootNodeCount > 0 ? ValidationStatus.pass : ValidationStatus.warn,
      detail: null,
    ));
    checks.add(ValidationCheck(
      id: 'char.skeleton',
      label: 'Skeleton detected',
      status: hasSkeleton ? ValidationStatus.pass : ValidationStatus.warn,
      detail: hasSkeleton
          ? '$boneCount bones · ${data.skins.length} armature(s)'
          : 'No skeleton — static model, animations cannot play',
    ));
    checks.add(ValidationCheck(
      id: 'char.skinning',
      label: 'Skinned mesh detected',
      status: hasSkeleton ? ValidationStatus.pass : ValidationStatus.warn,
      detail: hasSkeleton
          ? 'Rigged character (skin + bones attached)'
          : 'Mesh is not bound to a skeleton',
    ));
    if (hasSkeleton) {
      final deepest = data.skins.fold<int>(0, (m, s) => s.hierarchyDepth > m ? s.hierarchyDepth : m);
      checks.add(ValidationCheck(
        id: 'char.hierarchy',
        label: 'Bone hierarchy valid',
        status: deepest >= 2 ? ValidationStatus.pass : ValidationStatus.warn,
        detail: 'Hierarchy depth $deepest level(s)',
      ));
      checks.add(ValidationCheck(
        id: 'char.humanoid',
        label: rig!.humanLike ? 'Human-like character' : 'Non-humanoid rig',
        status: rig.humanLike ? ValidationStatus.pass : ValidationStatus.warn,
        detail: rig.humanLike
            ? '${rig.matchedCount}/17 humanoid bones matched (${(rig.score * 100).round()}%)'
            : 'Only ${rig.matchedCount}/17 humanoid bones matched — animation '
                'mapping still works per-clip',
      ));
    }

    // ---------------- ANIMATIONS ----------------
    final clipNames = [for (final a in data.animations) a.name];
    final detection = matcher.detect(clipNames);
    checks.add(ValidationCheck(
      id: 'anim.clips',
      label: hasAnimationsLabel(data),
      status: data.animations.isEmpty ? ValidationStatus.warn : ValidationStatus.pass,
      detail: data.animations.isEmpty
          ? 'No animation clips embedded — model can still be viewed in 3D'
          : _clipSummary(clipNames),
    ));

    // Action statuses (found / suggested / missing) — honest, no fakes.
    final actions = <ActionStatus>[];
    for (final action in StandardAction.all) {
      if (detection.mapped.containsKey(action)) {
        final c = detection.mapped[action]!;
        actions.add(ActionStatus(
          action: action,
          state: 'found',
          clipName: c.clipName,
          confidence: c.confidence,
        ));
      } else if (detection.suggested.containsKey(action)) {
        final c = detection.suggested[action]!;
        actions.add(ActionStatus(
          action: action,
          state: 'suggested',
          suggestedClip: c.clipName,
          confidence: c.confidence,
        ));
      } else {
        actions.add(ActionStatus(action: action, state: 'missing'));
      }
    }

    // ---------------- OVERALL ----------------
    final failed = checks.any((c) => c.status == ValidationStatus.fail);
    CharacterReadiness readiness;
    if (failed || data.meshCount == 0) {
      readiness = CharacterReadiness.invalid;
    } else if (hasSkeleton && detection.mapped.isNotEmpty) {
      readiness = CharacterReadiness.ready;
    } else {
      readiness = CharacterReadiness.partial;
    }

    return ValidationReport(
      checks: checks,
      actions: actions,
      readiness: readiness,
      autoMapping: {
        for (final e in detection.mapped.entries) e.key: e.value.clipName,
      },
      suggestions: {
        for (final e in detection.suggested.entries) e.key: e.value.clipName,
      },
      humanoidRig: rig,
    );
  }

  static String hasAnimationsLabel(GlbModelData data) => data.animations.isEmpty
      ? 'No animations detected'
      : '${data.animations.length} animations detected';

  static String _clipSummary(List<String> clipNames) {
    final shown = clipNames.take(4).join(', ');
    final extra = clipNames.length > 4 ? ' …' : '';
    return '${clipNames.length} clip(s): $shown$extra';
  }
}

/// Icon + color helpers shared by the validation UIs.
IconData statusIcon(ValidationStatus s) => switch (s) {
      ValidationStatus.pass => Icons.check_circle_rounded,
      ValidationStatus.warn => Icons.error_outline_rounded,
      ValidationStatus.fail => Icons.cancel_rounded,
      ValidationStatus.info => Icons.info_outline_rounded,
    };

Color statusColor(ValidationStatus s) => switch (s) {
      ValidationStatus.pass => const Color(0xFF6BD9A5),
      ValidationStatus.warn => const Color(0xFFFFC46B),
      ValidationStatus.fail => const Color(0xFFFF6B7A),
      ValidationStatus.info => const Color(0xFF7B9BFF),
    };

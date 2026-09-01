import 'package:flutter/material.dart' show Color;

/// Phase 2 — multi-object scene graph model.
///
/// Every visible thing in the composition (except the project background,
/// which stays a first-class project field rendered bottom-most) is a
/// SceneObject. Transforms are CANVAS-RELATIVE (0..1 of project width /
/// height) so they survive orientation/resolution changes.
enum SceneObjectType { character, image, text, shape }

/// Common transform for every object (canvas-relative coordinates).
class ObjectTransform {
  ObjectTransform({
    this.x = 0.5,
    this.y = 0.78,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.flipH = false,
  });

  /// 0..1 of canvas width (object anchor point).
  double x;
  /// 0..1 of canvas height (character ground line / object center).
  double y;
  double scaleX;
  double scaleY;
  double rotation; // degrees, clockwise
  double opacity; // 0..1
  bool flipH;

  Map<String, dynamic> toJson() => {
        'x': x, 'y': y, 'scaleX': scaleX, 'scaleY': scaleY,
        'rotation': rotation, 'opacity': opacity, 'flipH': flipH,
      };

  static ObjectTransform fromJson(Map<String, dynamic>? j) => ObjectTransform(
        x: (j?['x'] as num?)?.toDouble() ?? 0.5,
        y: (j?['y'] as num?)?.toDouble() ?? 0.78,
        scaleX: (j?['scaleX'] as num?)?.toDouble() ?? 1,
        scaleY: (j?['scaleY'] as num?)?.toDouble() ?? 1,
        rotation: (j?['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (j?['opacity'] as num?)?.toDouble() ?? 1,
        flipH: j?['flipH'] as bool? ?? false,
      );
}

/// Shape kinds for Phase 2 (rectangle / circle / line).
enum ShapeKind2 { rect, circle, line }

/// A scene object: character / image / text / shape.
class SceneObject {
  SceneObject({
    required this.id,
    required this.type,
    required this.name,
    required this.zIndex,
    this.visible = true,
    this.locked = false,
    ObjectTransform? transform,
    // character
    this.characterId,
    this.actionId = 'idle',
    this.expression,
    this.talking = false,
    this.directionLeft = false,
    // image
    this.imagePath,
    // text
    this.text = 'Text',
    this.fontSize = 64,
    this.fontWeight = 700,
    this.fontFamily,
    this.textColor = 0xFFF3F5FB,
    this.textAlign = 'center',
    this.strokeColor = 0xFF11141C,
    this.strokeWidth = 0,
    this.textBgColor,
    // shape
    this.shapeKind = 'rect',
    this.width = 0.34,
    this.height = 0.2,
    this.fillColor = 0xFFF09A2E,
    this.shapeStrokeColor = 0xFF11141C,
    this.shapeStrokeWidth = 0,
  }) : transform = transform ?? ObjectTransform();

  final String id;
  final SceneObjectType type;
  String name;
  int zIndex; // render order: lower = deeper (background always below all)
  bool visible;
  bool locked;
  ObjectTransform transform;

  // ---- character ----------------------------------------------------------
  String? characterId; // Character2D.id in the library
  String actionId; // current animation action
  String? expression; // Expr name
  bool talking;
  bool directionLeft;

  // ---- image ---------------------------------------------------------------
  /// Project-RELATIVE path ("assets/img_xxx.png") so the project folder can
  /// be moved/copied without breaking.
  String? imagePath;

  // ---- text -----------------------------------------------------------------
  String text;
  double fontSize; // in project-canvas pixels (1920 space)
  int fontWeight;
  String? fontFamily;
  int textColor;
  String textAlign; // left / center / right
  int strokeColor;
  double strokeWidth;
  int? textBgColor;

  // ---- shape ----------------------------------------------------------------
  String shapeKind; // rect / circle / line
  double width; // 0..1 of canvas width
  double height; // 0..1 of canvas height
  int fillColor;
  int shapeStrokeColor;
  double shapeStrokeWidth;

  bool get isCharacter => type == SceneObjectType.character;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'z': zIndex,
        'visible': visible,
        'locked': locked,
        't': transform.toJson(),
        if (type == SceneObjectType.character) ...{
          'characterId': characterId,
          'actionId': actionId,
          'expression': expression,
          'talking': talking,
          'directionLeft': directionLeft,
        },
        if (type == SceneObjectType.image) 'imagePath': imagePath,
        if (type == SceneObjectType.text) ...{
          'text': text,
          'fontSize': fontSize,
          'fontWeight': fontWeight,
          'fontFamily': fontFamily,
          'textColor': textColor,
          'textAlign': textAlign,
          'strokeColor': strokeColor,
          'strokeWidth': strokeWidth,
          'textBgColor': textBgColor,
        },
        if (type == SceneObjectType.shape) ...{
          'shapeKind': shapeKind,
          'width': width,
          'height': height,
          'fillColor': fillColor,
          'strokeColor': shapeStrokeColor,
          'strokeWidth': shapeStrokeWidth,
        },
      };

  static SceneObject fromJson(Map<String, dynamic> j) {
    final type = SceneObjectType.values.byName(j['type'] as String? ?? 'shape');
    final t = ObjectTransform.fromJson((j['t'] as Map?)?.cast<String, dynamic>());
    return SceneObject(
      id: j['id'] as String,
      type: type,
      name: j['name'] as String? ?? type.name,
      zIndex: (j['z'] as num?)?.toInt() ?? 0,
      visible: j['visible'] as bool? ?? true,
      locked: j['locked'] as bool? ?? false,
      transform: t,
      characterId: j['characterId'] as String?,
      actionId: j['actionId'] as String? ?? 'idle',
      expression: j['expression'] as String?,
      talking: j['talking'] as bool? ?? false,
      directionLeft: j['directionLeft'] as bool? ?? false,
      imagePath: j['imagePath'] as String?,
      text: j['text'] as String? ?? 'Text',
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 64,
      fontWeight: (j['fontWeight'] as num?)?.toInt() ?? 700,
      fontFamily: j['fontFamily'] as String?,
      textColor: (j['textColor'] as num?)?.toInt() ?? 0xFFF3F5FB,
      textAlign: j['textAlign'] as String? ?? 'center',
      strokeColor: (j['strokeColor'] as num?)?.toInt() ?? 0xFF11141C,
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0,
      textBgColor: (j['textBgColor'] as num?)?.toInt(),
      shapeKind: j['shapeKind'] as String? ?? 'rect',
      width: (j['width'] as num?)?.toDouble() ?? 0.34,
      height: (j['height'] as num?)?.toDouble() ?? 0.2,
      fillColor: (j['fillColor'] as num?)?.toInt() ?? 0xFFF09A2E,
      shapeStrokeColor: (j['strokeColor'] as num?)?.toInt() ?? 0xFF11141C,
      shapeStrokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0,
    );
  }

  SceneObject clone() => SceneObject.fromJson(toJson());
}

/// Convenience factory: new character object.
SceneObject characterObject({
  required String id,
  required String characterId,
  required String name,
  required int zIndex,
  String actionId = 'idle',
}) =>
    SceneObject(id: id, type: SceneObjectType.character, name: name, zIndex: zIndex, characterId: characterId, actionId: actionId);

SceneObject imageObject({required String id, required String relPath, required String name, required int zIndex}) =>
    SceneObject(id: id, type: SceneObjectType.image, name: name, zIndex: zIndex, imagePath: relPath, transform: ObjectTransform(x: 0.5, y: 0.5));

SceneObject textObject({required String id, required int zIndex, String text = 'Text'}) =>
    SceneObject(id: id, type: SceneObjectType.text, name: 'Text', zIndex: zIndex, text: text, transform: ObjectTransform(x: 0.5, y: 0.4));

SceneObject shapeObject({required String id, required int zIndex, String kind = 'rect'}) =>
    SceneObject(id: id, type: SceneObjectType.shape, name: kind[0].toUpperCase() + kind.substring(1), zIndex: zIndex, shapeKind: kind, transform: ObjectTransform(x: 0.5, y: 0.5));

/// The whole scene: ordered object list (index = z-order).
class SceneGraph {
  SceneGraph({List<SceneObject>? objects}) : objects = objects ?? [];

  List<SceneObject> objects;

  /// Objects sorted for painting (background itself is painted separately
  /// before all objects; this list is the z-order above it).
  List<SceneObject> get paintOrder {
    final list = [...objects]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return list.where((o) => o.visible).toList();
  }

  Map<String, dynamic> toJson() => {
        'objects': [for (final o in objects) o.toJson()],
      };

  static SceneGraph fromJson(Map<String, dynamic>? j) => SceneGraph(
        objects: [
          for (final m in (j?['objects'] as List? ?? []))
            if (m is Map) SceneObject.fromJson(m.cast<String, dynamic>()),
        ],
      );
}

const shapeKinds = ['rect', 'circle', 'line'];

Color intToColor(int v) => Color(v);

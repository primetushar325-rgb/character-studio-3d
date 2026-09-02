import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../characters2d/art/character_catalog.dart';
import '../../characters2d/character2d_model.dart';
import '../../characters2d/png_character.dart';
import '../../characters2d/zip_pack.dart';
import '../../core/theme/app_colors.dart';
import '../../state/editor_provider.dart';
import '../../state/library2d_provider.dart';

/// ---- PNG CHARACTER IMPORT ---------------------------------------------------
///
/// 1. System picker → PNG/JPG/WEBP.
/// 2. Artwork copied into the app's character directory (never executed,
///    parse-only image decode).
/// 3. The exact artwork is mounted on the universal rig (humanoid or
///    quadruped cutout) — the design is preserved, only rigged for animation.
Future<void> importPngCharacter(BuildContext context) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
  );
  final src = res?.files.single.path;
  if (src == null) return;
  if (!context.mounted) return;

  final lib = context.read<Library2DProvider>();
  final ed = context.read<EditorProvider>();

  final rigKind = await _askRigKind(context);
  if (rigKind == null) return;
  if (!context.mounted) return;

  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/characters2d_png');
    await dir.create(recursive: true);
    final id = 'png_${DateTime.now().millisecondsSinceEpoch}';
    final name = _nameFromPath(src);
    final dest = '${dir.path}/$id.png';
    await File(src).copy(dest);

    final art = await loadPngArt(dest);
    if (art == null) throw 'artwork could not be decoded';
    CharacterCatalog.register(pngSpecFromArt(id: id, name: name, art: art, rigKind: rigKind));
    final character = Character2D(id: id, specId: id, name: name, isVariant: true, imagePath: dest, rigKind: rigKind, createdAt: DateTime.now());
    await lib.saveVariantFull(character);
    ed.loadCharacter(id);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added — full artwork preserved on a $rigKind rig.'), backgroundColor: AppColors.surfaceAlt),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Character asset could not be loaded: $e'), backgroundColor: AppColors.dangerSoft),
      );
    }
  }
}

Future<String?> _askRigKind(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Body type', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'humanoid_v1'),
          child: const Text('Humanoid (2 arms, 2 legs)', style: TextStyle(color: AppColors.textSecondary)),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'quadruped_v1'),
          child: const Text('Quadruped (4 legs + tail)', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    ),
  );
}

String _nameFromPath(String path) {
  final base = path.split(Platform.pathSeparator).last;
  final noExt = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
  return noExt.isEmpty ? 'PNG Character' : noExt.replaceFirst(noExt[0], noExt[0].toUpperCase());
}

/// ---- ZIP CHARACTER PACK IMPORT ---------------------------------------------
///
/// 1. System picker → .zip (manifest.json + art/*.png).
/// 2. The archive is parsed (never executed): manifest, bones and art are
///    validated — circular parents, missing art and non-PNG files reject the
///    pack with a clear reason.
/// 3. Valid packs install to the app's pack directory and register a fully
///    rigged character (custom bones included) on the shared engine.
Future<void> importZipPackCharacter(BuildContext context) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip'],
    withData: true,
  );
  final file = res?.files.single;
  final bytes = file?.bytes;
  if (bytes == null) return;
  if (!context.mounted) return;

  final lib = context.read<Library2DProvider>();
  final ed = context.read<EditorProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  try {
    final pack = await importZipPackBytes(Uint8List.fromList(bytes));
    final character = Character2D(
      id: pack.specId,
      specId: pack.specId,
      name: pack.name,
      isVariant: true,
      imagePath: pack.dir,
      rigKind: pack.rigKind,
      createdAt: DateTime.now(),
    );
    await lib.saveVariantFull(character);
    ed.loadCharacter(pack.specId);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${pack.name} pack imported on rig ${pack.rigKind}.'), backgroundColor: AppColors.surfaceAlt),
    );
  } on ZipPackException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.dangerSoft),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Pack could not be imported: \$e'), backgroundColor: AppColors.dangerSoft),
    );
  }
}

/// ---- PROMPT → CHARACTER --------------------------------------------------------
Future<void> showPromptDialog(BuildContext context) async {
  final controller = TextEditingController();
  final lib = context.read<Library2DProvider>();
  final ed = context.read<EditorProvider>();

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Generate from Prompt', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. "orange cartoon tiger", "village girl in a blue kameez"',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Builds a clean, consistent 2D cartoon character on the universal rig — colors and type follow your description.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final prompt = controller.text.trim();
            if (prompt.isEmpty) return;
            final character = generateFromPrompt(lib, prompt);
            final nav = Navigator.of(dialogCtx);
            await lib.saveVariantFull(character);
            ed.loadCharacter(character.id);
            nav.pop();
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          },
          child: const Text('Generate'),
        ),
      ],
    ),
  );
  controller.dispose();
}

final _colorWords = <String, int>{
  'red': 0xFFD9534B, 'blue': 0xFF4C7BD9, 'green': 0xFF4C9A6A, 'yellow': 0xFFF2C14E,
  'orange': 0xFFF09A2E, 'purple': 0xFF8E6FC0, 'pink': 0xFFE4638F, 'black': 0xFF23262E,
  'white': 0xFFF3EEDF, 'brown': 0xFF8A5A36, 'gray': 0xFF7C8B99, 'grey': 0xFF7C8B99,
  'cyan': 0xFF3BB8C9, 'teal': 0xFF2E8B8B, 'maroon': 0xFF7A3030, 'navy': 0xFF2A3C66,
};

/// Prompt → character: picks the closest template (tiger for felines,
/// farmer/girl/teacher for humans) and recolors it from the words. The
/// generated character is saved as a variant of the original (never modifies
/// built-ins) and can be customized further.
Character2D generateFromPrompt(Library2DProvider lib, String prompt) {
  final p = prompt.toLowerCase();
  final isAnimal = _animalWords.any(p.contains);
  final baseSpec = isAnimal
      ? CharacterCatalog.tiger
      : p.contains('girl') || p.contains('woman') || p.contains('female')
          ? CharacterCatalog.villageGirl
          : p.contains('teacher') || p.contains('school') || p.contains('sir')
              ? CharacterCatalog.teacher
              : CharacterCatalog.farmer;

  final overrides = <String, Color>{};
  for (final e in _colorWords.entries) {
    if (p.contains(e.key)) {
      if (isAnimal) {
        overrides['fur'] = Color(e.value);
        overrides['skin'] = Color(e.value);
      } else {
        overrides['shirt'] = Color(e.value);
        overrides['skin'] = const Color(0xFFB07A54);
      }
      break;
    }
  }
  if (isAnimal && p.contains('stripe') || p.contains('black stripe')) {
    overrides['stripe'] = const Color(0xFF2E2620);
  }
  if (!isAnimal && (p.contains('lungi') || p.contains('farmer'))) {
    overrides['accent'] = const Color(0xFFD9532B);
  }

  final name = _titleCase(prompt.length > 28 ? prompt.substring(0, 28) : prompt);
  final now = DateTime.now();
  return Character2D(
    id: 'gen_${now.millisecondsSinceEpoch}',
    specId: baseSpec.id,
    name: name,
    palette: overrides,
    accessories: {...baseSpec.defaultAccessories},
    isVariant: true,
    createdAt: now,
  );
}

const _animalWords = ['tiger', 'cat', 'lion', 'dog', 'wolf', 'fox', 'cow', 'horse', 'elephant', 'animal', 'bear', 'deer'];

String _titleCase(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

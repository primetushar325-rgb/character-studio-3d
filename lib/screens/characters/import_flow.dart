import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/library_provider.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../player/player_screen.dart';

/// Opens the Android system file picker (Storage Access Framework) and runs
/// the full import pipeline: validate → copy/convert → parse → metadata →
/// success/error feedback. Real import, no permissions required.
Future<void> startImportFlow(BuildContext context) async {
  final scaffoldContext = context;
  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // .gltf + .bin + textures may be multi-selected for glTF imports.
      allowedExtensions: ['glb', 'gltf', 'bin', 'png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
      withData: false,
    );
  } catch (_) {
    if (scaffoldContext.mounted) {
      _showImportError(
        scaffoldContext,
        'The file picker could not be opened. Please try again.',
      );
    }
    return;
  }

  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) return; // user cancelled — not an error
  if (!scaffoldContext.mounted) return;

  final library = scaffoldContext.read<LibraryProvider>();

  // Show a loading overlay while parsing/copying.
  showDialog<void>(
    context: scaffoldContext,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const _ImportProgressDialog(),
  );

  final outcome = await library.repository.importFromPicker(files);

  if (!scaffoldContext.mounted) return;
  Navigator.of(scaffoldContext, rootNavigator: true).pop(); // close progress

  if (outcome.success && outcome.character != null) {
    final character = outcome.character!;
    // refresh the library list
    await library.reloadAfterImport();
    if (scaffoldContext.mounted) {
      await showPremiumDialog<void>(
        scaffoldContext,
        _ImportSuccessDialog(
          characterName: character.displayName,
          animationCount: character.animationCount,
          warnings: outcome.warnings,
          onOpen: () => Navigator.of(scaffoldContext).pop(),
          onAnimate: () {
            Navigator.of(scaffoldContext).pop();
            Navigator.of(scaffoldContext).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => PlayerScreen(
                  characterId: character.id,
                  initialAnimationName:
                      character.animations.isNotEmpty ? character.animations.first.name : null,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          },
        ),
      );
    }
  } else {
    if (scaffoldContext.mounted) {
      _showImportError(
          scaffoldContext, outcome.errorMessage ?? 'Unable to load this character.');
    }
  }
}

void _showImportError(BuildContext context, String message) {
  showPremiumDialog<void>(
    context,
    _ImportErrorDialog(message: message),
  );
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 18),
            Text('Importing Character…',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Validating model and detecting animations',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportSuccessDialog extends StatelessWidget {
  const _ImportSuccessDialog({
    required this.characterName,
    required this.animationCount,
    required this.warnings,
    this.onOpen,
    this.onAnimate,
  });

  final String characterName;
  final int animationCount;
  final List<String> warnings;
  final VoidCallback? onOpen;
  final VoidCallback? onAnimate;

  @override
  Widget build(BuildContext context) {
    return _OutcomeDialog(
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      title: 'Character Imported',
      message: '$characterName has been added successfully.',
      details: [
        '$animationCount ${animationCount == 1 ? 'animation' : 'animations'} detected',
        ...warnings,
      ],
      actions: [
        PremiumTextButton(label: 'Open', onPressed: onOpen),
        PremiumButton(
          label: 'Animate',
          onPressed: onAnimate,
          style: PremiumButtonStyle.primary,
          small: true,
          icon: Icons.play_arrow_rounded,
        ),
      ],
    );
  }
}

class _ImportErrorDialog extends StatelessWidget {
  const _ImportErrorDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _OutcomeDialog(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.danger,
      title: 'Unable to load this character',
      message: message,
      actions: [
        PremiumTextButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PremiumButton(
          label: 'Try Again',
          onPressed: () {
            Navigator.of(context).pop();
            startImportFlow(context);
          },
          small: true,
        ),
      ],
    );
  }
}

/// Shared styled dialog for import outcomes.
class _OutcomeDialog extends StatelessWidget {
  const _OutcomeDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.details = const [],
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<String> details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.12),
                border: Border.all(color: iconColor.withOpacity(0.35)),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  children: [
                    for (final d in details)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

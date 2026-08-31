import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../services/character_service.dart';
import '../../services/native_picker_service.dart';
import '../../state/library_provider.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import 'import_review_screen.dart';

/// Opens the Android system file picker and runs the staged import pipeline:
/// validate → parse → skeleton → animations → preview → review screen.
///
/// Picker strategy (no storage permissions needed):
///   1. Cross-platform file picker with .glb/.gltf (+ resource) filtering.
///   2. If it fails or returns no usable path → native ACTION_OPEN_DOCUMENT
///      fallback with glTF MIME filtering.
Future<void> startImportFlow(BuildContext context) async {
  final scaffoldContext = context;

  // ---- 1) pick files -----------------------------------------------------
  final paths = await _pickModelFiles(scaffoldContext);
  if (paths == null || paths.isEmpty) return; // cancelled / nothing usable
  if (!scaffoldContext.mounted) return;

  final library = scaffoldContext.read<LibraryProvider>();

  // ---- 2) staged progress UI ----------------------------------------------
  final stageNotifier = ValueNotifier<ImportStage>(ImportStage.reading);
  showDialog<void>(
    context: scaffoldContext,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _ImportProgressDialog(stage: stageNotifier),
  );

  final result = await library.stageImport(
    paths,
    onStage: (stage) => stageNotifier.value = stage,
  );

  if (!scaffoldContext.mounted) return;
  Navigator.of(scaffoldContext, rootNavigator: true).pop(); // close progress

  // ---- 3) route the outcome -------------------------------------------------
  if (result is StagedImport) {
    Navigator.of(scaffoldContext).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ImportReviewScreen(staged: result),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  } else if (result is ImportOutcome) {
    showPremiumDialog<void>(
      scaffoldContext,
      PremiumDialog(
        title: '❌ Invalid GLB file',
        message: result.errorMessage ??
            'This 3D model could not be loaded. Please choose a valid '
            'GLB/GLTF character.',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
        actions: [
          PremiumTextButton(
              label: 'Close', onPressed: () => Navigator.of(scaffoldContext).pop()),
          PremiumButton(
            label: 'Try Again',
            small: true,
            icon: Icons.refresh_rounded,
            onPressed: () {
              Navigator.of(scaffoldContext).pop();
              startImportFlow(scaffoldContext);
            },
          ),
        ],
      ),
    );
  }
}

/// Returns absolute paths of picked model files, or null/empty on cancel.
Future<List<String>?> _pickModelFiles(BuildContext context) async {
  // ---- primary: cross-platform picker with extension filtering ----------
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf', 'bin', 'png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
      withData: false,
    );
    final paths = <String>[
      for (final f in result?.files ?? const <PlatformFile>[])
        if (f.path != null && f.path!.isNotEmpty) f.path!
    ];
    if (paths.isNotEmpty) return paths;
    // Empty result with no exception = user closed the dialog.
    if (result != null) return const [];
  } catch (_) {
    // fall through to the native picker
  }

  // ---- fallback: native ACTION_OPEN_DOCUMENT with MIME filtering --------
  try {
    final picked = await NativePickerService.pickModelFile();
    if (picked == null) return const [];
    return [picked.path];
  } on Exception catch (e) {
    if (!context.mounted) return const [];
    showPremiumDialog<void>(
      context,
      PremiumDialog(
        title: 'File picker unavailable',
        message: e is PlatformException
            ? (e.message ?? 'The file picker could not be opened on this device.')
            : 'The file picker could not be opened on this device. Please try again.',
        icon: Icons.folder_off_rounded,
        iconColor: AppColors.danger,
        actions: [
          PremiumButton(
            label: 'Close',
            small: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    return const [];
  }
}

/// Staged progress dialog: "Reading file → Loading 3D model → Checking
/// skeleton → Checking animations → Preparing preview".
class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.stage});

  final ValueNotifier<ImportStage> stage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: ValueListenableBuilder<ImportStage>(
          valueListenable: stage,
          builder: (context, current, _) {
            final currentIndex = current.index;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
                const SizedBox(height: 20),
                Text('Importing Character…',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                for (final s in ImportStage.values)
                  _StageRow(
                    label: s.label,
                    state: s.index < currentIndex
                        ? _StageState.done
                        : s.index == currentIndex
                            ? _StageState.active
                            : _StageState.pending,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _StageState { pending, active, done }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});

  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (state) {
      case _StageState.done:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
      case _StageState.active:
        color = AppColors.accent;
        icon = Icons.radio_button_checked_rounded;
      case _StageState.pending:
        color = AppColors.textMuted;
        icon = Icons.radio_button_unchecked_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: state == _StageState.active
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  )
                : Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight:
                  state == _StageState.pending ? FontWeight.w600 : FontWeight.w800,
              color: state == _StageState.pending
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../export2d/export_service2d.dart';
import '../../scene/scene_renderer.dart';
import '../../state/editor_provider.dart';
import '../../state/library2d_provider.dart';
import '../../widgets/premium_button.dart';
import '../characters/character_picker_sheet.dart';
import 'export_share_bridge.dart';
import 'panels.dart';

/// The professional 16:9 2D animation editor. Canvas stays true 16:9 at any
/// screen size; all controls live outside the composition.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _transformationController = TransformationController();
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ed = context.read<EditorProvider>();
      final lib = context.read<Library2DProvider>();
      if (ed.controller == null && lib.all.isNotEmpty) {
        ed.loadCharacter(lib.all.first.id);
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    SystemChrome.setPreferredOrientations(_fullscreen ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(_fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final ed = context.watch<EditorProvider>();
    final isWide = MediaQuery.of(context).size.width > 720;

    if (_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onDoubleTap: _toggleFullscreen,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 5,
            child: Center(child: AspectRatio(aspectRatio: 16 / 9, child: _canvas(ed))),
          ),
        ),
      );
    }

    final canvas = AspectRatio(aspectRatio: 16 / 9, child: _canvas(ed));
    final panels = const EditorPanels();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: isWide
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _toolbar(ed),
                        Expanded(child: InteractiveViewer(transformationController: _transformationController, minScale: 0.5, maxScale: 5, child: Center(child: canvas))),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SizedBox(width: 380, child: panels),
                ],
              )
            : Column(
                children: [
                  _toolbar(ed),
                  InteractiveViewer(transformationController: _transformationController, minScale: 0.5, maxScale: 5, child: canvas),
                  Expanded(child: panels),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.surfaceAlt,
        onPressed: _toggleFullscreen,
        child: const Icon(Icons.fullscreen_rounded, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _canvas(EditorProvider ed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _ScenePainter(ed),
          ),
          // Drag to reposition the character on the canvas.
          GestureDetector(
            onPanUpdate: ed.controller == null
                ? null
                : (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final w = box.size.width;
                    final h = box.size.height;
                    ed.setTransform((t) {
                      t.x = (t.x + d.delta.dx / w).clamp(0.05, 0.95);
                      t.y = (t.y + d.delta.dy / h).clamp(0.1, 0.99);
                    });
                  },
            onDoubleTap: () => ed.setTransform((t) {
                  t.x = 0.5;
                  t.y = 0.78;
                  t.scale = 1;
                  t.rotation = 0;
                }),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(EditorProvider ed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${ed.projectName}  ·  ${ed.canvasWidth}×${ed.canvasHeight}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PremiumButton(
            label: 'Character',
            icon: Icons.person_rounded,
            small: true,
            onPressed: () => showCharacterPickerSheet(context),
          ),
          const SizedBox(width: 8),
          PremiumButton(
            label: 'Export',
            icon: Icons.movie_creation_rounded,
            small: true,
            style: PremiumButtonStyle.primary,
            onPressed: () => _openExport(context, ed),
          ),
        ],
      ),
    );
  }
}

Future<void> _openExport(BuildContext context, EditorProvider ed) async {
  if (ed.controller == null) return;
  showDialog<void>(context: context, builder: (_) => const ExportDialog());
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.ed) : super(repaint: ed.controller ?? ed);
  final EditorProvider ed;

  @override
  void paint(Canvas canvas, Size size) => paintScene(canvas, size, ed);

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => true;
}

/// The export dialog: type, preset, fps, quality, estimate, progress, done.
class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportType _type = ExportType.video;
  int _w = 1920;
  int _h = 1080;
  int _fps = 30;
  int _quality = 2;
  int _loops = 2;
  ExportProgress? _progress;
  ExportResult? _result;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final ed = context.watch<EditorProvider>();
    final clipDur = ed.controller?.animator.clipDuration ?? 2;
    final duration = clipDur * _loops;
    final estimate = _estimate(duration);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Export', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: _result != null
            ? _doneView()
            : _progress != null
                ? _progressView()
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _seg<ExportType>(
                          values: const [ExportType.video, ExportType.gif, ExportType.png, ExportType.pngSequence],
                          labels: const ['Video', 'GIF', 'PNG', 'Sequence'],
                          value: _type,
                          onChanged: (v) => setState(() => _type = v),
                        ),
                        const SizedBox(height: 12),
                        if (_type != ExportType.png) ...[
                          _seg<int>(values: const [1920, 1280, 854], labels: const ['1080p', '720p', '480p'], value: _w, onChanged: (v) => setState(() { _w = v; _h = (v * 9 / 16).round(); })),
                          const SizedBox(height: 12),
                          _seg<int>(values: const [24, 30, 60], labels: const ['24 FPS', '30 FPS', '60 FPS'], value: _fps, onChanged: (v) => setState(() => _fps = v)),
                          const SizedBox(height: 12),
                        ],
                        if (_type == ExportType.video)
                          _seg<int>(values: const [0, 1, 2, 3], labels: const ['Low', 'Medium', 'High', 'Ultra'], value: _quality, onChanged: (v) => setState(() => _quality = v)),
                        if (_type == ExportType.video) const SizedBox(height: 12),
                        if (_type != ExportType.png)
                          _seg<int>(values: const [1, 2, 3, 4], labels: const ['×1', '×2', '×3', '×4'], value: _loops, onChanged: (v) => setState(() => _loops = v)),
                        if (_type != ExportType.png) const SizedBox(height: 14),
                        Text(
                          _type == ExportType.png
                              ? 'Current frame · $_w×$_h · PNG'
                              : '${_type == ExportType.video ? 'H.264 MP4' : _type == ExportType.gif ? 'Animated GIF' : 'PNG sequence'}\n'
                                  '$_w×$_h · $_fps FPS · ${duration.toStringAsFixed(1)}s\n'
                                  '≈ ${estimate.isEmpty ? '' : estimate}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Renders the real composition frame-by-frame — never the screen.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        if (_result != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _share(_result!),
            child: const Text('Share'),
          ),
        ] else if (_progress == null) ...[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          PremiumButton(
            label: 'Export',
            style: PremiumButtonStyle.primary,
            small: true,
            onPressed: _running ? null : () => _start(context.read<EditorProvider>()),
          ),
        ],
      ],
    );
  }

  String _estimate(double duration) {
    switch (_type) {
      case ExportType.video:
        final mbps = [0.8, 1.5, 3, 6, 12][_quality.clamp(1, 3) + 1];
        return '${(mbps * duration / 8).toStringAsFixed(1)} MB';
      case ExportType.gif:
        return '${(640 * 360 * 0.28 * _fps * duration / 8 / 1024 / 1024 * 3).toStringAsFixed(1)} MB';
      default:
        return '';
    }
  }

  Widget _seg<T>({required List<T> values, required List<String> labels, required T value, required void Function(T) onChanged}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < values.length; i++)
          ChoiceChip(
            label: Text(labels[i], style: const TextStyle(fontSize: 12)),
            selected: value == values[i],
            onSelected: (_) => onChanged(values[i]),
            selectedColor: AppColors.accentSoft,
            backgroundColor: AppColors.surfaceAlt,
            labelStyle: TextStyle(color: value == values[i] ? AppColors.accent : AppColors.textSecondary),
            side: BorderSide(color: value == values[i] ? AppColors.accent : AppColors.stroke),
            showCheckmark: false,
          ),
      ],
    );
  }

  Future<void> _start(EditorProvider ed) async {
    setState(() => _running = true);
    final service = ExportService2D();
    try {
      final res = await service.export(
        ed: ed,
        type: _type,
        width: _w,
        height: _h,
        fps: _fps,
        quality: _quality,
        durationSeconds: ed.controller?.animator.clipDuration ?? 2,
        loops: _type == ExportType.png ? 1 : _loops,
        onProgress: (p) => setState(() => _progress = p),
      );
      // Save videos/GIFs into Movies (MediaStore) on Android.
      if (_type == ExportType.video || _type == ExportType.gif) {
        final bytes = await File(res.path).readAsBytes();
        final saved = await service.saveToMovies('2DStudio_${DateTime.now().millisecondsSinceEpoch}${_type == ExportType.video ? '.mp4' : '.gif'}', res.mime, bytes);
        if (saved != null) {
          setState(() => _progress = const ExportProgress(ExportPhase.finalizing, 1, 'Saved to Movies/2DCharacterStudio'));
        }
      }
      setState(() => _result = res);
    } catch (e) {
      setState(() => _progress = ExportProgress(ExportPhase.failed, 0, '$e'));
    } finally {
      setState(() => _running = false);
    }
  }

  Widget _progressView() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_progress!.message, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _progress!.phase == ExportPhase.done ? 1 : (_progress!.value <= 0 ? null : _progress!.value),
            backgroundColor: AppColors.surfaceAlt,
            color: _progress!.phase == ExportPhase.failed ? AppColors.danger : AppColors.accent,
          ),
          const SizedBox(height: 8),
          Text(
            _progress!.phase.name.toUpperCase(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1.2),
          ),
        ],
      );

  Widget _doneView() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 46),
          const SizedBox(height: 10),
          const Text('EXPORT COMPLETE', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            _result!.frameCount > 1 ? '${_result!.frameCount} frames · ${( _result!.fileBytes / 1048576).toStringAsFixed(1)} MB' : '${(_result!.fileBytes / 1024).toStringAsFixed(0)} KB',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          Text(_result!.path, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ],
      );

  Future<void> _share(ExportResult res) async {
    await shareExportFile(res.path, res.mime);
  }
}

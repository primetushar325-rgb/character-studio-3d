import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../export2d/export_service2d.dart';
import '../../scene/scene_renderer.dart';
import '../../project/project_document.dart';
import '../../scene/scene_object.dart';
import '../../scene/scene_renderer.dart' show objectBounds;
import '../../state/editor_provider.dart';
import '../../state/projects_provider.dart';
import '../../widgets/premium_button.dart';
import '../characters/character_picker_sheet.dart';
import 'background_picker.dart';
import 'export_share_bridge.dart';
import 'panels.dart';

/// The professional 16:9 2D animation editor. Canvas stays true 16:9 at any
/// screen size; all controls live outside the composition.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  final _transformationController = TransformationController();
  bool _fullscreen = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Phase 1: NO character is auto-loaded — a new project starts empty and
    // the user adds background/character from the tools. Existing projects
    // restore their saved character via ProjectsProvider.openProject.
    final ed = context.read<EditorProvider>();
    _applyOrientationLock(ed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lifecycle pause → flush the debounced save immediately.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      context.read<ProjectsProvider>().onAppPaused();
    }
  }

  /// The editor canvas ratio is fixed by the project; landscape projects get
  /// a true horizontal workspace, portrait locks portrait, square is free.
  void _applyOrientationLock(EditorProvider ed) {
    final o = ed.project?.orientation ?? ProjectOrientation.landscape16x9;
    final landscape = [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
    final portrait = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
    final any = [...portrait, ...landscape];
    SystemChrome.setPreferredOrientations(
        o == ProjectOrientation.landscape16x9 ? landscape : (o == ProjectOrientation.portrait9x16 ? portrait : any));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _leaveEditor() async {
    if (_closed) return;
    _closed = true;
    await context.read<ProjectsProvider>().closeCurrent();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformationController.dispose();
    // Restore free orientation for the shell screens.
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    SystemChrome.setEnabledSystemUIMode(_fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final ed = context.watch<EditorProvider>();
    final isWide = MediaQuery.of(context).size.width > 720;

    final aspect = ed.canvasWidth / ed.canvasHeight;

    if (_fullscreen) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) => _leaveEditor(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onDoubleTap: _toggleFullscreen,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 5,
              child: Center(child: AspectRatio(aspectRatio: aspect, child: _canvas(ed))),
            ),
          ),
        ),
      );
    }

    final canvas = AspectRatio(aspectRatio: aspect, child: _canvas(ed));
    final panels = const EditorPanels();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) => _leaveEditor(),
      child: Scaffold(
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
      ),
    );
  }

  Widget _canvas(EditorProvider ed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(builder: (context, cbox) {
        final csize = Size(cbox.maxWidth, cbox.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(size: Size.infinite, painter: _ScenePainter(ed)),

            // ---- Object interaction: tap-select + drag-move ----------------
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final obj = hitTestObjects(ed, d.localPosition, csize);
                ed.select(obj?.id);
              },
              onPanUpdate: (d) {
                final id = ed.selectedId;
                if (id == null) return;
                ed.updateTransform(id, (t) {
                  t.x = (t.x + d.delta.dx / csize.width).clamp(-0.2, 1.2);
                  t.y = (t.y + d.delta.dy / csize.height).clamp(-0.2, 1.2);
                });
              },
              onDoubleTap: () {
                final id = ed.selectedId;
                if (id != null) ed.updateTransform(id, (t) {
                  t.x = 0.5;
                  t.rotation = 0;
                });
              },
            ),

            // ---- Selection overlay (bounds + handles + delete) -------------
            if (ed.selected != null)
              _SelectionOverlay(
                ed: ed,
                object: ed.selected!,
                canvasSize: csize,
                viewScale: _transformationController.value.getMaxScaleOnAxis(),
              ),
          ],
        );
      }),
    );
  }

  void _addText(EditorProvider ed) {
    final obj = ed.addText();
    _editText(obj);
  }

  void _editText(SceneObject obj) {
    final controller = TextEditingController(text: obj.text);
    showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Text', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Your text', hintStyle: TextStyle(color: AppColors.textMuted)),
              onChanged: (_) => setD(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final w in [400, 700, 900])
                  ChoiceChip(
                    label: Text(['Regular', 'Bold', 'Black'][w == 400 ? 0 : w == 700 ? 1 : 2], style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    selected: obj.fontWeight == w,
                    onSelected: (_) => setD(() => obj.fontWeight = w),
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                for (final fs in [40, 64, 96, 140])
                  ChoiceChip(
                    label: Text('$fs', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    selected: obj.fontSize == fs.toDouble(),
                    onSelected: (_) => setD(() => obj.fontSize = fs.toDouble()),
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                context.read<EditorProvider>().updateObject(obj.id, (o) => o.text = controller.text.isEmpty ? 'Text' : controller.text);
                Navigator.pop(d);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _pickShape(EditorProvider ed) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('Add Shape', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final (k, icon) in [
              ('rect', Icons.crop_square_rounded),
              ('circle', Icons.circle_outlined),
              ('line', Icons.horizontal_rule_rounded),
            ])
              Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  icon: Icon(icon, color: AppColors.accent),
                  onPressed: () {
                    ed.addShape(k);
                    Navigator.pop(context);
                  },
                ),
              ),
          ]),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _toolbar(EditorProvider ed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 22),
            onPressed: _leaveEditor,
            tooltip: 'Save & close project',
          ),
          Expanded(
            child: Text(
              '${ed.projectName}  ·  ${ed.canvasWidth}×${ed.canvasHeight}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PremiumButton(label: 'Char', icon: Icons.person_add_rounded, small: true, onPressed: () => showCharacterPickerSheet(context)),
          const SizedBox(width: 4),
          PremiumButton(label: 'Image', icon: Icons.image_rounded, small: true, onPressed: () => pickImageObject(context)),
          const SizedBox(width: 4),
          PremiumButton(label: 'Text', icon: Icons.text_fields_rounded, small: true, onPressed: () => _addText(ed)),
          const SizedBox(width: 4),
          PremiumButton(label: 'Shape', icon: Icons.category_rounded, small: true, onPressed: () => _pickShape(ed)),
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
  // Exports the real composition — a background-only project (no character
  // yet) still exports exactly what the canvas shows.
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

  @override
  void initState() {
    super.initState();
    final ed = context.read<EditorProvider>();
    _w = ed.canvasWidth;
    _h = ed.canvasHeight;
  }
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
    // Presets follow the project orientation (16:9 / 9:16 / 1:1); smaller
    // presets stay available exactly as before for landscape.
    final portrait = ed.canvasHeight > ed.canvasWidth;
    final square = ed.canvasWidth == ed.canvasHeight;
    final presets = portrait || square ? const [1080, 720, 480] : const [1920, 1280, 854];
    final presetLabels = const ['1080p', '720p', '480p'];

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
                          _seg<int>(
                            values: presets,
                            labels: presetLabels,
                            value: _w,
                            onChanged: (v) => setState(() {
                              _w = v;
                              _h = square ? v : portrait ? (v * 16 / 9).round() : (v * 9 / 16).round();
                            }),
                          ),
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

/// Topmost-first hit test on the editor canvas (z-order respected).
SceneObject? hitTestObjects(EditorProvider ed, Offset point, Size canvasSize) {
  final sorted = [...ed.objects]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
  for (final o in sorted) {
    if (!o.visible) continue;
    if (objectBounds(o, canvasSize).inflate(4).contains(point)) return o;
  }
  return null;
}

/// Selection bounds + scale/rotate/delete handles drawn INSIDE the canvas
/// coordinate space (so they track zoom/pan). Only the composition below is
/// ever exported — this overlay lives in the widget tree, not the renderer.
class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({
    required this.ed,
    required this.object,
    required this.canvasSize,
    required this.viewScale,
  });

  final EditorProvider ed;
  final SceneObject object;
  final Size canvasSize;
  final double viewScale;

  static const _handle = 26.0;

  double _px(double v) => _handle / viewScale; // constant screen-size handles

  @override
  Widget build(BuildContext context) {
    if (!object.visible) return const SizedBox.shrink();
    final bounds = objectBounds(object, canvasSize).deflate(0);
    final hs = _px(1) / 2;

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: bounds,
            child: CustomPaint(painter: _MarchingBounds(object.locked)),
          ),
          // Corner handle (bottom-right): drag = scale X/Y together.
          Positioned(
            left: bounds.right - hs,
            top: bounds.bottom - hs,
            width: _px(1),
            height: _px(1),
            child: GestureDetector(
              onPanUpdate: (d) {
                final c = bounds.center;
                final before = (bounds.bottomRight - c).distance;
                final after = ((bounds.bottomRight + d.delta) - c).distance;
                if (before <= 0) return;
                final k = (after / before).clamp(0.5, 2.0);
                ed.updateTransform(object.id, (t) {
                  t.scaleX = (t.scaleX * k).clamp(0.05, 20);
                  t.scaleY = (t.scaleY * k).clamp(0.05, 20);
                });
              },
              child: Container(
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ),
          // Top handle: drag = rotate.
          Positioned(
            left: bounds.center.dx - hs,
            top: bounds.top - _px(1) * 1.4,
            width: _px(1),
            height: _px(1),
            child: GestureDetector(
              onPanUpdate: (d) {
                ed.updateTransform(object.id, (t) {
                  t.rotation += d.delta.dx / 2;
                });
              },
              child: Container(
                decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 2)),
                child: const Icon(Icons.rotate_right_rounded, size: 14, color: AppColors.accent),
              ),
            ),
          ),
          // Delete handle (top-right of bounds).
          Positioned(
            left: bounds.right - hs,
            top: bounds.top - hs,
            width: _px(1),
            height: _px(1),
            child: GestureDetector(
              onTap: () => ed.removeObject(object.id),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFFE2574C), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarchingBounds extends CustomPainter {
  _MarchingBounds(this.locked);
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = locked ? const Color(0xFF9AA3B8) : const Color(0xFF66A6FF);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)), paint);
    if (locked) {
      final tp = TextPainter(
        text: const TextSpan(text: 'LOCKED', style: TextStyle(color: Color(0xFF9AA3B8), fontSize: 9, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MarchingBounds oldDelegate) => oldDelegate.locked != locked;
}

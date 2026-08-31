import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_names.dart';
import '../../core/utils/formatters.dart';
import '../../models/animation_clip.dart';
import '../../models/character.dart';
import '../../models/viewer_enums.dart';
import '../../state/export_provider.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/animated_icon_button.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/error_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../characters2d/engine/face_rig.dart';
import '../../state/library2d_provider.dart';
import '../../widgets/three_d_viewer.dart';
import 'stage2d_body.dart';
import '../../widgets/thumbnail.dart';
import '../actions/action_select_screen.dart';
import '../export/export_screen.dart';

/// Full-screen premium 3D animation player.
///
/// Generic: takes a characterId + optional animation name (original clip
/// identifier) and plays it. Works for every GLB in the library.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    this.characterId = '',
    this.initialAnimationName,
    this.projectBackground,
    this.projectCustomHex,
    this.projectLighting,
    this.projectOrbit,
    this.projectAutoRotate,
    this.openExportOnReady = false,
    this.character2dId,
    this.initial2dAction = 'stand',
    this.initial2dExpr,
    this.initial2dSpeed = 1.0,
    this.initial2dDirectionLeft = false,
  });

  final String characterId;

  /// When set, the player runs in 2D cartoon mode (Stage2DBody) — the 3D
  /// GLB pipeline is never touched.
  final String? character2dId;
  final String initial2dAction;
  final Expr? initial2dExpr;
  final double initial2dSpeed;
  final bool initial2dDirectionLeft;
  final String? initialAnimationName;
  final BackgroundPreset? projectBackground;
  final String? projectCustomHex;
  final LightingPreset? projectLighting;
  final String? projectOrbit;
  final bool? projectAutoRotate;
  final bool openExportOnReady;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final ThreeDController _viewer;
  StreamSubscription<ViewerEvent>? _eventsSub;

  bool _modelLoadTriggered = false;
  bool _controlsReady = false;
  bool _animationErrorShown = false;
  bool _thumbnailDone = false;

  BackgroundPreset _background = BackgroundPreset.studio;
  String? _customHex;
  LightingPreset _lighting = LightingPreset.studio;
  bool _autoRotate = false;
  bool _gridVisible = false;
  bool _panEnabled = true;
  bool _fullscreen = false;

  bool get _is2D => widget.character2dId != null;

  @override
  void initState() {
    super.initState();
    if (_is2D) return; // 2D mode needs no WebView controller.
    _viewer = ThreeDController();
    _eventsSub = _viewer.events.listen(_onViewerEvent);
  }

  @override
  void dispose() {
    if (_is2D) {
      super.dispose();
      return;
    }
    _eventsSub?.cancel();
    try {
      final export = context.read<ExportProvider>();
      if (export.phase == ExportPhase.recording) {
        export.stopRecording();
      }
    } catch (_) {}
    // Dispose model + controller → frees WebView + GPU resources.
    _viewer.disposeModel();
    _viewer.dispose();
    super.dispose();
  }

  void _onViewerEvent(ViewerEvent event) {
    if (!mounted) return;
    if (event.type == 'load') {
      _onModelReady();
    } else if (event.type == 'error') {
      setState(() {}); // show error overlay
    }
  }

  Future<void> _onModelReady() async {
    if (_controlsReady) return;
    _controlsReady = true;

    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final library = context.read<LibraryProvider>();
    final character = library.byId(widget.characterId);
    if (character == null) return;

    // Apply persisted defaults + optional project overrides.
    _background = widget.projectBackground ?? _background;
    _customHex = widget.projectCustomHex ?? _customHex;
    _lighting = widget.projectLighting ?? _lighting;
    _autoRotate = widget.projectAutoRotate ?? settings.autoRotateCamera;

    await _viewer.applyBackground(_background, customHex: _customHex);
    await _viewer.applyLighting(_lighting);
    await _viewer.setGridVisible(_gridVisible);
    await _viewer.setPanEnabled(_panEnabled);
    await _viewer.setPlaybackSpeed(settings.defaultSpeed);
    await _viewer.setLoop(settings.autoLoop);
    await _viewer.setAutoRotateCamera(_autoRotate);
    if (widget.projectOrbit != null) {
      await _viewer.setCameraOrbit(widget.projectOrbit!);
    }

    // Verify the requested clip exists; fall back to the first one.
    var animationName = widget.initialAnimationName;
    if (animationName != null && character.clipByName(animationName) == null) {
      if (!_animationErrorShown && widget.initialAnimationName != null) {
        _animationErrorShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAnimationUnavailable();
        });
      }
      animationName = null;
    }
    animationName ??=
        character.animations.isNotEmpty ? character.animations.first.name : null;

    if (animationName != null) {
      await _viewer.playAnimation(character.serverModelPath, animationName,
          loop: settings.autoLoop);
      library.recordUsage(character, animationName);
    }

    _maybeCaptureThumbnail(character);

    if (widget.openExportOnReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openExport(character);
      });
    }
    setState(() {});
  }

  void _showAnimationUnavailable() {
    showPremiumDialog<void>(
      context,
      PremiumDialog(
        title: 'Animation unavailable',
        message:
            'The selected animation could not be played. It may not exist in this '
            'version of the model.',
        icon: Icons.animation_outlined,
        actions: [
          PremiumTextButton(
            label: 'Choose Another Animation',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _maybeCaptureThumbnail(Character character) async {
    if (_thumbnailDone) return;
    final settings = context.read<SettingsProvider>();
    final library = context.read<LibraryProvider>();
    if (!settings.autoThumbnails) return;
    if (character.thumbnailPath != null) {
      _thumbnailDone = true;
      return;
    }
    // Give the renderer a moment to draw the first frame.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _viewer.state != ViewerLoadState.ready) return;
    final dataUrl = await _viewer.captureThumbnail();
    if (dataUrl == null) return;
    final file = await library.repository.thumbnails
        .saveDataUrlFor(dataUrl, character.fileName);
    if (file != null) {
      _thumbnailDone = true;
      await library.updateThumbnail(character.id, file.path);
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_is2D) {
      final library2d = context.watch<Library2DProvider>();
      final character2d = library2d.byId(widget.character2dId!);
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          title: Text(
            character2d?.name ?? '2D Character',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: character2d == null
            ? Center(
                child: Text(
                  'Character data could not be loaded.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            : Stage2DBody(
                character: character2d,
                initialAction: widget.initial2dAction,
                initialExpr: widget.initial2dExpr ?? Expr.neutral,
                initialSpeed: widget.initial2dSpeed,
                initialDirectionLeft: widget.initial2dDirectionLeft,
              ),
      );
    }
    final library = context.watch<LibraryProvider>();
    final export = context.watch<ExportProvider>();
    final character = library.byId(widget.characterId);

    if (character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D Player')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorView(
              title: 'Character not found',
              message:
                  'This character is no longer available in the library. '
                  'It may have been deleted.',
              onRetry: () => Navigator.of(context).maybePop(),
              retryLabel: 'Go Back',
            ),
          ),
        ),
      );
    }

    // Trigger the initial model load exactly once.
    if (!_modelLoadTriggered) {
      _modelLoadTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewer.loadCharacter(character);
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!_fullscreen)
              _TopBar(
                viewer: _viewer,
                character: character,
                onExport: () => _openExport(character),
                onCapturePoster: () => _capturePoster(character),
                onToggleFullscreen: () => setState(() => _fullscreen = true),
              ),
            if (_fullscreen)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 12, 0),
                  child: AnimatedIconButton(
                    icon: Icons.close_fullscreen_rounded,
                    tooltip: 'Exit fullscreen',
                    semanticLabel: 'Exit fullscreen preview',
                    background: AppColors.surfaceAlt,
                    onPressed: () => setState(() => _fullscreen = false),
                  ),
                ),
              ),
            // ---- 3D stage ----
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                child: Stack(
                    children: [
                      Positioned.fill(child: ThreeDViewer(controller: _viewer)),
                      if (_viewer.state == ViewerLoadState.loading)
                        Positioned.fill(
                          child: _PlayerLoadingOverlay(
                              name: character.displayName,
                              progress: _viewer.progress),
                        ),
                      if (_viewer.state == ViewerLoadState.error)
                        Positioned.fill(
                          child: _PlayerErrorOverlay(viewer: _viewer),
                        ),
                      if (export.phase == ExportPhase.recording)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: _RecordingBadge(
                            startedAt: export.startedAt,
                            plannedSeconds: export.plannedSeconds,
                            onStop: () => export.stopRecording(),
                          ),
                        ),
                      const Positioned(
                        left: 0,
                        top: 0,
                        child: _ExportResultWatcher(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ---- control deck ----
            if (!_fullscreen)
              _ControlDeck(
                viewer: _viewer,
                character: character,
                background: _background,
                lighting: _lighting,
                autoRotate: _autoRotate,
                gridVisible: _gridVisible,
                panEnabled: _panEnabled,
                onBackgroundChanged: (preset, hex) {
                  setState(() {
                    _background = preset;
                    _customHex = hex;
                  });
                  _viewer.applyBackground(preset, customHex: hex);
                },
                onLightingChanged: (preset) {
                  setState(() => _lighting = preset);
                  _viewer.applyLighting(preset);
                },
                onAutoRotateChanged: (v) {
                  setState(() => _autoRotate = v);
                  _viewer.setAutoRotateCamera(v);
                },
                onGridChanged: (v) {
                  setState(() => _gridVisible = v);
                  _viewer.setGridVisible(v);
                },
                onPanChanged: (v) {
                  setState(() => _panEnabled = v);
                  _viewer.setPanEnabled(v);
                },
                onResetCamera: () => _viewer.resetCamera(),
              ),
          ],
        ),
      ),
    );
  }

  void _openExport(Character character) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ExportScreen(
          character: character,
          currentAnimationName: _viewer.currentAnimationName,
          onPrepareBackground: (preset, hex) {
            _viewer.applyBackground(preset, customHex: hex);
          },
          onRestartAnimation: () {
            _viewer.setLoop(true);
            _viewer.restartAnimation();
          },
        ),
        fullscreenDialog: true,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }

  Future<void> _capturePoster(Character character) async {
    if (_viewer.state != ViewerLoadState.ready) return;
    final export = context.read<ExportProvider>();
    final dataUrl = await _viewer.captureThumbnail();
    if (dataUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture the frame right now.')),
        );
      }
      return;
    }
    try {
      await export.savePoster(dataUrl, character.displayName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster saved to your gallery.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster could not be saved.')),
        );
      }
    }
  }
}

// ======================================================================
// Export result watcher — surfaces the finished/failed recording while the
// player is on screen (the export sheet has already popped by then).
// ======================================================================
class _ExportResultWatcher extends StatefulWidget {
  const _ExportResultWatcher();

  @override
  State<_ExportResultWatcher> createState() => _ExportResultWatcherState();
}

class _ExportResultWatcherState extends State<_ExportResultWatcher> {
  ExportPhase? _lastPhase;

  @override
  Widget build(BuildContext context) {
    final export = context.watch<ExportProvider>();
    if (export.phase != _lastPhase) {
      final previous = _lastPhase;
      _lastPhase = export.phase;
      if (previous != null &&
          previous != export.phase &&
          export.phase == ExportPhase.done) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSuccess(context, export);
        });
      } else if (previous != null &&
          export.phase == ExportPhase.error &&
          export.error != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(export.error!)),
            );
          }
        });
      }
    }
    return const SizedBox.shrink();
  }

  void _showSuccess(BuildContext context, ExportProvider export) {
    final uri = export.lastEvent?.uri ?? '';
    showPremiumDialog<void>(
      context,
      PremiumDialog(
        title: 'Video exported successfully.',
        message:
            'Saved to your gallery (Movies/Character Studio 3D) · '
            '${Formatters.fileSize(export.lastEvent?.sizeBytes ?? 0)}.',
        icon: Icons.videocam_rounded,
        iconColor: const Color(0xFF6BD9A5),
        actions: [
          PremiumTextButton(
            label: 'Open',
            onPressed: uri.isEmpty
                ? null
                : () {
                    export.service.openMedia(uri);
                  },
          ),
          PremiumTextButton(
            label: 'Share',
            onPressed: uri.isEmpty
                ? null
                : () {
                    export.service.shareMedia(uri);
                  },
          ),
          PremiumButton(
            label: 'Done',
            small: true,
            onPressed: () {
              export.reset();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Top bar
// ======================================================================
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.viewer,
    required this.character,
    required this.onExport,
    required this.onCapturePoster,
    required this.onToggleFullscreen,
  });

  final ThreeDController viewer;
  final Character character;
  final VoidCallback onExport;
  final VoidCallback onCapturePoster;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return ListenableBuilder(
      listenable: viewer,
      builder: (context, _) {
        final playingName = viewer.currentAnimationName;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              const BackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      playingName == null
                          ? 'Free view'
                          : 'Playing · ${playingName.split('|').last}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FavoriteHeart(
                favorite: character.isFavorite,
                onToggle: () => library.toggleFavorite(character),
                size: 21,
              ),
              AnimatedIconButton(
                icon: Icons.photo_camera_outlined,
                tooltip: 'Save poster frame',
                semanticLabel: 'Save poster frame to gallery',
                onPressed: onCapturePoster,
              ),
              AnimatedIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Export video',
                semanticLabel: 'Export animation as video',
                onPressed: onExport,
              ),
              AnimatedIconButton(
                icon: Icons.fullscreen_rounded,
                tooltip: 'Fullscreen preview',
                semanticLabel: 'Toggle fullscreen preview',
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ======================================================================
// Loading / error overlays
// ======================================================================
class _PlayerLoadingOverlay extends StatelessWidget {
  const _PlayerLoadingOverlay({required this.name, required this.progress});

  final String name;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 16),
            Text('Loading 3D Character...',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            SizedBox(
              width: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerErrorOverlay extends StatelessWidget {
  const _PlayerErrorOverlay({required this.viewer});

  final ThreeDController viewer;

  @override
  Widget build(BuildContext context) {
    final character = viewer.character;
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: ErrorView(
            title: 'Animation unavailable',
            message:
                'The selected character could not be rendered. The GLB may be '
                'corrupted or use an unsupported feature.',
            onRetry: () {
              if (character != null) viewer.loadCharacter(character);
            },
            retryLabel: 'Try Again',
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Recording badge
// ======================================================================
class _RecordingBadge extends StatefulWidget {
  const _RecordingBadge({
    required this.startedAt,
    required this.plannedSeconds,
    required this.onStop,
  });

  final DateTime? startedAt;
  final int plannedSeconds;
  final VoidCallback onStop;

  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge> {
  Timer? _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.plannedSeconds > 0 ? widget.plannedSeconds - _elapsed : null;
    final blink = _elapsed % 2 == 0;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 14,
      blur: 14,
      shadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: blink ? 1.0 : 0.25,
            duration: const Duration(milliseconds: 450),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'REC ${Formatters.clock(_elapsed.toDouble())}'
            '${remaining != null && remaining > 0 ? '  ·  ${remaining}s left' : ''}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: 'Stop recording',
            button: true,
            child: GestureDetector(
              onTap: widget.onStop,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.stop_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Control deck
// ======================================================================
class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.viewer,
    required this.character,
    required this.background,
    required this.lighting,
    required this.autoRotate,
    required this.gridVisible,
    required this.panEnabled,
    required this.onBackgroundChanged,
    required this.onLightingChanged,
    required this.onAutoRotateChanged,
    required this.onGridChanged,
    required this.onPanChanged,
    required this.onResetCamera,
  });

  final ThreeDController viewer;
  final Character character;
  final BackgroundPreset background;
  final LightingPreset lighting;
  final bool autoRotate;
  final bool gridVisible;
  final bool panEnabled;
  final void Function(BackgroundPreset preset, String? customHex) onBackgroundChanged;
  final ValueChanged<LightingPreset> onLightingChanged;
  final ValueChanged<bool> onAutoRotateChanged;
  final ValueChanged<bool> onGridChanged;
  final ValueChanged<bool> onPanChanged;
  final VoidCallback onResetCamera;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
              color: isDark ? AppColors.stroke : AppColors.lightStroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListenableBuilder(
          listenable: viewer,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimationStrip(viewer: viewer, character: character),
              const SizedBox(height: 12),
              _ProgressRow(viewer: viewer),
              const SizedBox(height: 10),
              _TransportRow(viewer: viewer),
              const SizedBox(height: 12),
              SizedBox(
                height: 74,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _stageTile(
                      context,
                      icon: background.icon,
                      label: 'Background',
                      value: background == BackgroundPreset.custom
                          ? 'Custom'
                          : background.label,
                      onTap: () => _pickBackground(context),
                    ),
                    _stageTile(
                      context,
                      icon: lighting.icon,
                      label: 'Lighting',
                      value: lighting.label,
                      onTap: () => _pickLighting(context),
                    ),
                    _stageTile(
                      context,
                      icon: autoRotate
                          ? Icons.screen_rotation_rounded
                          : Icons.center_focus_strong_rounded,
                      label: 'Camera',
                      value: autoRotate ? 'Auto-rotate' : 'Manual',
                      onTap: () => onAutoRotateChanged(!autoRotate),
                    ),
                    _stageTile(
                      context,
                      icon: gridVisible
                          ? Icons.grid_on_rounded
                          : Icons.grid_off_rounded,
                      label: 'Grid',
                      value: gridVisible ? 'On' : 'Off',
                      onTap: () => onGridChanged(!gridVisible),
                    ),
                    _stageTile(
                      context,
                      icon: panEnabled
                          ? Icons.pan_tool_rounded
                          : Icons.pan_tool_alt_outlined,
                      label: 'Pan',
                      value: panEnabled ? 'On' : 'Off',
                      onTap: () => onPanChanged(!panEnabled),
                    ),
                    _stageTile(
                      context,
                      icon: Icons.filter_center_focus_rounded,
                      label: 'Reset',
                      value: 'Camera',
                      onTap: onResetCamera,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickBackground(BuildContext context) async {
    final result = await showModalBottomSheet<(BackgroundPreset, String?)>(
      context: context,
      builder: (sheetContext) => _BackgroundSheet(initial: background),
    );
    if (result != null) onBackgroundChanged(result.$1, result.$2);
  }

  Future<void> _pickLighting(BuildContext context) async {
    final result = await showModalBottomSheet<LightingPreset>(
      context: context,
      builder: (sheetContext) => _LightingSheet(initial: lighting),
    );
    if (result != null) onLightingChanged(result);
  }

  Widget _stageTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 84,
        child: _OptionTile(
          icon: icon,
          label: label,
          value: value,
          onTap: onTap,
        ),
      ),
    );
  }
}

// ======================================================================
// Animation strip
// ======================================================================
class _AnimationStrip extends StatelessWidget {
  const _AnimationStrip({required this.viewer, required this.character});

  final ThreeDController viewer;
  final Character character;

  @override
  Widget build(BuildContext context) {
    if (character.animations.isEmpty) {
      return Row(
        children: [
          Icon(Icons.animation_outlined,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No animations detected in this model — free 3D view only',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // ---- standard actions (enabled when mapped, disabled "—") ----
          for (final action in StandardAction.all)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StandardChip(
                action: action,
                clipName: character.animationMapping[action],
                selected: _isStandardSelected(action),
                onTap: () => _playStandard(context, action),
              ),
            ),
          // ---- divider + every detected clip ----
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            color: AppColors.stroke,
          ),
          for (final clip in character.animations)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _AnimationChip(
                clip: clip,
                selected: viewer.currentAnimationName == clip.name,
                onTap: () {
                  final library = context.read<LibraryProvider>();
                  viewer.playAnimation(character.serverModelPath, clip.name,
                      loop: viewer.loop);
                  library.recordUsage(character, clip.name);
                },
              ),
            ),
        ],
      ),
    );
  }

  bool _isStandardSelected(String action) {
    final mapped = character.animationMapping[action];
    return mapped != null && mapped == viewer.currentAnimationName;
  }

  void _playStandard(BuildContext context, String action) {
    final clip = character.clipForAction(action);
    if (clip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${StandardAction.label(action)} animation is not available for this character.'),
          action: SnackBarAction(
            label: 'Use another',
            onPressed: () => Navigator.of(context).push(
              fadeSlideRoute(ActionSelectScreen(characterId: character.id)),
            ),
          ),
        ),
      );
      return;
    }
    final library = context.read<LibraryProvider>();
    viewer.playAnimation(character.serverModelPath, clip.name, loop: viewer.loop);
    library.recordUsage(character, clip.name);
  }
}

/// Standard action chip: ✓ when mapped, "—" when unavailable.
class _StandardChip extends StatelessWidget {
  const _StandardChip({
    required this.action,
    required this.clipName,
    required this.selected,
    required this.onTap,
  });

  final String action;
  final String? clipName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = clipName != null && clipName!.isNotEmpty;
    return Semantics(
      label:
          '${StandardAction.label(action)} ${enabled ? 'play' : 'not available for this character'}',
      button: true,
      enabled: enabled,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: !enabled
                ? AppColors.surfaceAlt
                : selected
                    ? AppColors.accent
                    : AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !enabled
                  ? AppColors.stroke
                  : selected
                      ? AppColors.accent
                      : AppColors.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.check_rounded : Icons.remove_rounded,
                size: 14,
                color: !enabled
                    ? AppColors.textMuted
                    : selected
                        ? const Color(0xFF0A0C11)
                        : AppColors.accent,
              ),
              const SizedBox(width: 5),
              Text(
                StandardAction.label(action),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: !enabled
                      ? AppColors.textMuted
                      : selected
                          ? const Color(0xFF0A0C11)
                          : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimationChip extends StatelessWidget {
  const _AnimationChip({
    required this.clip,
    required this.selected,
    required this.onTap,
  });

  final AnimationClip clip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = animationIconFor(
        clip.knownAction ? clip.normalizedName : clip.displayName);
    return Semantics(
      label: 'Play ${clip.displayName}',
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? const Color(0xFF0A0C11) : AppColors.accent),
              const SizedBox(width: 6),
              Text(
                clip.displayName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color:
                      selected ? const Color(0xFF0A0C11) : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Progress row
// ======================================================================
class _ProgressRow extends StatefulWidget {
  const _ProgressRow({required this.viewer});

  final ThreeDController viewer;

  @override
  State<_ProgressRow> createState() => _ProgressRowState();
}

class _ProgressRowState extends State<_ProgressRow> {
  double? _scrubValue;

  @override
  Widget build(BuildContext context) {
    final viewer = widget.viewer;
    final duration = viewer.duration > 0 ? viewer.duration : 1.0;
    final current = _scrubValue ?? viewer.currentTime.clamp(0.0, duration);

    return Row(
      children: [
        Text(
          Formatters.clock(current),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: current.clamp(0.0, duration),
              max: duration,
              onChangeStart: (v) => setState(() => _scrubValue = v),
              onChanged: (v) => setState(() => _scrubValue = v),
              onChangeEnd: (v) {
                setState(() => _scrubValue = null);
                widget.viewer.seekTo(v);
              },
            ),
          ),
        ),
        Text(
          Formatters.clock(duration == 1.0 && viewer.duration <= 0 ? 0 : duration),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ======================================================================
// Transport row
// ======================================================================
class _TransportRow extends StatelessWidget {
  const _TransportRow({required this.viewer});

  final ThreeDController viewer;

  @override
  Widget build(BuildContext context) {
    final playing = viewer.isPlaying;
    final hasAnimation = viewer.hasAnimationSelected;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        AnimatedIconButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Restart',
          semanticLabel: 'Restart animation',
          onPressed: hasAnimation ? () => viewer.restartAnimation() : null,
        ),
        _PlayButton(
          playing: playing,
          hasAnimation: hasAnimation,
          onToggle: () {
            if (playing) {
              viewer.pauseAnimation();
            } else {
              viewer.resumeAnimation();
            }
          },
        ),
        AnimatedIconButton(
          icon: Icons.stop_rounded,
          tooltip: 'Stop',
          semanticLabel: 'Stop animation',
          onPressed: hasAnimation ? () => viewer.stopAnimation() : null,
        ),
        AnimatedIconButton(
          icon: viewer.loop ? Icons.repeat_rounded : Icons.repeat_one_outlined,
          tooltip: viewer.loop ? 'Loop on' : 'Loop off',
          semanticLabel: 'Toggle loop',
          active: viewer.loop,
          onPressed: () => viewer.setLoop(!viewer.loop),
        ),
        AnimatedIconButton(
          icon: Icons.filter_center_focus_rounded,
          tooltip: 'Reset camera (or double-tap stage)',
          semanticLabel: 'Reset camera',
          onPressed: () => viewer.resetCamera(),
        ),
        _SpeedButton(viewer: viewer),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.hasAnimation,
    required this.onToggle,
  });

  final bool playing;
  final bool hasAnimation;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: playing ? 'Pause' : 'Play',
      button: true,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 32,
            color: const Color(0xFF0A0C11),
          ),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.viewer});

  final ThreeDController viewer;

  static const _speeds = [0.25, 0.5, 1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Playback speed',
      button: true,
      child: PopupMenuButton<double>(
        tooltip: 'Playback speed',
        position: PopupMenuPosition.over,
        color: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (speed) => viewer.setPlaybackSpeed(speed),
        itemBuilder: (context) => [
          for (final speed in _speeds)
            PopupMenuItem(
              value: speed,
              child: Row(
                children: [
                  if (viewer.speed == speed)
                    const Icon(Icons.check_rounded,
                        size: 17, color: AppColors.accent)
                  else
                    const SizedBox(width: 17),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatSpeed(speed)}x',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Text(
            '${_formatSpeed(viewer.speed)}x',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accent),
          ),
        ),
      ),
    );
  }

  String _formatSpeed(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();
}

// ======================================================================
// Option tiles + sheets
// ======================================================================
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: -0.1),
              ),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundSheet extends StatefulWidget {
  const _BackgroundSheet({required this.initial});

  final BackgroundPreset initial;

  @override
  State<_BackgroundSheet> createState() => _BackgroundSheetState();
}

class _BackgroundSheetState extends State<_BackgroundSheet> {
  late BackgroundPreset _selected;
  String? _customHex;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stage Background',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final preset in BackgroundPreset.values)
                  _PresetChip(
                    icon: preset.icon,
                    label: preset.label,
                    selected: _selected == preset,
                    onTap: () async {
                      if (preset == BackgroundPreset.custom) {
                        final hex = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const ColorPickerSheet(),
                        );
                        if (hex == null) return;
                        setState(() {
                          _selected = preset;
                          _customHex = hex;
                        });
                      } else {
                        setState(() => _selected = preset);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            PremiumButton(
              label: 'Apply',
              icon: Icons.check_rounded,
              style: PremiumButtonStyle.primary,
              onPressed: () => Navigator.of(context).pop((_selected, _customHex)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightingSheet extends StatelessWidget {
  const _LightingSheet({required this.initial});

  final LightingPreset initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Studio Lighting',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Local lighting presets — no online HDRI needed',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final preset in LightingPreset.values)
                  _PresetChip(
                    icon: preset.icon,
                    label: preset.label,
                    selected: preset == initial,
                    onTap: () => Navigator.of(context).pop(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(13),
            border:
                Border.all(color: selected ? AppColors.accent : AppColors.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? const Color(0xFF0A0C11) : AppColors.accent),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color:
                      selected ? const Color(0xFF0A0C11) : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

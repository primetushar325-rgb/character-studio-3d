import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../backgrounds/backgrounds.dart';
import '../../characters2d/engine/face_rig.dart';
import '../../characters2d/puppet_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../scene/scene_object.dart';
import '../../state/editor_provider.dart';
import 'timeline_widget.dart';
import '../../widgets/premium_button.dart';
import 'background_picker.dart';
import 'character_export.dart';

/// Editor panels: CHARACTER · ANIMATION · BACKGROUND · LAYERS · TIMELINE.
/// Collapsible tabbed panel — compact on phones, side panel on tablets.
class EditorPanels extends StatefulWidget {
  const EditorPanels({super.key});

  @override
  State<EditorPanels> createState() => _EditorPanelsState();
}

class _EditorPanelsState extends State<EditorPanels> {
  int _tab = 0;
  static const _tabs = ['Character', 'Animation', 'Background', 'Layers', 'Timeline'];

  @override
  Widget build(BuildContext context) {
    final ed = context.watch<EditorProvider>();
    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_tabs[i], style: const TextStyle(fontSize: 12)),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i),
                      selectedColor: AppColors.accentSoft,
                      backgroundColor: AppColors.surfaceAlt,
                      labelStyle: TextStyle(color: _tab == i ? AppColors.accent : AppColors.textSecondary),
                      showCheckmark: false,
                      side: BorderSide(color: _tab == i ? AppColors.accent : AppColors.stroke),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_tab == 0) _characterPanel(ed),
                if (_tab == 1) _animationPanel(ed),
                if (_tab == 2) _backgroundPanel(ed),
                if (_tab == 3) _layersPanel(ed),
                if (_tab == 4) _timelinePanel(ed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- CHARACTER --------------------------------------------------------------
  Widget _characterPanel(EditorProvider ed) {
    final sel = ed.selected;
    if (sel == null) {
      return _card('Object', [
        _hint('Tap an object on the canvas (or add one from the toolbar) to edit its transform.'),
      ]);
    }
    final t = sel.transform;
    final id = sel.id;
    return _card('${sel.name} · Transform', [
      _slider('Position X', t.x, (v) => ed.updateTransform(id, (s) => s.x = v)),
      _slider('Position Y', t.y, (v) => ed.updateTransform(id, (s) => s.y = v)),
      _slider('Scale X', t.scaleX, (v) => ed.updateTransform(id, (s) => s.scaleX = v), min: 0.2, max: 4),
      _slider('Scale Y', t.scaleY, (v) => ed.updateTransform(id, (s) => s.scaleY = v), min: 0.2, max: 4),
      _slider('Rotation', t.rotation, (v) => ed.updateTransform(id, (s) => s.rotation = v), min: -180, max: 180),
      _slider('Opacity', t.opacity, (v) => ed.updateTransform(id, (s) => s.opacity = v)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          _toggle('Flip H', t.flipH, (v) => ed.updateTransform(id, (s) => s.flipH = v)),
          PremiumButton(
            label: 'Reset',
            small: true,
            onPressed: () => ed.updateTransform(id, (s) {
              s.x = 0.5;
              s.y = sel.isCharacter ? 0.78 : 0.5;
              s.scaleX = 1;
              s.scaleY = 1;
              s.rotation = 0;
              s.flipH = false;
              s.opacity = 1;
            }),
          ),
        ],
      ),
      if (sel.isCharacter) ...[
        const SizedBox(height: 14),
        const Text('EXPORT CHARACTER', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PremiumButton(
            label: 'Single-file HTML',
            icon: Icons.code_rounded,
            small: true,
            onPressed: () => exportCharacterHtml(context, ed),
          ),
          PremiumButton(
            label: 'character.json',
            icon: Icons.data_object_rounded,
            small: true,
            onPressed: () => exportCharacterJson(context, ed),
          ),
        ],
      ),
      ],
    ]);
  }

  // ---- ANIMATION -----------------------------------------------------------------
  Widget _animationPanel(EditorProvider ed) {
    final c = ed.controller;
    if (c == null) return _hint('Select a character object on the canvas (or add one with Char).');
    return _card('Animation', [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final id in PuppetController.actionOrder)
            ChoiceChip(
              label: Text(id.toUpperCase(), style: const TextStyle(fontSize: 11)),
              selected: c.actionId == id,
              onSelected: (_) => ed.setAction(id),
              selectedColor: AppColors.accentSoft,
              backgroundColor: AppColors.surfaceAlt,
              labelStyle: TextStyle(color: c.actionId == id ? AppColors.accent : AppColors.textSecondary),
              showCheckmark: false,
              side: BorderSide(color: c.actionId == id ? AppColors.accent : AppColors.stroke),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in Expr.values)
            ChoiceChip(
              label: Text('${Expressions.emoji(e)} ${Expressions.label(e)}', style: const TextStyle(fontSize: 11)),
              selected: c.animator.expression == e,
              onSelected: (_) => ed.setExpression(e),
              selectedColor: AppColors.accentSoft,
              backgroundColor: AppColors.surfaceAlt,
              labelStyle: TextStyle(color: c.animator.expression == e ? AppColors.accent : AppColors.textSecondary),
              showCheckmark: false,
              side: BorderSide(color: c.animator.expression == e ? AppColors.accent : AppColors.stroke),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Talk', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Switch(value: c.talkOverlay, activeColor: AppColors.accent, onChanged: ed.setTalking),
          const Spacer(),
          const Text('Face left', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          Switch(value: c.directionLeft, activeColor: AppColors.accent, onChanged: (v) => ed.setDirection(v)),
        ],
      ),
      const SizedBox(height: 8),
      // Playback transport.
      Row(
        children: [
          IconButton(
            icon: Icon(c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded), color: AppColors.textPrimary, onPressed: c.playing ? ed.pause : ed.play, tooltip: 'Play/Pause'),
          IconButton(icon: const Icon(Icons.stop_rounded), color: AppColors.textPrimary, onPressed: ed.stop, tooltip: 'Stop'),
          IconButton(icon: const Icon(Icons.skip_previous_rounded), color: AppColors.textPrimary, onPressed: () => ed.stepFrame(-1), tooltip: 'Previous frame'),
          IconButton(icon: const Icon(Icons.skip_next_rounded), color: AppColors.textPrimary, onPressed: () => ed.stepFrame(1), tooltip: 'Next frame'),
          ChoiceChip(
            label: Text(c.loop ? 'Loop' : 'Once', style: const TextStyle(fontSize: 11)),
            selected: c.loop,
            onSelected: (_) => ed.setLoop(!c.loop),
            selectedColor: AppColors.accentSoft,
            backgroundColor: AppColors.surfaceAlt,
            labelStyle: TextStyle(color: c.loop ? AppColors.accent : AppColors.textSecondary),
            showCheckmark: false,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        children: [
          for (final s in const [0.25, 0.5, 1.0, 1.5, 2.0])
            ChoiceChip(
              label: Text('${s}x', style: const TextStyle(fontSize: 11)),
              selected: c.speed == s,
              onSelected: (_) => ed.setSpeed(s),
              selectedColor: AppColors.accentSoft,
              backgroundColor: AppColors.surfaceAlt,
              labelStyle: TextStyle(color: c.speed == s ? AppColors.accent : AppColors.textSecondary),
              showCheckmark: false,
            ),
        ],
      ),
    ]);
  }

  // ---- BACKGROUND -----------------------------------------------------------------
  Widget _backgroundPanel(EditorProvider ed) {
    final bg = ed.background;
    return _card('Background', [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (kind, label) in const [
            (BgKind.builtin, 'Library'),
            (BgKind.gradient, 'Gradient'),
            (BgKind.solid, 'Color'),
            (BgKind.image, 'Gallery'),
            (BgKind.transparent, 'None'),
          ])
            ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 11)),
              selected: bg.kind == kind,
              onSelected: (_) => ed.setBackground(bg.clone()..kind = kind),
              selectedColor: AppColors.accentSoft,
              backgroundColor: AppColors.surfaceAlt,
              labelStyle: TextStyle(color: bg.kind == kind ? AppColors.accent : AppColors.textSecondary),
              showCheckmark: false,
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (bg.kind == BgKind.builtin) ..._builtinPicker(ed, bg),
      if (bg.kind == BgKind.gradient) ...[
        _colorRow('Color A', bg.color1, (c) => ed.setBackground(bg.clone()..color1 = c)),
        _colorRow('Color B', bg.color2, (c) => ed.setBackground(bg.clone()..color2 = c)),
        _slider('Angle', bg.gradientAngle, (v) => ed.setBackground(bg.clone()..gradientAngle = v), min: 0, max: 360),
      ],
      if (bg.kind == BgKind.solid) _colorRow('Color', bg.color1, (c) => ed.setBackground(bg.clone()..color1 = c)),
      if (bg.kind == BgKind.image) ...[
        PremiumButton(label: 'Pick from Gallery', icon: Icons.photo_library_rounded, small: true, onPressed: () => pickGalleryBackground(context)),
        const SizedBox(height: 10),
        _seg4(bg, ed, 'Fit', ['Cover', 'Contain', 'Fill']),
        _slider('Scale', bg.scale, (v) => ed.setBackground(bg.clone()..scale = v), min: 0.5, max: 3),
        _slider('Pos X', bg.offsetX, (v) => ed.setBackground(bg.clone()..offsetX = v), min: -1, max: 1),
        _slider('Pos Y', bg.offsetY, (v) => ed.setBackground(bg.clone()..offsetY = v), min: -1, max: 1),
      ],
      if (bg.kind == BgKind.image || bg.kind == BgKind.builtin) ...[
        _slider('Blur', bg.blur, (v) => ed.setBackground(bg.clone()..blur = v), min: 0, max: 10),
      ],
      _slider('Brightness', bg.brightness, (v) => ed.setBackground(bg.clone()..brightness = v), min: -0.5, max: 0.5),
      _slider('Contrast', bg.contrast, (v) => ed.setBackground(bg.clone()..contrast = v), min: -0.5, max: 0.5),
      _slider('Opacity', bg.opacity, (v) => ed.setBackground(bg.clone()..opacity = v), min: 0.05, max: 1),
      const SizedBox(height: 8),
      Row(
        children: [
          PremiumButton(label: 'Reset', small: true, onPressed: () => ed.setBackground(BgConfig())),
          const SizedBox(width: 8),
          if (bg.kind == BgKind.image)
            PremiumButton(label: 'Remove', small: true, onPressed: () => ed.setBackground(BgConfig())),
        ],
      ),
    ]);
  }

  List<Widget> _builtinPicker(EditorProvider ed, BgConfig bg) {
    return [
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final cat in Backgrounds.categories)
              if (Backgrounds.byCategory(cat).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 11)),
                    selected: Backgrounds.byCategory(cat).any((b) => b.id == bg.builtinId),
                    onSelected: (_) => ed.setBackground(bg.clone()
                      ..builtinId = Backgrounds.byCategory(cat).first.id
                      ..kind = BgKind.builtin),
                    selectedColor: AppColors.accentSoft,
                    backgroundColor: AppColors.surfaceAlt,
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    showCheckmark: false,
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final b in Backgrounds.builtIns)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => ed.setBackground(bg.clone()
                ..builtinId = b.id
                ..kind = BgKind.builtin),
              child: Container(
                width: 108,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: bg.builtinId == b.id ? AppColors.accent : AppColors.stroke, width: bg.builtinId == b.id ? 2 : 1),
                  color: AppColors.surfaceAlt,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: CustomPaint(painter: _BgThumb(b)))),
                    Positioned(
                      left: 6,
                      bottom: 4,
                      child: Text(
                        b.name,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4)]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _seg4(BgConfig bg, EditorProvider ed, String label, List<String> labels) {
    final fits = BgFit.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < fits.length; i++)
              ChoiceChip(
                label: Text(labels[i], style: const TextStyle(fontSize: 11)),
                selected: bg.fit == fits[i],
                onSelected: (_) => ed.setBackground(bg.clone()..fit = fits[i]),
                selectedColor: AppColors.accentSoft,
                backgroundColor: AppColors.surfaceAlt,
                labelStyle: TextStyle(color: bg.fit == fits[i] ? AppColors.accent : AppColors.textSecondary),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---- LAYERS ---------------------------------------------------------------------
  Widget _layersPanel(EditorProvider ed) {
    // Real scene-object list, TOP layer first (matches visual stacking).
    final ordered = [...ed.objects]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    return _card('Layers', [
      _backgroundLayerRow(ed),
      for (final o in ordered) _objectLayerRow(ed, o),
      if (ed.objects.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('No objects yet — add characters, images, text or shapes from the toolbar.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.5)),
        ),
      const SizedBox(height: 8),
      const Text('Background always renders below every object.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);
  }

  Widget _backgroundLayerRow(EditorProvider ed) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.landscape_rounded, color: AppColors.textSecondary, size: 20),
      title: const Text('Background', style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
      subtitle: Text(ed.background.kind.name, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
      trailing: IconButton(
        icon: Icon(ed.backgroundVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 19, color: AppColors.textSecondary),
        onPressed: () {
          ed.backgroundVisible = !ed.backgroundVisible;
          ed.refresh();
        },
      ),
    );
  }

  Widget _objectLayerRow(EditorProvider ed, SceneObject o) {
    final selected = ed.selectedId == o.id;
    IconData icon = switch (o.type) {
      SceneObjectType.character => Icons.person_rounded,
      SceneObjectType.image => Icons.image_rounded,
      SceneObjectType.text => Icons.text_fields_rounded,
      SceneObjectType.shape => Icons.category_rounded,
    };
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSoft : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        dense: true,
        onTap: () => ed.select(o.id),
        leading: Icon(icon, color: selected ? AppColors.accent : AppColors.textSecondary, size: 20),
        title: Text(o.name, style: TextStyle(color: selected ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        subtitle: Text(o.type.name, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Move up',
            icon: const Icon(Icons.arrow_upward_rounded, size: 17, color: AppColors.textSecondary),
            onPressed: () => ed.moveObjectUp(o.id),
          ),
          IconButton(
            tooltip: 'Move down',
            icon: const Icon(Icons.arrow_downward_rounded, size: 17, color: AppColors.textSecondary),
            onPressed: () => ed.moveObjectDown(o.id),
          ),
          IconButton(
            tooltip: o.visible ? 'Hide' : 'Show',
            icon: Icon(o.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: AppColors.textSecondary),
            onPressed: () => ed.setVisibility(o.id, !o.visible),
          ),
          IconButton(
            tooltip: o.locked ? 'Unlock' : 'Lock',
            icon: Icon(o.locked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 18, color: o.locked ? AppColors.accent : AppColors.textSecondary),
            onPressed: () => ed.toggleLock(o.id),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE2574C)),
            onPressed: () => ed.removeObject(o.id),
          ),
        ]),
      ),
    );
  }

  // ---- TIMELINE --------------------------------------------------------------------
  Widget _timelinePanel(EditorProvider ed) {
    final c = ed.controller;
    if (c == null) return _hint('Add a character first.');
    return _card('Timeline', [
      TimelineWidget(ed: ed),
      const SizedBox(height: 10),
      Text(
        'Clip: ${c.actionId} · ${(c.animator.clipDuration).toStringAsFixed(2)}s · time ${c.animator.clipTime.toStringAsFixed(2)}s',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ]);
  }

  // ---- helpers -----------------------------------------------------------------------
  Widget _card(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          ...children,
        ],
      );

  Widget _hint(String s) => Text(s, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5));

  Widget _slider(String label, double value, void Function(double) onChanged, {double min = 0, double max = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.surfaceAlt,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, void Function(bool) onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11.5, color: value ? AppColors.accent : AppColors.textSecondary)),
      selected: value,
      onSelected: onChanged,
      selectedColor: AppColors.accentSoft,
      backgroundColor: AppColors.surfaceAlt,
      showCheckmark: false,
      side: BorderSide(color: value ? AppColors.accent : AppColors.stroke),
    );
  }

  Widget _colorRow(String label, Color color, void Function(Color) onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        const Spacer(),
        for (final c in const [
          Color(0xFF101828), Color(0xFF1C1430), Color(0xFF12241C), Color(0xFF2A1E1E),
          Color(0xFF243B6B), Color(0xFF6B2430), Color(0xFF2A5240), Color(0xFF5C4A1E),
          Color(0xFFE8D4B0), Color(0xFF7EC8F0), Color(0xFFFFC98A), Color(0xFFD96A9E),
        ])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(c),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? AppColors.accent : AppColors.stroke, width: 2)),
              ),
            ),
          ),
      ],
    );
  }
}

class _BgThumb extends CustomPainter {
  _BgThumb(this.spec);
  final BgSpec spec;

  @override
  void paint(Canvas canvas, Size size) => spec.painter(canvas, size);

  @override
  bool shouldRepaint(_BgThumb oldDelegate) => oldDelegate.spec != spec;
}

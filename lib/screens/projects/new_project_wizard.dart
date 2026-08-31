import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/animation_clip.dart';
import '../../models/character.dart';
import '../../models/studio_project.dart';
import '../../models/viewer_enums.dart';
import '../../state/library_provider.dart';
import '../../state/projects_provider.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/thumbnail.dart';

/// "New Project" wizard: Character → Animation → Background → Camera →
/// Duration → Create Preview. All state is local, the result is persisted.
class NewProjectWizard extends StatefulWidget {
  const NewProjectWizard({super.key});

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NewProjectWizard(),
    );
  }

  @override
  State<NewProjectWizard> createState() => _NewProjectWizardState();
}

class _NewProjectWizardState extends State<NewProjectWizard> {
  int _step = 0;
  Character? _character;
  AnimationClip? _animation;
  BackgroundPreset _background = BackgroundPreset.studio;
  String? _customHex;
  LightingPreset _lighting = LightingPreset.studio;
  String _orbit = CameraPresets.front;
  bool _autoRotate = false;
  int _duration = 10;
  final _nameController = TextEditingController();

  static const _steps = [
    'Select Character',
    'Select Animation',
    'Set Background',
    'Set Camera',
    'Set Duration',
    'Create Preview',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, _steps.length - 1));
  void _back() => setState(() => _step = (_step - 1).clamp(0, _steps.length - 1));

  Future<void> _create() async {
    final projects = context.read<ProjectsProvider>();
    final name = _nameController.text.trim().isEmpty
        ? '${_character!.displayName} · ${_animation!.displayName}'
        : _nameController.text.trim();

    final project = StudioProject(
      id: newProjectId(),
      name: name,
      characterId: _character!.id,
      animationName: _animation!.name,
      animationDisplay: _animation!.displayName,
      background: _background,
      customBackgroundHex: _customHex,
      lighting: _lighting,
      cameraOrbit: _orbit,
      autoRotate: _autoRotate,
      durationSeconds: _duration,
      createdAt: DateTime.now(),
    );

    await projects.create(project);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project "${project.name}" created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    final canContinue = switch (_step) {
      0 => _character != null,
      1 => _animation != null,
      _ => true,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Column(
                children: [
                  Text('New Project',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _StepIndicator(step: _step, total: _steps.length),
                  const SizedBox(height: 4),
                  Text(
                    _steps[_step],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _stepContent(context, library),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      PremiumButton(
                        label: 'Back',
                        onPressed: _back,
                        style: PremiumButtonStyle.ghost,
                      ),
                    const Spacer(),
                    if (_step < _steps.length - 1)
                      PremiumButton(
                        label: 'Continue',
                        icon: Icons.arrow_forward_rounded,
                        style: PremiumButtonStyle.primary,
                        onPressed: canContinue ? _next : null,
                      )
                    else
                      PremiumButton(
                        label: 'Create Project',
                        icon: Icons.check_rounded,
                        style: PremiumButtonStyle.primary,
                        onPressed: _create,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context, LibraryProvider library) {
    switch (_step) {
      case 0:
        return _characterStep(library);
      case 1:
        return _animationStep();
      case 2:
        return _backgroundStep();
      case 3:
        return _cameraStep();
      case 4:
        return _durationStep();
      default:
        return _summaryStep();
    }
  }

  // ---- Step 1: character ------------------------------------------------
  Widget _characterStep(LibraryProvider library) {
    final characters = library.characters;
    return ListView(shrinkWrap: true, 
      key: const ValueKey('step-character'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        for (final character in characters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PickTile(
              selected: _character?.id == character.id,
              onTap: () => setState(() {
                _character = character;
                // Reset animation when switching characters.
                if (_animation != null &&
                    character.clipByName(_animation!.name) == null) {
                  _animation = null;
                }
              }),
              leading: CharacterAvatar(character: character, size: 46, borderRadius: 13),
              title: character.displayName,
              subtitle:
                  '${character.animationCount} ${character.animationCount == 1 ? 'animation' : 'animations'}',
            ),
          ),
      ],
    );
  }

  // ---- Step 2: animation --------------------------------------------------
  Widget _animationStep() {
    final animations = _character?.animations ?? const <AnimationClip>[];
    if (animations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'This character has no animation clips.\nPick a different character to continue.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView(shrinkWrap: true, 
      key: const ValueKey('step-animation'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        for (final clip in animations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PickTile(
              selected: _animation?.name == clip.name,
              onTap: () => setState(() => _animation = clip),
              leading: Icon(
                animationIconFor(
                    clip.knownAction ? clip.normalizedName : clip.displayName),
                color: AppColors.accent,
              ),
              title: clip.displayName,
              subtitle: 'Clip: ${clip.name.split('|').last}',
            ),
          ),
      ],
    );
  }

  // ---- Step 3: background ---------------------------------------------------
  Widget _backgroundStep() {
    return ListView(shrinkWrap: true, 
      key: const ValueKey('step-background'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text('Background', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in BackgroundPreset.values)
              _WizardChip(
                icon: preset.icon,
                label: preset.label,
                selected: _background == preset,
                onTap: () async {
                  if (preset == BackgroundPreset.custom) {
                    final hex = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const ColorPickerSheet(),
                    );
                    if (hex == null) return;
                    setState(() {
                      _background = preset;
                      _customHex = hex;
                    });
                  } else {
                    setState(() => _background = preset);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Lighting', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in LightingPreset.values)
              _WizardChip(
                icon: preset.icon,
                label: preset.label,
                selected: _lighting == preset,
                onTap: () => setState(() => _lighting = preset),
              ),
          ],
        ),
      ],
    );
  }

  // ---- Step 4: camera ----------------------------------------------------------
  Widget _cameraStep() {
    return ListView(shrinkWrap: true, 
      key: const ValueKey('step-camera'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text('Camera angle', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, orbit, icon) in CameraPresets.all)
              _WizardChip(
                icon: icon,
                label: label,
                selected: _orbit == orbit,
                onTap: () => setState(() => _orbit = orbit),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-rotate camera',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Slowly orbit the character automatically'),
          value: _autoRotate,
          onChanged: (v) => setState(() => _autoRotate = v),
        ),
      ],
    );
  }

  // ---- Step 5: duration -----------------------------------------------------------
  Widget _durationStep() {
    return ListView(shrinkWrap: true, 
      key: const ValueKey('step-duration'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text('Preview duration', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final seconds in const [5, 10, 15, 30])
              _WizardChip(
                icon: Icons.timer_outlined,
                label: '${seconds}s',
                selected: _duration == seconds,
                onTap: () => setState(() => _duration = seconds),
              ),
          ],
        ),
      ],
    );
  }

  // ---- Step 6: summary ---------------------------------------------------------------
  Widget _summaryStep() {
    final dateFormat = '${DateTime.now().year}';
    return ListView(shrinkWrap: true, 
      key: const ValueKey('step-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text('Project name', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          maxLength: 48,
          decoration: InputDecoration(
            hintText:
                '${_character?.displayName ?? ''} · ${_animation?.displayName ?? ''}',
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.stroke),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Character', value: _character?.displayName ?? '—'),
        _SummaryRow(label: 'Animation', value: _animation?.displayName ?? '—'),
        _SummaryRow(
            label: 'Background',
            value: _background == BackgroundPreset.custom
                ? 'Custom'
                : _background.label),
        _SummaryRow(label: 'Lighting', value: _lighting.label),
        _SummaryRow(label: 'Camera', value: CameraPresets.labelFor(_orbit)),
        _SummaryRow(label: 'Auto-rotate', value: _autoRotate ? 'On' : 'Off'),
        _SummaryRow(label: 'Duration', value: '$_duration seconds'),
        _SummaryRow(label: 'Created', value: dateFormat),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == step;
        final done = i < step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
            height: 4,
            decoration: BoxDecoration(
              color: done || active ? AppColors.accent : AppColors.strokeStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.stroke,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 46, height: 46, child: Center(child: leading)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardChip extends StatelessWidget {
  const _WizardChip({
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
            color: selected ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected
                    ? AppColors.accent.withOpacity(0.6)
                    : AppColors.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.accent : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

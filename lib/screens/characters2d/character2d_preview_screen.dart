import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../characters2d/character2d_model.dart';
import '../../characters2d/puppet_controller.dart';
import '../../characters2d/widgets2d/puppet_control_panel.dart';
import '../../characters2d/widgets2d/puppet_stage.dart';
import '../../core/theme/app_colors.dart';
import '../../state/library2d_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import '../player/player_screen.dart';
import 'customize_sheet.dart';

/// Character preview (§21–26): large animated stage + every control + Use
/// Character into the main editor.
class Character2DPreviewScreen extends StatefulWidget {
  const Character2DPreviewScreen({super.key, required this.characterId});

  final String characterId;

  @override
  State<Character2DPreviewScreen> createState() => _Character2DPreviewScreenState();
}

class _Character2DPreviewScreenState extends State<Character2DPreviewScreen> {
  PuppetController? _controller;
  String? _error;
  Color _bg = const Color(0xFF171B26);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final library = context.read<Library2DProvider>();
    final character = library.byId(widget.characterId);
    if (!mounted) return;
    if (character == null) {
      setState(() => _error = 'Character data could not be loaded.');
      return;
    }
    setState(() {
      _error = null;
      _controller = PuppetController(spec: character.spec, palette: character.colors, accessories: character.accessories)
        ..setAction('stand');
    });
    library.recordUsage(character.id);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<Library2DProvider>();
    final character = library.byId(widget.characterId);
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(character?.name ?? 'Character', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          if (character != null)
            IconButton(
              tooltip: 'Favorite',
              icon: Icon(
                library.isFavorite(character.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: library.isFavorite(character.id) ? AppColors.favorite : AppColors.textSecondary,
              ),
              onPressed: () => library.toggleFavorite(character.id),
            ),
          if (character != null && character.isVariant)
            IconButton(
              tooltip: 'Delete variant',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () => _confirmDelete(character),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _error != null || character == null || controller == null
            ? _errorBody()
            : Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: () => setState(() => _bg = const Color(0xFF171B26)),
                      child: PuppetStage(controller: controller, background: _bg),
                    ),
                  ),
                  _bgRow(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    color: AppColors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: PremiumButton(
                            label: 'Customize',
                            icon: Icons.palette_rounded,
                            onPressed: () => _customize(character),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: PremiumButton(
                            label: 'Use Character',
                            icon: Icons.play_circle_rounded,
                            style: PremiumButtonStyle.primary,
                            onPressed: () {
                              library.recordUsage(character.id);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PlayerScreen(
                                    characterId: '',
                                    character2dId: character.id,
                                    initial2dAction: controller.actionId,
                                    initial2dExpr: controller.animator.expression,
                                    initial2dSpeed: controller.speed,
                                    initial2dDirectionLeft: controller.directionLeft,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 296,
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: SingleChildScrollView(
                      child: PuppetControlPanel(
                        controller: controller,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _errorBody() => Center(
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 42),
              const SizedBox(height: 12),
              Text(_error ?? 'Character not found', style: const TextStyle(color: AppColors.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              PremiumButton(
                label: 'Reload Character',
                icon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );

  Widget _bgRow() => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const Text('STAGE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(width: 12),
            for (final c in const [
              Color(0xFF171B26),
              Color(0xFF101828),
              Color(0xFF1C1430),
              Color(0xFF12241C),
              Color(0xFF2A1E1E),
              Color(0xFF24282E),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _bg = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg == c ? AppColors.accent : AppColors.strokeStrong, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Future<void> _customize(Character2D character) async {
    await showCustomizeSheet(
      context,
      character: character,
      onSave: (name, palette, accessories) async {
        final library = context.read<Library2DProvider>();
        if (character.isVariant) {
          final updated = character.copyWith(name: name, palette: palette, accessories: accessories)..updatedAt = DateTime.now();
          await library.updateVariant(updated);
        } else {
          final variant = await library.saveVariant(
            baseId: character.id,
            name: name,
            palette: palette,
            accessories: accessories,
          );
          if (!mounted) return;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Variant saved: ${variant.name}'), backgroundColor: AppColors.surfaceAlt),
          );
        }
      },
    );
  }

  Future<void> _confirmDelete(Character2D character) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete variant?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${character.name}" will be removed permanently.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<Library2DProvider>().deleteVariant(character.id);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

import 'package:flutter/material.dart';

import '../../characters2d/character2d_model.dart';
import '../../characters2d/engine/face_rig.dart';
import '../../characters2d/puppet_controller.dart';
import '../../characters2d/widgets2d/puppet_control_panel.dart';
import '../../characters2d/widgets2d/puppet_stage.dart';
import '../../core/theme/app_colors.dart';
import '../../state/library2d_provider.dart';
import '../../widgets/premium_button.dart';
import 'package:provider/provider.dart';

/// Main-editor mode for 2D cartoon characters (§29). The selected character
/// + action + expression + speed + direction animate immediately inside the
/// player; the 3D GLB path is untouched.
class Stage2DBody extends StatefulWidget {
  const Stage2DBody({
    super.key,
    required this.character,
    this.initialAction = 'stand',
    this.initialExpr = Expr.neutral,
    this.initialSpeed = 1.0,
    this.initialDirectionLeft = false,
  });

  final Character2D character;
  final String initialAction;
  final Expr initialExpr;
  final double initialSpeed;
  final bool initialDirectionLeft;

  @override
  State<Stage2DBody> createState() => _Stage2DBodyState();
}

class _Stage2DBodyState extends State<Stage2DBody> {
  late final PuppetController _controller;
  Color _bg = const Color(0xFF171B26);
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _controller = PuppetController(
        spec: widget.character.spec,
        palette: widget.character.colors,
        accessories: widget.character.accessories,
      )
        ..setExpression(widget.initialExpr)
        ..setSpeed(widget.initialSpeed)
        ..setDirection(widget.initialDirectionLeft ? -1 : 1)
        ..setAction(widget.initialAction);
    } catch (_) {
      _error = 'Unable to initialize character rig.';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _error == null) {
        context.read<Library2DProvider>().recordUsage(widget.character.id);
      }
    });
  }

  @override
  void dispose() {
    if (_error == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            PremiumButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: PuppetStage(controller: _controller, background: _bg),
          ),
          _tiles(),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: SizedBox(
              height: 210,
              child: SingleChildScrollView(
                child: PuppetControlPanel(controller: _controller, onChanged: () {}, compact: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiles() => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
        child: Row(
          children: [
            for (final c in const [
              Color(0xFF171B26), Color(0xFF101828), Color(0xFF1C1430),
              Color(0xFF12241C), Color(0xFF2A1E1E), Color(0xFF24282E),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _bg = c),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg == c ? AppColors.accent : AppColors.strokeStrong, width: 2),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Text(
              widget.character.name,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../engine/face_rig.dart';
import '../puppet_controller.dart';

/// Shared control surface for the character preview and the main 2D editor:
/// actions, playback, expressions, talking, gestures, head movement,
/// direction. Pure UI — all logic lives in [PuppetController].
class PuppetControlPanel extends StatelessWidget {
  const PuppetControlPanel({
    super.key,
    required this.controller,
    required this.onChanged,
    this.compact = false,
  });

  final PuppetController controller;
  final VoidCallback onChanged;
  final bool compact;

  static const _speeds = [0.25, 0.5, 1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Action'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in PuppetController.actionIds)
              _chip(
                label: _actionLabel(id),
                icon: _actionIcon(id),
                selected: c.actionId == id,
                onTap: () {
                  c.setAction(id);
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _section('Playback'),
        Row(
          children: [
            _iconBtn(
              icon: c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: c.playing ? 'Pause' : 'Play',
              onTap: () {
                c.setPlaying(!c.playing);
                onChanged();
              },
            ),
            const SizedBox(width: 8),
            _iconBtn(
              icon: Icons.loop_rounded,
              tooltip: 'Loop cycles',
              selected: c.loop,
              onTap: () {
                c.loop = !c.loop;
                onChanged();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in _speeds)
                    _chip(
                      label: '${s}x',
                      small: true,
                      selected: c.speed == s,
                      onTap: () {
                        c.setSpeed(s);
                        onChanged();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section('Expression'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in Expr.values)
              _chip(
                label: '${Expressions.emoji(e)} ${Expressions.label(e)}',
                small: true,
                selected: c.animator.expression == e,
                onTap: () {
                  c.setExpression(e);
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _section('Talking'),
        Row(
          children: [
            Switch(
              value: c.talkOverlay,
              activeColor: AppColors.accent,
              onChanged: (v) {
                c.setTalking(v);
                onChanged();
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.talkOverlay
                    ? 'Procedural talking: mouth, blinks, head & gestures active.'
                    : 'Talk ON/OFF — works while standing, walking or sitting.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section('Direction'),
        Row(
          children: [
            _chip(
              label: '← Left',
              selected: c.directionLeft,
              onTap: () {
                c.setDirection(-1);
                onChanged();
              },
            ),
            const SizedBox(width: 8),
            _chip(
              label: 'Right →',
              selected: !c.directionLeft,
              onTap: () {
                c.setDirection(1);
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section('Hand gestures'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in _gestures)
              _chip(
                label: g.label,
                small: true,
                icon: g.icon,
                onTap: () {
                  c.gesture(g.id);
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _section('Head & eyes'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in _headMoves)
              _chip(
                label: h.label,
                small: true,
                icon: h.icon,
                onTap: () {
                  c.headMove(h.id);
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _chip({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    bool small = false,
    IconData? icon,
  }) {
    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? AppColors.accent : AppColors.stroke),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14, vertical: small ? 7 : 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: small ? 14 : 16, color: selected ? AppColors.accent : AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontSize: small ? 12 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required String tooltip, required VoidCallback onTap, bool selected = false}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? AppColors.accentSoft : AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.accent : AppColors.stroke),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: selected ? AppColors.accent : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

String _actionLabel(String id) {
  switch (id) {
    case 'stand':
      return 'Stand';
    case 'walk':
      return 'Walk';
    case 'run':
      return 'Run';
    case 'sit':
      return 'Sit';
    case 'sleep':
      return 'Sleep';
    case 'talk':
      return 'Talk';
  }
  return id;
}

IconData _actionIcon(String id) {
  switch (id) {
    case 'stand':
      return Icons.accessibility_new_rounded;
    case 'walk':
      return Icons.directions_walk_rounded;
    case 'run':
      return Icons.directions_run_rounded;
    case 'sit':
      return Icons.chair_rounded;
    case 'sleep':
      return Icons.bedtime_rounded;
    case 'talk':
      return Icons.record_voice_over_rounded;
  }
  return Icons.play_arrow_rounded;
}

class _G {
  const _G(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const _gestures = [
  _G('wave', 'Wave', Icons.waving_hand_rounded),
  _G('greet', 'Greeting', Icons.volunteer_activism_rounded),
  _G('point_left', 'Point Left', Icons.arrow_back_rounded),
  _G('point_right', 'Point Right', Icons.arrow_forward_rounded),
  _G('point_forward', 'Point Forward', Icons.north_rounded),
  _G('open_palm', 'Open Palm', Icons.back_hand_rounded),
  _G('thumbs_up', 'Thumbs Up', Icons.thumb_up_rounded),
  _G('explain', 'Explain', Icons.school_rounded),
  _G('thinking', 'Thinking', Icons.psychology_rounded),
  _G('angry_gesture', 'Angry Gesture', Icons.sentiment_very_dissatisfied_rounded),
];

class _H {
  const _H(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const _headMoves = [
  _H('nod', 'Nod', Icons.arrow_downward_rounded),
  _H('shake', 'Shake Head', Icons.swap_horiz_rounded),
  _H('tilt_left', 'Tilt Left', Icons.rotate_left_rounded),
  _H('tilt_right', 'Tilt Right', Icons.rotate_right_rounded),
  _H('look_left', 'Look Left', Icons.visibility_rounded),
  _H('look_right', 'Look Right', Icons.visibility_outlined),
];

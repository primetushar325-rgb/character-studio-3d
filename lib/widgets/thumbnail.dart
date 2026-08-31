import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/character.dart';

/// Character thumbnail widget.
///
/// Priority:
///   1. Real image file beside the GLB (or captured from the live viewer)
///   2. Deterministic generated placeholder (gradient + initial + 3D badge)
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.character,
    this.size = 120,
    this.borderRadius = 18,
  });

  final Character character;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final file =
        character.thumbnailPath == null ? null : File(character.thumbnailPath!);

    if (file != null && file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final hues = _huesFor(character.id);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : size;
        final height = constraints.hasBoundedHeight ? constraints.maxHeight : size;
        final dimension = width < height ? width : height;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CustomPaint(
            painter: _AvatarPainter(hueA: hues.$1, hueB: hues.$2),
            child: SizedBox(
              width: size.isFinite ? size : width,
              height: size.isFinite ? size : height,
              child: Center(
                child: Text(
                  character.displayName.isEmpty
                      ? '?'
                      : character.displayName.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: dimension * 0.34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  (double, double) _huesFor(String id) {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final hueA = (hash % 360).toDouble();
    return (hueA, (hueA + 42) % 360);
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({required this.hueA, required this.hueB});

  final double hueA;
  final double hueB;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base dark gradient tinted with the character's deterministic hues.
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HSLColor.fromAHSL(1, hueA, 0.42, 0.26).toColor(),
          HSLColor.fromAHSL(1, hueB, 0.35, 0.14).toColor(),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Soft radial highlight.
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.4),
        radius: 0.9,
        colors: [
          Colors.white.withOpacity(0.16),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    // Subtle grid — a nod to 3D software viewports.
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1;
    const step = 16.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.hueA != hueA || oldDelegate.hueB != hueB;
}

/// Animated favorite heart used inside cards and app bars.
class FavoriteHeart extends StatefulWidget {
  const FavoriteHeart({
    super.key,
    required this.favorite,
    required this.onToggle,
    this.size = 22,
  });

  final bool favorite;
  final VoidCallback onToggle;
  final double size;

  @override
  State<FavoriteHeart> createState() => _FavoriteHeartState();
}

class _FavoriteHeartState extends State<FavoriteHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      lowerBound: 0.8,
      upperBound: 1.25,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _handleTap() {
    _bounce.forward(from: 0.8);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.favorite ? 'Remove from favorites' : 'Add to favorites',
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.25).animate(
              CurvedAnimation(parent: _bounce, curve: Curves.elasticOut),
            ),
            child: Icon(
              widget.favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: widget.size,
              color: widget.favorite ? AppColors.favorite : AppColors.textSecondary,
              shadows: widget.favorite
                  ? [
                      Shadow(
                        color: AppColors.favorite.withOpacity(0.5),
                        blurRadius: 14,
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

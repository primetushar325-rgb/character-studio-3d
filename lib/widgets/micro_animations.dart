import 'package:flutter/material.dart';

/// Subtle entrance animation for lists & grids.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = const Offset(0, 18),
  });

  final int index;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    // Cap the stagger so long lists don't feel slow.
    final i = index.clamp(0, 8);
    return _Entrance(
      key: ValueKey('entrance-$i-${child.hashCode}'),
      delay: Duration(milliseconds: 40 * i),
      offset: offset,
      child: child,
    );
  }
}

class _Entrance extends StatefulWidget {
  const _Entrance({
    super.key,
    required this.delay,
    required this.offset,
    required this.child,
  });

  final Duration delay;
  final Offset offset;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final dx = widget.offset.dx * (1 - _animation.value);
        final dy = widget.offset.dy * (1 - _animation.value);
        return Opacity(
          opacity: _animation.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Smooth page transition used across the app.
Route<T> fadeSlideRoute<T>(Widget page, {Offset begin = const Offset(0, 24)}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondary) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

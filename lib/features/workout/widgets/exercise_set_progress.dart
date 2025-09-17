import 'package:flutter/material.dart';

/// Visualizes per-set progress for an exercise.
///
/// States:
/// - Completed: index < completedSets (filled + check icon)
/// - Active: index == completedSets (outlined + pulse animation)
/// - Pending: index > completedSets (faint outline)
class ExerciseSetProgress extends StatelessWidget {
  final int totalSets;
  final int completedSets; // number of fully completed sets
  final double spacing;
  final double size;
  final bool animateActive;

  const ExerciseSetProgress({
    super.key,
    required this.totalSets,
    required this.completedSets,
    this.spacing = 8,
    this.size = 36,
    this.animateActive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSets <= 0) return const SizedBox.shrink();
    final clampedCompleted = completedSets.clamp(0, totalSets);

    return Semantics(
      container: true,
      label:
          'Exercise set progress: $clampedCompleted of $totalSets sets completed',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSets, (i) {
          final state = _computeSetState(i, clampedCompleted, totalSets);
          return Padding(
            padding: EdgeInsets.only(right: i == totalSets - 1 ? 0 : spacing),
            child: _SetChip(
              index: i,
              state: state,
              size: size,
              totalSets: totalSets,
              animateActive: animateActive,
            ),
          );
        }),
      ),
    );
  }
}

enum _SetState { completed, active, pending }

_SetState _computeSetState(int index, int completed, int total) {
  if (index < completed) return _SetState.completed;
  if (index == completed && completed < total) return _SetState.active;
  return _SetState.pending;
}

class _SetChip extends StatefulWidget {
  final int index;
  final _SetState state;
  final double size;
  final int totalSets;
  final bool animateActive;

  const _SetChip({
    required this.index,
    required this.state,
    required this.size,
    required this.totalSets,
    required this.animateActive,
  });

  @override
  State<_SetChip> createState() => _SetChipState();
}

class _SetChipState extends State<_SetChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
    if (widget.state == _SetState.active && widget.animateActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SetChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == _SetState.active &&
        widget.animateActive &&
        !_controller.isAnimating) {
      _controller.repeat();
    } else if ((widget.state != _SetState.active || !widget.animateActive) &&
        _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.shade300;
    Color bg;
    Color border;
    Widget? inner;
    switch (widget.state) {
      case _SetState.completed:
        bg = Colors.green.shade500;
        border = bg;
        inner = const Icon(Icons.check, size: 18, color: Colors.white);
        break;
      case _SetState.active:
        bg = Colors.white;
        border = Colors.blueAccent;
        inner = Text(
          '${widget.index + 1}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        );
        break;
      case _SetState.pending:
        bg = Colors.white;
        border = baseColor;
        inner = Text(
          '${widget.index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: Colors.grey.shade600,
          ),
        );
        break;
    }

    final semanticsLabel = switch (widget.state) {
      _SetState.completed =>
        'Set ${widget.index + 1} of ${widget.totalSets} completed',
      _SetState.active =>
        'Set ${widget.index + 1} of ${widget.totalSets} active',
      _SetState.pending =>
        'Set ${widget.index + 1} of ${widget.totalSets} pending',
    };

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.size * 0.5),
        border: Border.all(color: border, width: 2),
        boxShadow: widget.state == _SetState.active
            ? [
                BoxShadow(
                  color: border.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: inner,
    );

    return Semantics(
      label: semanticsLabel,
      child: widget.state == _SetState.active && widget.animateActive
          ? ScaleTransition(scale: _scale, child: chip)
          : chip,
    );
  }
}

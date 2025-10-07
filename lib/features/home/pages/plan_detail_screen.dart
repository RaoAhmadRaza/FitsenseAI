import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/workouts/workouts_cubit.dart';
import '../../../core/models/workout_plan.dart';
import '../../presentation/widgets/colors.dart';
import '../../../core/navigation/app_navigator.dart';

/// Displays details for a single [WorkoutPlan]: metadata, exercise list,
/// equipment, and provides a Start Plan action.
class PlanDetailScreen extends StatelessWidget {
  final String planId;
  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    return StartPlanActionScope(
      child: BlocBuilder<WorkoutsCubit, WorkoutsState>(
        builder: (context, state) {
          final plan = state.plans.firstWhere(
            (p) => p.id == planId,
            orElse: () => WorkoutPlan(
              id: 'missing',
              name: 'Missing Plan',
              level: 'Unknown',
              durationDisplay: '--',
              equipment: const [],
              exercises: const [],
            ),
          );
          final missing = plan.id == 'missing';
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF9FAFB),
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.black),
              title: Hero(
                tag: 'title_${plan.id}',
                flightShuttleBuilder:
                    (context, animation, direction, from, to) =>
                        FadeTransition(opacity: animation, child: to.widget),
                child: Text(
                  missing ? 'Plan Missing' : plan.name,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.3,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              actions: [
                if (!missing)
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit, color: Colors.black),
                    onPressed: () => _showRenameDialog(context, plan),
                  ),
              ],
              centerTitle: true,
            ),
            floatingActionButton: missing
                ? null
                : Semantics(
                    button: true,
                    label: 'Start plan ${plan.name}',
                    child: Builder(
                      builder: (ctx) {
                        final inFlight =
                            StartPlanInFlightMarker.of(ctx)?.inFlight ?? false;
                        return _FrostedFab(
                          label: inFlight ? 'Starting…' : 'Start Plan',
                          icon: CupertinoIcons.play_fill,
                          enabled: !inFlight,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            AppNavigator.startPlan(ctx, plan);
                          },
                        );
                      },
                    ),
                  ),
            body: missing
                ? const _MissingPlanBody()
                : _PlanDetailBody(plan: plan),
          );
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WorkoutPlan plan) {
    final ctrl = TextEditingController(text: plan.name);
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Rename Plan',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(
                fontFamily: 'SF Pro Text',
                color: Color(0xFF6B7280),
              ),
            ),
            autofocus: true,
            onSubmitted: (_) => _commitRename(context, plan, ctrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _commitRename(context, plan, ctrl.text),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commitRename(
    BuildContext context,
    WorkoutPlan plan,
    String name,
  ) async {
    Navigator.pop(context);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == plan.name) return;
    final updated = plan.copyWith(name: trimmed);
    await context.read<WorkoutsCubit>().updatePlan(updated);
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan renamed')));
    }
  }
}

class _PlanDetailBody extends StatelessWidget {
  final WorkoutPlan plan;
  const _PlanDetailBody({required this.plan});

  @override
  Widget build(BuildContext context) {
    final equip = plan.equipment.isEmpty
        ? 'Bodyweight / None'
        : plan.equipment.join(', ');
    final thumb = plan.exercises.isNotEmpty
        ? plan.exercises.first.imagePath
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (thumb != null && thumb.isNotEmpty) ...[
          Center(
            child: Hero(
              tag: 'thumb_${plan.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey.shade200,
                  child: Image.asset(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.fitness_center,
                      size: 36,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _MetaRow(icon: Icons.fitness_center, label: 'Level', value: plan.level),
        const SizedBox(height: 8),
        _MetaRow(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: plan.durationDisplay,
        ),
        const SizedBox(height: 8),
        _MetaRow(
          icon: Icons.handyman_outlined,
          label: 'Equipment',
          value: equip,
        ),
        const SizedBox(height: 20),
        Text(
          'Exercises (${plan.exercises.length})',
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        if (plan.exercises.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              'No exercises yet. Tap + in the browser to add (coming soon).',
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          )
        else ...[
          for (final e in plan.exercises) _ExerciseTile(e: e),
        ],
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final PlanExercise e;
  const _ExerciseTile({required this.e});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: _Thumb(path: e.imagePath),
        title: Text(
          e.name,
          style: const TextStyle(
            fontFamily: 'SF Pro Text',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          '${e.sets} x ${e.reps}  •  ${e.targetMuscle}',
          style: TextStyle(
            fontFamily: 'SF Pro Text',
            fontSize: 13,
            color: const Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
        onTap: () {
          // Placeholder for future exercise edit/detail.
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? path;
  const _Thumb({this.path});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 50,
        height: 50,
        color: Colors.grey.shade200,
        child: path == null || path!.isEmpty
            ? const Icon(Icons.fitness_center, size: 26, color: Colors.grey)
            : Image.asset(
                path!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fitness_center,
                  size: 26,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.fitnessBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissingPlanBody extends StatelessWidget {
  const _MissingPlanBody();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 54, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Plan Not Found',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'It may have been deleted or is unavailable.',
            style: TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedFab extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  const _FrostedFab({
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  @override
  State<_FrostedFab> createState() => _FrostedFabState();
}

class _FrostedFabState extends State<_FrostedFab> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final effectiveOpacity = widget.enabled ? 1.0 : 0.6;
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.95 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: (_pressed ? 0.9 : 1.0) * effectiveOpacity,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.vibrantRed,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

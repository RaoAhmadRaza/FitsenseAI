import 'package:flutter/material.dart';
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
            appBar: AppBar(
              title: Text(missing ? 'Plan Missing' : plan.name),
              actions: [
                if (!missing)
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRenameDialog(context, plan),
                  ),
              ],
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
                        return FloatingActionButton.extended(
                          onPressed: inFlight
                              ? null
                              : () => AppNavigator.startPlan(ctx, plan),
                          label: Text(inFlight ? 'Starting…' : 'Start Plan'),
                          icon: const Icon(Icons.play_arrow),
                          backgroundColor: AppColors.fitnessBlue,
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Plan'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
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
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        if (plan.exercises.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No exercises yet. Tap + in the browser to add (coming soon).',
              style: TextStyle(fontFamily: 'Sora', fontSize: 13),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: _Thumb(path: e.imagePath),
        title: Text(
          e.name,
          style: const TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${e.sets} x ${e.reps}  •  ${e.targetMuscle}',
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
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
                  fontFamily: 'Sora',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
              fontFamily: 'Sora',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'It may have been deleted or is unavailable.',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

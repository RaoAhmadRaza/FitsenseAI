import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/workouts/workouts_cubit.dart';
import '../../../logic/session/session_cubit.dart';
import '../../../core/utils/plan_exercise_id.dart';
import '../../presentation/widgets/colors.dart';
import '../../../core/models/workout_plan.dart';

/// Horizontal exercise queue for plan-derived sessions.
/// Displays ordered plan exercises with active highlighting and allows
/// tapping future exercises to jump (optional future behavior; currently disabled).
class ExerciseQueue extends StatefulWidget {
  final String planId;
  final int activeIndex; // 1-based
  const ExerciseQueue({
    super.key,
    required this.planId,
    required this.activeIndex,
  });

  @override
  State<ExerciseQueue> createState() => _ExerciseQueueState();
}

class _ExerciseQueueState extends State<ExerciseQueue> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ExerciseQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      _scrollToActive();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  void _scrollToActive() {
    final idx = widget.activeIndex - 1;
    if (!_scrollController.hasClients) return;
    if (idx < 0) return;
    const itemExtent = 100.0; // approximate width incl. padding
    final offset = (idx * itemExtent).clamp(
      0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      offset.toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutsCubit, WorkoutsState>(
      builder: (context, state) {
        final plan = state.plans.firstWhere(
          (p) => p.id == widget.planId,
          orElse: () => WorkoutPlan(
            id: 'missing',
            name: 'Missing',
            level: '',
            durationDisplay: '',
            equipment: const [],
            exercises: const [],
          ),
        );
        if (plan.id == 'missing' || plan.exercises.isEmpty) {
          return const SizedBox.shrink();
        }
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SizedBox(
            height: 110,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemBuilder: (context, index) {
                final ex = plan.exercises[index];
                final exIndex = index + 1;
                final active = exIndex == widget.activeIndex;
                return Semantics(
                  label: 'Exercise $exIndex, ${ex.name}',
                  selected: active,
                  button: true,
                  child: _ExerciseChip(
                    name: ex.name,
                    index: exIndex,
                    active: active,
                    completed: exIndex < widget.activeIndex,
                    onTap: () {
                      if (!active && exIndex < widget.activeIndex + 1) {
                        final sessionCubit = context.read<SessionCubit>();
                        final id = PlanExerciseId.build(plan.id, exIndex);
                        sessionCubit.startExercise(id);
                      }
                    },
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: plan.exercises.length,
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseChip extends StatelessWidget {
  final String name;
  final int index;
  final bool active;
  final bool completed;
  final VoidCallback onTap;
  const _ExerciseChip({
    required this.name,
    required this.index,
    required this.active,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = completed
        ? Colors.green.shade400
        : active
        ? AppColors.fitnessBlue
        : Colors.grey.shade300;
    final textColor = active || completed ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (active)
              BoxShadow(
                color: baseColor.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ex $index',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

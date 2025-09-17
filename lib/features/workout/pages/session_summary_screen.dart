import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/session/session_cubit.dart';
import '../../presentation/widgets/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../logic/workouts/workouts_cubit.dart';
import '../../../core/models/workout_plan.dart';

/// Minimal placeholder summary page.
/// Shows duration, exercise count and basic actions.
class SessionSummaryScreen extends StatelessWidget {
  final String sessionId;
  const SessionSummaryScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, state) {
          final session = (state.lastCompleted?.workoutId == sessionId)
              ? state.lastCompleted
              : (state.ongoing?.workoutId == sessionId ? state.ongoing : null);
          if (session == null) {
            return Center(
              child: Text(
                'Session not found',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            );
          }
          final exerciseCount = session.progress.length;
          final durationStr = formatDuration(session.durationSeconds);

          // Attempt to resolve plan to derive friendly exercise names if this session originated from a plan id.
          WorkoutPlan? sourcePlan;
          final workoutsState = context.read<WorkoutsCubit>().state;
          for (final p in workoutsState.plans) {
            if (p.id == session.workoutId) {
              sourcePlan = p;
              break;
            }
          }

          final rows = <_ExerciseRowData>[];
          int totalSets = 0;
          int totalReps = 0;
          for (int i = 0; i < session.progress.length; i++) {
            final prog = session.progress[i];
            totalSets += prog.completedSets;
            totalReps += prog.completedReps;
            String name;
            if (sourcePlan != null) {
              try {
                // naive match by index; if lengths diverged, fallback
                if (i < sourcePlan.exercises.length) {
                  name = sourcePlan.exercises[i].name;
                } else {
                  name = 'Exercise ${i + 1}';
                  debugPrint('[SessionSummary] Plan mismatch length index=$i');
                }
              } catch (e) {
                name = 'Exercise ${i + 1}';
                debugPrint(
                  '[SessionSummary] Error resolving plan exercise: $e',
                );
              }
            } else {
              name = 'Exercise ${i + 1}';
            }
            rows.add(
              _ExerciseRowData(
                name: name,
                sets: prog.completedSets,
                reps: prog.completedReps,
                timeSeconds: prog.timeSpentSeconds,
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Well done!',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _StatTile(
                  label: 'Duration',
                  value: durationStr,
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 12),
                _StatTile(
                  label: 'Exercises',
                  value: '$exerciseCount',
                  icon: Icons.fitness_center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _ExerciseTable(
                    rows: rows,
                    totalSets: totalSets,
                    totalReps: totalReps,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.fitnessBlue,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseRowData {
  final String name;
  final int sets;
  final int reps;
  final int timeSeconds; // may be zero
  _ExerciseRowData({
    required this.name,
    required this.sets,
    required this.reps,
    required this.timeSeconds,
  });
}

class _ExerciseTable extends StatelessWidget {
  final List<_ExerciseRowData> rows;
  final int totalSets;
  final int totalReps;
  const _ExerciseTable({
    required this.rows,
    required this.totalSets,
    required this.totalReps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'Exercise',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Sets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Reps',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final r = rows[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        r.name,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${r.sets}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${r.reps}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        r.timeSeconds > 0 ? formatDuration(r.timeSeconds) : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$totalSets',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$totalReps',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.fitnessBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

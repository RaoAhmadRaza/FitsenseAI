import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Session Summary',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
            color: Color(0xFF111827),
          ),
        ),
      ),
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
                  fontFamily: 'SF Pro Text',
                  fontSize: 15,
                  color: const Color(0xFF6B7280),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Great job!',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Here’s a quick look at what you completed.',
                  style: const TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 8),
                _PillCtaButton(
                  label: 'Back to Home',
                  icon: CupertinoIcons.house_fill,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
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
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Sets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Reps',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151),
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
                          fontFamily: 'SF Pro Text',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${r.sets}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${r.reps}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        r.timeSeconds > 0 ? formatDuration(r.timeSeconds) : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Text',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
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
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$totalSets',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$totalReps',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
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
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                fontFamily: 'SF Pro Text',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'SF Pro Text',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PillCtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PillCtaButton> createState() => _PillCtaButtonState();
}

class _PillCtaButtonState extends State<_PillCtaButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'SF Pro Text',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:ai_fitness_tracker/features/auth/presentation/pages/inividualWorkout.dart';
import '../../../../logic/session/session_cubit.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  Future<void> _startNewWorkout(BuildContext context) async {
    final sessionCubit = context.read<SessionCubit>();
    final existing = sessionCubit.state.ongoing;
    if (existing != null && !existing.completed) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Session In Progress'),
          content: const Text(
            'You already have an active workout. Start a new one anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start New'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    final id = 'workout_${DateTime.now().millisecondsSinceEpoch}';
    await sessionCubit.startSession(id);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Inividualworkout(sessionWorkoutId: id),
        ),
      );
    }
  }

  void _openPlans(BuildContext context) {
    Navigator.of(context).pushNamed('/plans');
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).pushNamed('/history');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          label: 'Start\nWorkout',
          icon: Icons.play_arrow_rounded,
          color: AppColors.vibrantRed,
          onTap: () => _startNewWorkout(context),
        ),
        _ActionButton(
          label: 'Browse\nPlans',
          icon: Icons.list_alt,
          color: AppColors.fitnessBlue,
          onTap: () => _openPlans(context),
        ),
        _ActionButton(
          label: 'History',
          icon: Icons.history,
          color: AppColors.healthGreen,
          onTap: () => _openHistory(context),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Sora',
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

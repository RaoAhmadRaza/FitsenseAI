import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/session/session_cubit.dart';
import '../../presentation/widgets/colors.dart';

class HistoryPlaceholder extends StatelessWidget {
  const HistoryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout History')),
      body: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, state) {
          // For now show lastCompleted + note future timeline/history work.
          final last = state.lastCompleted;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'History feature coming soon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Sora',
                  ),
                ),
                const SizedBox(height: 12),
                if (last != null)
                  Text(
                    'Most recent: ${last.workoutId} • ${last.progress.length} exercises',
                    style: const TextStyle(fontFamily: 'Sora'),
                  )
                else
                  const Text(
                    'No completed workouts yet',
                    style: TextStyle(fontFamily: 'Sora'),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fitnessBlue,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export / filtering coming soon')),
          );
        },
        child: const Icon(Icons.ios_share),
      ),
    );
  }
}

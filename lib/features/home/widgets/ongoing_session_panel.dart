import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../logic/session/session_cubit.dart';
import '../../../core/models/workout_session.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../features/presentation/widgets/colors.dart';
import '../../../core/ui/app_text_styles.dart';

/// Combines recovery banner + ongoing workout summary in one panel.
class OngoingSessionPanel extends StatefulWidget {
  const OngoingSessionPanel({super.key});

  @override
  State<OngoingSessionPanel> createState() => _OngoingSessionPanelState();
}

class _OngoingSessionPanelState extends State<OngoingSessionPanel> {
  // Recovery banner removed permanently.

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        final WorkoutSession? ongoing =
            (state.ongoing != null && !state.ongoing!.completed)
            ? state.ongoing
            : null;
        return Column(children: [_OngoingCard(ongoing: ongoing)]);
      },
    );
  }
}

class _OngoingCard extends StatelessWidget {
  final WorkoutSession? ongoing;
  const _OngoingCard({required this.ongoing});
  @override
  Widget build(BuildContext context) {
    final timeDisplay = ongoing == null
        ? 'NO ACTIVE'
        : formatDuration(ongoing!.durationSeconds);
    return Container(
      height: AppLayout.ongoingCardHeight,
      width: AppLayout.cardWidth,
      decoration: AppDecorations.subtleSurface(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Ongoing Workout', style: AppText.title16Bold),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 1,
                    backgroundColor: Colors.white,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(60),
                    ),
                  ),
                  onPressed: ongoing == null
                      ? null
                      : () => AppNavigator.resumeSession(
                          context,
                          ongoing!.workoutId,
                        ),
                  child: Row(
                    children: [
                      Text(
                        'Resume',
                        style: TextStyle(
                          color: AppColors.vibrantRed.withOpacity(
                            ongoing == null ? 0.3 : 1,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.vibrantRed.withOpacity(
                          ongoing == null ? 0.3 : 1,
                        ),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 130.0),
            child: Text(timeDisplay, style: AppText.hero33),
          ),
          const SizedBox(height: 1),
          Padding(
            padding: const EdgeInsets.only(right: 160.0),
            child: Text(
              ongoing == null ? 'No session in progress' : 'Session Active',
              style: AppText.subtitleGray12,
            ),
          ),
          const SizedBox(height: 10),
          const _OngoingWorkoutThumbnails(),
        ],
      ),
    );
  }
}

class _OngoingWorkoutThumbnails extends StatelessWidget {
  const _OngoingWorkoutThumbnails();
  static const thumbs = [
    'assets/images/incline-dumbbell-bench-press_0.jpg',
    'assets/images/incline-bench-press.jpg',
    'assets/images/barbell-curl.jpg',
    'assets/images/seated-arnold-press-thumb.jpg',
  ];
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: thumbs
        .map(
          (p) => SizedBox(
            height: 70,
            width: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(p, fit: BoxFit.cover),
            ),
          ),
        )
        .toList(),
  );
}

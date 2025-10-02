// ignore_for_file: unused_import, unused_shown_name
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/models/workout_session.dart';
import '../../../../logic/auth_bloc/auth_bloc.dart';
import '../../../../logic/auth_bloc/auth_event.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../main.dart'
    show
        gUserDisplayName,
        gUserEmail,
        gUserPhotoUrl,
        gUserAge,
        gUserWeightKg,
        gUserHeightCm,
        gUserHeightUnit,
        gUserGender,
        gUserPrimaryGoal;

/// Profile & Settings
/// Clean, developer-friendly structure with small reusable tiles.
/// TODOs are added where real data wiring is expected (auth/profile, persistence).
class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  // Compute active streak (consecutive days up to today), total minutes and completed count
  int _computeStreak(Iterable<WorkoutSession> sessions) {
    final completedDates = sessions
        .where((s) => s.completed)
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    int streak = 0;
    DateTime cursor = DateTime.now();
    DateTime curDay = DateTime(cursor.year, cursor.month, cursor.day);
    while (completedDates.contains(curDay)) {
      streak += 1;
      curDay = curDay.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _computeCompletedCount(Iterable<WorkoutSession> sessions) =>
      sessions.where((s) => s.completed).length;

  int _computeTotalSeconds(Iterable<WorkoutSession> sessions) => sessions
      .where((s) => s.completed)
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);

  String _formatHM(int seconds) {
    if (seconds <= 0) return '0M';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}H ${m}M';
    if (h > 0) return '${h}H';
    return '${m}M';
  }

  @override
  void initState() {
    super.initState();
    // Keep any minimal backend init here if needed.
    // Intentional: globals and bloc imports are preserved for backend wiring.
  }

  @override
  Widget build(BuildContext context) {
    // Keep only the background color of the screen; remove all UI widgets.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.only(top: 50.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: gUserPhotoUrl != null
                    ? NetworkImage(gUserPhotoUrl!)
                    : AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
              ),
              SizedBox(height: 16),
              Text(
                gUserDisplayName ?? 'Guest User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Sora',
                  letterSpacing: -1,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              // Stats from local backend (Hive sessionBox)
              ValueListenableBuilder<Box<WorkoutSession>>(
                valueListenable:
                    Hive.box<WorkoutSession>('sessionBox').listenable(),
                builder: (context, box, _) {
                  final sessions = box.values.toList(growable: false);
                  final streak = _computeStreak(sessions);
                  final totalSec = _computeTotalSeconds(sessions);
                  final completed = _computeCompletedCount(sessions);
                  return IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Icon(
                              AntDesign.fire_fill,
                              color: AppColors.energyOrange,
                              size: 30,
                            ),
                            SizedBox(height: 20),
                            Text(
                              '$streak',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              ' Active \nStreaks',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 10),
                        VerticalDivider(
                          color: Colors.grey.shade300,
                          thickness: 2.8,
                          indent: 10,
                          endIndent: 10,
                          width: 20,
                        ),
                        SizedBox(width: 10),
                        Column(
                          children: [
                            Icon(
                              AntDesign.clock_circle_fill,
                              color: AppColors.vibrantRed,
                              size: 30,
                            ),
                            SizedBox(height: 20),
                            Text(
                              _formatHM(totalSec),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Workout \n Minutes',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 10),
                        VerticalDivider(
                          color: Colors.grey.shade300,
                          thickness: 2.8,
                          indent: 10,
                          endIndent: 10,
                          width: 20,
                        ),
                        SizedBox(width: 10),
                        Column(
                          children: [
                            const Icon(
                              FontAwesomeIcons.dumbbell,
                              color: Colors.purpleAccent,
                              size: 30,
                            ),
                            SizedBox(height: 20),
                            Text(
                              '$completed',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Completed \n Workouts',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        'My Body',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Update your height, weight, age, and more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0, left: 40),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade800,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.profile);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1),
              Divider(
                color: Colors.grey.shade300,
                thickness: 2,
                indent: 15,
                endIndent: 30,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        'Workouts',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Check your workout history and stats',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 40),
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0, left: 40),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade800,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.history);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1),
              Divider(
                color: Colors.grey.shade300,
                thickness: 2,
                indent: 15,
                endIndent: 30,
              ),

              // TODO: REMOVED_MEALS — Meal Plans section removed
              SizedBox(height: 30),
              TextButton(
                onPressed: () {
                  context.read<AuthBloc>().add(const AuthSignOutRequested());
                },
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    letterSpacing: -1,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.red,
                    decorationThickness: 2,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

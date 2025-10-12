// ignore_for_file: unused_import, unused_shown_name
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/stats/minutes_service.dart';
import '../../../../core/db/session_index.dart';
import '../../../../core/models/workout_session.dart';
import '../../../../logic/auth_bloc/auth_bloc.dart';
import '../../../../logic/auth_bloc/auth_event.dart';
import '../../../../logic/session/session_cubit.dart';
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
  String _statsScope = 'all'; // 'today' | 'week' | 'all'

  // Compute active streak (consecutive days up to today)
  int _computeStreak(Iterable<WorkoutSession> sessions) {
    final completedDates = sessions
        .where((s) => s.completed)
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    int streak = 0;
    DateTime now = DateTime.now();
    DateTime cur = DateTime(now.year, now.month, now.day);
    while (completedDates.contains(cur)) {
      streak += 1;
      cur = cur.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Count completed sessions within the selected scope
  int _computeCompletedCount(Iterable<WorkoutSession> sessions) =>
      sessions.where((s) => s.completed && _isWithinScope(s.date)).length;

  // Variant that uses an override for ongoing duration seconds when provided
  int _scopedSecondsIndexedWithOngoingOverride(
    Iterable<WorkoutSession> sessions,
    int? ongoingOverrideSeconds,
  ) {
    final now = DateTime.now();
    if (_statsScope == 'today') {
      final completedToday = SessionIndex.daySeconds(now);
      final ongoingList = sessions
          .where((s) => !s.completed && _isWithinScope(s.date))
          .toList(growable: false);
      final ongoing = ongoingList.isEmpty
          ? 0
          : (ongoingOverrideSeconds ?? ongoingList.first.durationSeconds);
      return completedToday + ongoing;
    }
    if (_statsScope == 'week') {
      int completed = 0;
      for (int i = 0; i < 7; i++) {
        completed += SessionIndex.daySeconds(now.subtract(Duration(days: i)));
      }
      final ongoingList = sessions
          .where((s) => !s.completed && _isWithinScope(s.date))
          .toList(growable: false);
      final ongoing = ongoingList.isEmpty
          ? 0
          : (ongoingOverrideSeconds ?? ongoingList.first.durationSeconds);
      return completed + ongoing;
    }
    // All time
    return StatsService.secondsForScope(
      sessions,
      StatsScope.all,
      includeOngoing: true,
      now: now,
    );
  }

  // Pretty format hours/minutes
  String _formatHM(int seconds) {
    if (seconds <= 0) return '0M';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}H ${m}M';
    if (h > 0) return '${h}H';
    return '${m}M';
  }

  // Scope filter helper
  bool _isWithinScope(DateTime dt) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (_statsScope == 'today') {
      return dt.isAfter(startOfToday) || dt.isAtSameMomentAs(startOfToday);
    }
    if (_statsScope == 'week') {
      // Last 7 days (including today)
      final start = startOfToday.subtract(const Duration(days: 6));
      return (dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
          dt.isBefore(startOfToday.add(const Duration(days: 1)));
    }
    return true; // all time
  }

  @override
  void initState() {
    super.initState();
    try {
      final box = Hive.box('userBox');
      _statsScope = (box.get('statsScope') as String?) ?? 'all';
    } catch (_) {}
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
              // (scope chooser will be rendered below the username)
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey.shade200,
                foregroundImage: gUserPhotoUrl != null
                    ? NetworkImage(gUserPhotoUrl!)
                    : null,
                child: gUserPhotoUrl == null
                    ? const Icon(Icons.person, color: Colors.black)
                    : null,
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
              const SizedBox(height: 12),
              // Stats scope chooser (chips under username, without title)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _statsScope == 'today',
                          onSelected: (sel) async {
                            if (!sel) return;
                            setState(() => _statsScope = 'today');
                            try {
                              await Hive.box(
                                'userBox',
                              ).put('statsScope', 'today');
                            } catch (_) {}
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _statsScope == 'today'
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          shape: StadiumBorder(
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Week'),
                          selected: _statsScope == 'week',
                          onSelected: (sel) async {
                            if (!sel) return;
                            setState(() => _statsScope = 'week');
                            try {
                              await Hive.box(
                                'userBox',
                              ).put('statsScope', 'week');
                            } catch (_) {}
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _statsScope == 'week'
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          shape: StadiumBorder(
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('All Time'),
                          selected: _statsScope == 'all',
                          onSelected: (sel) async {
                            if (!sel) return;
                            setState(() => _statsScope = 'all');
                            try {
                              await Hive.box(
                                'userBox',
                              ).put('statsScope', 'all');
                            } catch (_) {}
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: _statsScope == 'all'
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          shape: StadiumBorder(
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.only(
                        left: _statsScope == 'today'
                            ? 21.0
                            : _statsScope == 'week'
                            ? 18.0
                            : 50.0,
                      ),
                      child: Text(
                        _statsScope == 'today'
                            ? 'Shows activity from midnight to now.'
                            : _statsScope == 'week'
                            ? 'Shows the last 7 days, including today.'
                            : 'Shows all recorded activity.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(height: 20),
              // Stats from local backend (Hive sessionBox)
              ValueListenableBuilder<Box<WorkoutSession>>(
                valueListenable: Hive.box<WorkoutSession>(
                  'sessionBox',
                ).listenable(),
                builder: (context, box, _) {
                  final sessions = box.values.toList(growable: false);
                  final streak = _computeStreak(sessions);
                  final completed = _computeCompletedCount(sessions);
                  return BlocBuilder<SessionCubit, SessionState>(
                    buildWhen: (prev, curr) =>
                        prev.ongoing?.durationSeconds !=
                        curr.ongoing?.durationSeconds,
                    builder: (context, s) {
                      final ongoingOverride = s.ongoing?.durationSeconds;
                      // Minutes breakdown with override so live minutes tick and pause correctly
                      final totalSec = _scopedSecondsIndexedWithOngoingOverride(
                        sessions,
                        ongoingOverride,
                      );
                      final hasOngoing = sessions.any(
                        (s) => !s.completed && _isWithinScope(s.date),
                      );
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatHM(totalSec),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    if (hasOngoing) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        key: const Key('minutes_live_dot'),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
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
                  );
                },
              ),

              // Removed: "Include ongoing minutes" toggle (now always enabled)
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

              // AI Companion Settings removed (moved to dedicated screen)

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

// (Settings UI moved to Altrix Settings screen)

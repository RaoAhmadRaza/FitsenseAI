import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'features/home/widgets/home_quick_actions.dart';
import 'features/home/widgets/ongoing_session_panel.dart';
// Removed direct intl usage; date formatting centralized in core/utils/formatters.dart
import 'logic/workouts/workouts_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/presentation/widgets/colors.dart';
import 'features/auth/presentation/pages/workouts.dart';
import 'features/auth/presentation/pages/profileSettings.dart';
import 'logic/auth_bloc/auth_bloc.dart';
import 'logic/auth_bloc/auth_state.dart';
import 'logic/auth_bloc/auth_event.dart';
import 'logic/session/session_cubit.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:awesome_icons/awesome_icons.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'core/utils/formatters.dart';
import 'core/navigation/app_navigator.dart';
import 'main.dart'
    show
        gUserUid,
        gUserEmail,
        gUserDisplayName,
        gUserPhotoUrl,
        gUserAge,
        gUserWeightKg,
        gUserHeightCm,
        gUserHeightUnit,
        gUserGender,
        gUserGoals,
        gUserPrimaryGoal;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.fitnessBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.fitnessBlue,
          onPrimary: AppColors.primaryBlack,
          secondary: AppColors.healthGreen,
          onSecondary: AppColors.primaryBlack,
          error: AppColors.vibrantRed,
          onError: AppColors.primaryBlack,
          surface: AppColors.lightGray,
          onSurface: AppColors.primaryBlack,
        );

    return MaterialApp(
      title: 'AI Fitness Tracker',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryBlack,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: scheme,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.white),
          bodyMedium: TextStyle(color: AppColors.white),
          bodySmall: TextStyle(color: AppColors.secondaryGray),
          titleLarge: TextStyle(color: AppColors.white),
          titleMedium: TextStyle(color: AppColors.white),
          titleSmall: TextStyle(color: AppColors.secondaryGray),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.fitnessBlue,
          foregroundColor: AppColors.primaryBlack,
        ),
      ),
      home: const MyHomePage(title: 'AI Fitness Tracker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _pageController = PageController(initialPage: 0);
  final NotchBottomBarController _controller = NotchBottomBarController(
    index: 0,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            if (_controller.index != index) {
              _controller.jumpTo(index);
            }
          },
          children: const [_HomeTab(), WorkoutsPage(), ProfileSettings()],
        ),
        bottomNavigationBar: AnimatedNotchBottomBar(
          notchBottomBarController: _controller,
          color: Colors.white,
          showLabel: true,
          textOverflow: TextOverflow.visible,
          maxLine: 1,
          shadowElevation: 2,
          kBottomRadius: 29.0,
          notchColor: AppColors.vibrantRed,
          removeMargins: false,
          // Reduced width for a more compact bottom nav bar
          bottomBarWidth: 300,
          showShadow: true,
          durationInMilliSeconds: 320,
          itemLabelStyle: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.black,
            fontWeight: FontWeight.w500,
          ),
          elevation: 2,
          onTap: (index) => _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
          kIconSize: 24.0,
          bottomBarItems: const [
            BottomBarItem(
              inActiveItem: Icon(
                Icons.home_filled,
                color: CupertinoColors.black,
              ),
              activeItem: Icon(Icons.home_filled, color: Colors.white),
              itemLabel: 'Home',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                Icons.fitness_center,
                color: CupertinoColors.black,
              ),
              activeItem: Icon(Icons.fitness_center, color: Colors.white),
              itemLabel: 'Workouts',
            ),
            BottomBarItem(
              inActiveItem: Icon(Icons.person, color: CupertinoColors.black),
              activeItem: Icon(Icons.person, color: Colors.white),
              itemLabel: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Removed inline recovery + ongoing widgets in favor of OngoingSessionPanel.

/// Home tab content extracted from previous MyHomePage body
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: StartPlanActionScope(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 40),
              if (kDebugMode == true)
                TextButton(
                  onPressed: () {
                    try {
                      if (Hive.isBoxOpen('userBox')) {
                        final box = Hive.box('userBox');
                        box.deleteAll([
                          'uid',
                          'email',
                          'displayName',
                          'photoUrl',
                          'profile',
                          'profileComplete',
                        ]);
                      }
                    } catch (_) {}
                    gUserUid = null;
                    gUserEmail = null;
                    gUserDisplayName = null;
                    gUserPhotoUrl = null;
                    gUserAge = null;
                    gUserWeightKg = null;
                    gUserHeightCm = null;
                    gUserHeightUnit = 'cm';
                    gUserGender = null;
                    gUserGoals.clear();
                    gUserPrimaryGoal = null;
                    context.read<AuthBloc>().add(const AuthSignOutRequested());
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              Container(
                height: 50,
                width: 370,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(70),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 10),
                    Lottie.network(
                      'https://lottie.host/2d58d506-a04c-4354-b6ed-b03812317093/5fPPvtbClc.json',
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Ask',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'Altrix',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Sora',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'for.....',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(right: 16.0),
                      child: Icon(
                        FontAwesomeIcons.microphoneAlt,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: gUserPhotoUrl != null
                          ? NetworkImage(gUserPhotoUrl!)
                          : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'HELLO!',
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Sora',
                                fontSize: 20,
                                letterSpacing: -1,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              gUserDisplayName?.split(' ').first ?? 'User',
                              style: const TextStyle(
                                color: Colors.black,
                                fontFamily: 'Sora',
                                fontSize: 20,
                                letterSpacing: -1,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Regain your healthy body',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Sora',
                            fontSize: 12,
                            wordSpacing: -1,
                            fontWeight: FontWeight.normal,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              EasyDateTimeLine(
                initialDate: DateTime.now(),
                timeLineProps: const EasyTimeLineProps(),
                activeColor: AppColors.vibrantRed,
              ),
              const SizedBox(height: 20),
              const HomeQuickActions(),
              const SizedBox(height: 24),
              const OngoingSessionPanel(),
              const SizedBox(height: 24),
              const _SuggestedPlanCard(),
              const SizedBox(height: 24),
              const _LastCompletedCard(),
              const SizedBox(height: 30),
              const Padding(
                padding: EdgeInsets.only(right: 250.0),
                child: Text(
                  'Exercies(3)',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const _ExercisesList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable exercise list widget that eliminates repetitive code
class _ExercisesList extends StatelessWidget {
  const _ExercisesList();

  static const List<Map<String, String>> _exercises = [
    {
      'title': 'Incline Dumbbell Bench Press',
      'subtitle': '3 Sets . 12 Reps',
      'image': 'assets/images/incline-dumbbell-bench-press_0.jpg',
    },
    {
      'title': 'Barbell Curl',
      'subtitle': '3 Sets . 10 Reps',
      'image': 'assets/images/barbell-curl.jpg',
    },
    {
      'title': 'Seated Arnold Press',
      'subtitle': '3 Sets . 8 Reps',
      'image': 'assets/images/seated-arnold-press-thumb.jpg',
    },
    {
      'title': 'Incline Bench Press',
      'subtitle': '3 Sets . 12 Reps',
      'image': 'assets/images/incline-bench-press.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100.0),
      child: Column(
        children: _exercises
            .map(
              (exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _ExerciseCard(
                  title: exercise['title']!,
                  subtitle: exercise['subtitle']!,
                  imagePath: exercise['image']!,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Reusable exercise card widget
class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: 370,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 10),
          _ExerciseImage(imagePath: imagePath),
          const SizedBox(width: 10),
          _ExerciseInfo(title: title, subtitle: subtitle),
          const Spacer(),
          const _ExerciseArrow(),
        ],
      ),
    );
  }
}

/// Reusable exercise image thumbnail widget
class _ExerciseImage extends StatelessWidget {
  final String imagePath;

  const _ExerciseImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(imagePath, fit: BoxFit.cover),
      ),
    );
  }
}

/// Reusable exercise info (title + subtitle) widget
class _ExerciseInfo extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ExerciseInfo({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.normal,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

/// Reusable exercise arrow icon widget
class _ExerciseArrow extends StatelessWidget {
  const _ExerciseArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 16.0),
      child: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
    );
  }
}

/// Reusable workout thumbnails row widget

/// Reusable individual workout thumbnail widget

class _LastCompletedCard extends StatelessWidget {
  const _LastCompletedCard();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        final last = state.lastCompleted;
        if (last == null) {
          return const SizedBox.shrink();
        }
        final totalSets = last.progress.fold<int>(
          0,
          (sum, p) => sum + p.completedSets,
        );
        final duration = formatDuration(last.durationSeconds);
        final dateStr = formatFriendlyDate(last.date);
        return Semantics(
          container: true,
          label:
              'Last workout on $dateStr, duration $duration, $totalSets sets across ${last.progress.length} exercises',
          child: Container(
            width: 370,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Last Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Sora',
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Sora',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metricBlock(label: 'Duration', value: duration),
                    const SizedBox(width: 16),
                    _metricBlock(label: 'Sets', value: '$totalSets'),
                    const SizedBox(width: 16),
                    _metricBlock(
                      label: 'Exercises',
                      value: '${last.progress.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      AppNavigator.sessionSummary(context, last.workoutId);
                    },
                    child: const Text('View Summary'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _metricBlock({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Sora',
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Sora',
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _SuggestedPlanCard extends StatelessWidget {
  const _SuggestedPlanCard();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutsCubit, WorkoutsState>(
      builder: (context, state) {
        // Kick off load on first build if needed
        if (state.status == WorkoutsStatus.initial) {
          // Delay to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.read<WorkoutsCubit>().load();
          });
        }

        if (state.status == WorkoutsStatus.loading) {
          return _planCardWrapper(
            child: Row(
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading plans...',
                  style: TextStyle(fontFamily: 'Sora', color: Colors.grey),
                ),
              ],
            ),
          );
        }
        if (state.status == WorkoutsStatus.error) {
          return _planCardWrapper(
            child: Text(
              state.errorMessage ?? 'Failed to load plans',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Sora',
                color: Colors.redAccent,
              ),
            ),
          );
        }
        final plans = state.plans;
        if (plans.isEmpty) {
          return _planCardWrapper(
            child: const Text(
              'No plans yet. Create one to get started.',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Sora',
                color: Colors.grey,
              ),
            ),
          );
        }
        // Prefer a selected plan, else first.
        final plan = state.selectedPlan ?? plans.first;
        final equipment = plan.equipment.isNotEmpty
            ? plan.equipment.take(3).join(', ')
            : 'Bodyweight';
        return _planCardWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Suggested Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Sora',
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '${plan.exercises.length} exercises',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Sora',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Sora',
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _planMetaChip(label: plan.level),
                  const SizedBox(width: 6),
                  _planMetaChip(
                    label: plan.durationDisplay.isEmpty
                        ? '--'
                        : plan.durationDisplay,
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: _planMetaChip(label: equipment)),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.vibrantRed,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => AppNavigator.startPlan(context, plan),
                  child: const Text(
                    'Start Plan',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Helper: consistent card container for suggested plan states
Widget _planCardWrapper({required Widget child}) => Container(
  width: 370,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: child,
);

Widget _planMetaChip({required String label}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.grey.shade200,
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    label,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 11,
      fontFamily: 'Sora',
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
  ),
);

// Local formatting helpers removed in favor of shared utilities in core/utils/formatters.dart

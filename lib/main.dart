import 'package:ai_fitness_tracker/features/auth/presentation/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart' as firebase_options;

import 'features/auth/presentation/pages/welcome.dart';
import 'features/presentation/widgets/colors.dart';
import 'app.dart';
import 'logic/auth_bloc/auth_bloc.dart';
import 'logic/auth_bloc/auth_event.dart';
import 'logic/auth_bloc/auth_state.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'core/db/app_database.dart'; // SQLite layer
import 'features/debug/sensor_demo_page.dart';
import 'features/workout/data/workout_session_repository.dart';
import 'core/models/workout_session.dart'; // WorkoutSession + ExerciseProgress Hive models
import 'core/models/exercise_set.dart';
import 'logic/session/session_cubit.dart';
import 'core/models/workout_plan.dart';
import 'core/models/session_runtime.dart';
import 'features/workout/data/workout_plan_repository.dart';
import 'logic/workouts/workouts_cubit.dart';
import 'features/home/pages/plan_browser_placeholder.dart';
import 'features/home/pages/plan_detail_screen.dart';
import 'features/home/pages/history_placeholder.dart';
import 'features/auth/presentation/pages/inividualWorkout.dart';
import 'core/navigation/app_routes.dart';
import 'features/workout/pages/session_summary_screen.dart';

// Global user info (populated after sign-in)
String? gUserUid;
String? gUserEmail;
String? gUserDisplayName;
String? gUserPhotoUrl;
// Extended profile fields (persisted locally via Hive)
int? gUserAge; // years
double? gUserWeightKg; // kilograms
double? gUserHeightCm; // canonical centimeters
String gUserHeightUnit = 'cm';
String? gUserGender; // 'male' | 'female'
Set<String> gUserGoals = <String>{};
String? gUserPrimaryGoal; // one of goals (optional)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: firebase_options.DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  // Open (or create) a Hive box for user profile caching
  await Hive.openBox('userBox');

  // Register workout session adapters (idempotent guard) & open session box.
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(ExerciseProgressAdapter());
  }
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(WorkoutSessionAdapter());
  }
  if (!Hive.isAdapterRegistered(12)) {
    Hive.registerAdapter(ExerciseSetAdapter());
  }
  if (!Hive.isAdapterRegistered(13)) {
    Hive.registerAdapter(PlanExerciseAdapter());
  }
  if (!Hive.isAdapterRegistered(14)) {
    Hive.registerAdapter(WorkoutPlanAdapter());
  }
  if (!Hive.isAdapterRegistered(15)) {
    Hive.registerAdapter(SessionRuntimeAdapter());
  }
  // Box holds serialized WorkoutSession objects; fast path for ongoing/last sessions.
  await Hive.openBox<WorkoutSession>('sessionBox');
  // Separate box for granular per-set tracking (optional layer).
  await Hive.openBox<ExerciseSet>('exerciseSetBox');
  // Box for workout plan templates (re-usable definitions, not active sessions)
  await Hive.openBox<WorkoutPlan>('workoutPlanBox');
  await Hive.openBox<SessionRuntime>('sessionRuntimeBox');

  // Initialize SQLite and attempt to hydrate extended profile into globals.
  try {
    await AppDatabase.instance();
    await AppDatabase.loadUserProfileIntoGlobals();
    // Migration safeguard: if SQLite has no profile yet but Hive does,
    // load from Hive into globals and persist to SQLite so future restarts rehydrate.
    if (gUserDisplayName == null &&
        gUserAge == null &&
        gUserWeightKg == null &&
        gUserHeightCm == null &&
        Hive.isBoxOpen('userBox')) {
      final box = Hive.box('userBox');
      final data = box.get('profile');
      if (data is Map && data.isNotEmpty) {
        gUserDisplayName = (data['name'] as String?) ?? gUserDisplayName;
        gUserAge = data['age'] as int? ?? gUserAge;
        gUserWeightKg = (data['weightKg'] as num?)?.toDouble() ?? gUserWeightKg;
        gUserHeightCm = (data['heightCm'] as num?)?.toDouble() ?? gUserHeightCm;
        gUserHeightUnit = (data['heightUnit'] as String?) ?? gUserHeightUnit;
        gUserGender = (data['gender'] as String?) ?? gUserGender;
        final goalsList = (data['goals'] as List?)?.cast<String>() ?? const [];
        gUserGoals = goalsList.toSet();
        // Persist this hydrated profile to SQLite for durability across restarts
        try {
          await AppDatabase.saveUserProfileFromGlobals();
        } catch (_) {}
      }
    }
  } catch (e) {
    // Silently ignore DB init errors for now; could log or report in future.
  }

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => AuthRepository()),
        RepositoryProvider<WorkoutSessionRepository>(
          create: (_) => WorkoutSessionRepository(),
        ),
        RepositoryProvider<WorkoutPlanRepository>(
          create: (_) => WorkoutPlanRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepository>())
                  ..add(const AuthStarted()),
          ),
          BlocProvider<SessionCubit>(
            create: (context) =>
                SessionCubit(context.read<WorkoutSessionRepository>())
                  ..refresh(),
          ),
          BlocProvider<WorkoutsCubit>(
            create: (context) =>
                WorkoutsCubit(context.read<WorkoutPlanRepository>())..load(),
          ),
        ],
        child: const _RootApp(),
      ),
    ),
  );
}

class _RootApp extends StatefulWidget {
  const _RootApp();

  @override
  State<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<_RootApp> {
  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // TODO: Implement real deep link listener (e.g., using uni_links).
    // Placeholder: In future, parse initial uri and any stream events.
    // Example mapping: ai-fit://plans/<id> -> pushNamed(AppRoutes.planDetail(<id>))
    // final initialUri = await getInitialUri();
    // if (initialUri != null) _handleUri(initialUri);
  }

  // ignore: unused_element
  void _handleUri(Uri uri) {
    // Basic pattern match for ai-fit scheme.
    if (uri.scheme == 'ai-fit') {
      if (uri.host == 'plans' && uri.pathSegments.isNotEmpty) {
        final planId = uri.pathSegments.first;
        // Delay push until after first frame to ensure navigator is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushNamed(AppRoutes.planDetail(planId));
          }
        });
      }
    }
    // TODO: analytics: deep_link_open(uri.toString())
  }

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
        fontFamily: 'Sora',
        scaffoldBackgroundColor: AppColors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryBlack,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: scheme,
      ),
      // Declarative root selection based on auth + profile completion.
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          // Fast synchronous read; box already opened in main().
          final box = Hive.box('userBox');
          final pc = box.get('profileComplete') == true;
          final pcUid = box.get('profileCompleteUid');

          // Authenticated user path
          if (state is AuthAuthenticated) {
            final currentUid = state.user.uid;
            // Consider profile complete only when flag is true and bound to this uid (or legacy unset)
            final profileComplete =
                pc && (pcUid == null || pcUid == currentUid);
            if (profileComplete) {
              return const MyHomePage(title: 'AI Fitness Tracker');
            } else {
              // Still need to finish onboarding/profile – keep them in welcome flow.
              return const WelcomeScreen();
            }
          }

          if (state is AuthLoading) {
            return const _SplashScreen();
          }

          // Unauthenticated (or initial) -> Welcome
          return const WelcomeScreen();
        },
      ),
      routes: {
        AppRoutes.home: (_) => const MyHomePage(title: 'AI Fitness Tracker'),
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.sensors: (_) => const SensorDemoPage(),
        AppRoutes.plans: (_) => const PlanBrowserScreen(),
        AppRoutes.history: (_) => const HistoryPlaceholder(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final planDetail = RegExp(r'^/plans/([^/]+)$').firstMatch(name);
        if (planDetail != null) {
          final planId = planDetail.group(1)!;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PlanDetailScreen(planId: planId),
          );
        }
        final workout = RegExp(r'^/workout/([^/]+)$').firstMatch(name);
        if (workout != null) {
          final sessionId = workout.group(1)!;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Inividualworkout(sessionWorkoutId: sessionId),
          );
        }
        final summary = RegExp(r'^/session/summary/([^/]+)$').firstMatch(name);
        if (summary != null) {
          final sessionId = summary.group(1)!;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => SessionSummaryScreen(sessionId: sessionId),
          );
        }
        return null; // default fallthrough
      },
    );
  }
}

/// Simple splash/loading placeholder for auth transitions.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.vibrantRed),
      ),
    );
  }
}

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
import 'features/auth/data/repositories/auth_repository.dart';
import 'core/db/app_database.dart'; // SQLite layer
import 'features/debug/sensor_demo_page.dart';

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

  // Initialize SQLite and attempt to hydrate extended profile into globals.
  try {
    await AppDatabase.instance();
    await AppDatabase.loadUserProfileIntoGlobals();
  } catch (e) {
    // Silently ignore DB init errors for now; could log or report in future.
  }

  runApp(
    RepositoryProvider(
      create: (_) => AuthRepository(),
      child: BlocProvider(
        create: (context) =>
            AuthBloc(authRepository: context.read<AuthRepository>())
              ..add(const AuthStarted()),
        child: const _RootApp(),
      ),
    ),
  );
}

class _RootApp extends StatelessWidget {
  const _RootApp();

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
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomeScreen(), // login screen
        '/home': (_) => const MyHomePage(title: 'AI Fitness Tracker'),
        '/profile': (_) => const ProfilePage(),
        '/sensors': (_) => const SensorDemoPage(),
      },
    );
  }
}

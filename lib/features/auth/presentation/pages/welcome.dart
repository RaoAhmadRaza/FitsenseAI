// ignore_for_file: avoid_unnecessary_containers
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_bloc.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_event.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_state.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:entry/entry.dart';
import 'package:lottie/lottie.dart';
import '../../../../main.dart'
    show gUserUid, gUserEmail, gUserDisplayName, gUserPhotoUrl; // globals
import '../../../../core/db/app_database.dart';
import '../../../../core/utils/logger.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

enum _Stage { landing, auth, greeting }

class _WelcomeScreenState extends State<WelcomeScreen> {
  _Stage _stage = _Stage.landing;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current != null && Hive.isBoxOpen('userBox')) {
        final box = Hive.box('userBox');
        final cachedUid = box.get('uid');
        if (cachedUid != null && cachedUid == current.uid) {
          gUserUid = cachedUid;
          gUserEmail = box.get('email');
          gUserDisplayName = box.get('displayName');
          gUserPhotoUrl = box.get('photoUrl');
          _stage = _Stage.greeting;
          _restored = true;
        }
      }
    } catch (_) {}
  }

  void _goToAuth() {
    setState(() {
      _stage = _Stage.auth;
    });
  }

  void _onAuthenticated(User user) async {
    gUserUid = user.uid;
    gUserEmail = user.email ?? '';
    gUserDisplayName = user.displayName ?? '';
    gUserPhotoUrl = user.photoURL;
    final box = Hive.box('userBox');
    await box.putAll({
      'uid': gUserUid,
      'email': gUserEmail,
      'displayName': gUserDisplayName,
      'photoUrl': gUserPhotoUrl,
      'lastLogin': DateTime.now().toIso8601String(),
    });

    // Persist profile basics to SQLite (ignore failures gracefully)
    try {
      await AppDatabase.saveUserProfileFromGlobals();
      logInfo('User profile persisted to SQLite');
    } catch (e, st) {
      logError('Failed saving profile to SQLite: $e', st);
    }

    if (!mounted) return;
    setState(() {
      _stage = _Stage.greeting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          _onAuthenticated(state.user);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (state is AuthUnauthenticated && (_stage == _Stage.greeting)) {
          _stage = _Stage.landing;
        }
        final isLoading = state is AuthLoading;

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset("assets/images/dl1.jpg", fit: BoxFit.cover),
              ),

              /// --- Landing stage ---
              if (_stage == _Stage.landing) ...[
                Entry.opacity(
                  duration: const Duration(seconds: 1),
                  visible: !_restored,
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 240.0),
                          child: Text(
                            'Balance Starts Here',
                            style: TextStyle(
                              color: AppColors.primaryBlack,
                              fontFamily: 'Sora',
                              fontSize: 16,
                              letterSpacing: -0.5,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.grey.shade200,
                              AppColors.vibrantRed,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            "FitSense AI",
                            style: TextStyle(
                              fontSize: 79,
                              fontFamily: 'Sora',
                              letterSpacing: -6,
                              wordSpacing: -9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                Entry.offset(
                  yOffset: 300,
                  delay: Duration(milliseconds: _restored ? 0 : 400),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _goToAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.vibrantRed,
                              foregroundColor: AppColors.primaryBlack,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shadowColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Start Moving',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              /// --- Auth Panel (Animated) ---
              if (_stage == _Stage.auth) ...[
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Entry.offset(
                    yOffset: 300,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.39,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(50),
                        ),
                      ),
                      child: _buildAuthContent(context),
                    ),
                  ),
                ),
              ],

              /// --- Greeting Panel ---
              if (_stage == _Stage.greeting) ...[
                Positioned.fill(
                  child: Entry.offset(
                    key: const ValueKey('greeting_screen'),
                    yOffset: 120,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      color: Colors.white,
                      child: _buildGreetingContent(context),
                    ),
                  ),
                ),
              ],

              /// --- Loading overlay ---
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            height: 52,
                            width: 52,
                            child: CircularProgressIndicator(
                              strokeWidth: 5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Signing you in...',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  /// --- Auth Content ---
  Widget _buildAuthContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Entry.offset(
            yOffset: 40,
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 800),
            child: const Text(
              "Let's Sign you in",
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 29,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Entry.opacity(
            duration: const Duration(milliseconds: 900),
            delay: const Duration(milliseconds: 200),
            child: Text(
              "Smarter workouts, personalized by\nAI — your fitness journey redefined.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                color: AppColors.secondaryGray,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Entry.offset(
            yOffset: 50,
            duration: const Duration(milliseconds: 900),
            delay: const Duration(milliseconds: 400),
            child: _buildSignInButton(
              context,
              icon: Bootstrap.google,
              label: "Sign in with Google",
              onTap: () => context.read<AuthBloc>().add(
                const AuthSignInWithGoogleRequested(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Entry.offset(
            yOffset: 50,
            duration: const Duration(milliseconds: 900),
            delay: const Duration(milliseconds: 600),
            child: _buildSignInButton(
              context,
              icon: Bootstrap.apple,
              label: "Sign in with Apple",
              onTap: () => context.read<AuthBloc>().add(
                const AuthSignInWithAppleRequested(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vibrantRed,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --- Greeting Content ---
  Widget _buildGreetingContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Entry.scale(
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutBack,

            child: Lottie.network(
              'https://lottie.host/2d58d506-a04c-4354-b6ed-b03812317093/5fPPvtbClc.json',
              width: 190,
              height: 200,
            ),
          ),
          const SizedBox(height: 20),
          Entry.opacity(
            delay: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 800),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'HELLO!',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 23,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  (gUserDisplayName ?? '').isNotEmpty
                      ? (gUserDisplayName!.split(' ').first)
                      : 'Friend',
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 23,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'I am',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 23,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.grey.shade400,
                      Colors.grey.shade800,
                      AppColors.vibrantRed,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    "ALTRIX",
                    style: TextStyle(
                      fontSize: 23,
                      fontFamily: 'Sora',
                      letterSpacing: -1,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Entry.offset(
            yOffset: 40,
            delay: const Duration(milliseconds: 700),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/sensors'),
              icon: const Icon(Icons.sensors, color: Colors.redAccent),
              label: const Text(
                'Open Sensor Demo',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Entry.opacity(
            delay: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 800),
            child: Text(
              "Your AI Fitness Companion — I'm here\nstep by step toward lasting progress.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                color: AppColors.secondaryGray,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Entry.offset(
            yOffset: 0,
            xOffset: -400,
            delay: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 800),

            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Tell me more about yourself",
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 16,
                      color: AppColors.secondaryGray,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: AppColors.vibrantRed,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

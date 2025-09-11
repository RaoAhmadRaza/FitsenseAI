// ignore_for_file: avoid_unnecessary_containers
import 'package:entry/entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
// Removed nested app import; we navigate via named routes now
import 'package:icons_plus/icons_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_bloc.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_event.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_state.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../main.dart'
    show gUserUid, gUserEmail, gUserDisplayName, gUserPhotoUrl; // globals
// Rely on root RepositoryProvider from main.dart

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  bool _showSecondScreen = false;
  bool _expandFull = false; // triggers full height animation after auth
  bool _hideAuthChildren = false; // hides buttons/text during expansion
  bool _showExpandedContent = false; // shows content after expansion
  bool _restoredFromCache = false; // prevents duplicate restoration
  late AnimationController _expandController;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _heightFactor = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );

    // Hydrate from Hive if user already cached (hot restart or cold start with existing session)
    try {
      if (Hive.isBoxOpen('userBox')) {
        final box = Hive.box('userBox');
        final cachedUid = box.get('uid');
        if (cachedUid != null) {
          // Also hydrate globals if empty
          gUserUid = cachedUid;
          gUserEmail = box.get('email');
          gUserDisplayName = box.get('displayName');
          gUserPhotoUrl = box.get('photoUrl');
          _showSecondScreen = true;
          _expandFull = true;
          _hideAuthChildren = true; // original auth UI hidden
          _showExpandedContent = true; // show expanded content immediately
          _restoredFromCache = true;
          // Skip animation: jump controller to end on next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _expandController.value = 1.0;
            }
          });
        }
      }
    } catch (_) {
      // silent: restoration is best-effort
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          // Persist user info before UI transition
          final user = state.user;
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

          // Start expansion animation
          setState(() {
            _hideAuthChildren = true; // fade out contents
            _expandFull = true;
          });
          await Future.delayed(const Duration(milliseconds: 40));
          // Run animation once and remain on this screen (no navigation)
          await _expandController.forward();
          if (mounted) {
            setState(() {
              _showExpandedContent = true; // reveal new content
            });
          }
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        // If auth bloc reports authenticated but we didn't yet expand (e.g., no Hive cache path), fast-forward
        if (state is AuthAuthenticated && !_restoredFromCache && !_expandFull) {
          // fast-forward without animation flicker
          _showSecondScreen = true;
          _expandFull = true;
          _hideAuthChildren = true;
          _showExpandedContent = true;
          _expandController.value = 1.0;
          _restoredFromCache = true;
        }
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset("assets/images/dl1.jpg", fit: BoxFit.cover),
              ),
              if (_showSecondScreen == false)
                Entry.opacity(
                  visible: !_showSecondScreen,
                  duration: const Duration(seconds: 1),
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
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              if (_showSecondScreen == false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Entry.offset(
                      yOffset: 300,
                      duration: const Duration(seconds: 2),
                      delay: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showSecondScreen = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.vibrantRed,
                              foregroundColor: AppColors.primaryBlack,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shadowColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
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
              // second screen
              if (_showSecondScreen == true)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _heightFactor,
                    builder: (context, child) {
                      final fullHeight = MediaQuery.of(context).size.height;
                      final baseHeight = fullHeight * 0.42;
                      final targetHeight = _expandFull
                          ? baseHeight +
                                (fullHeight - baseHeight) * _heightFactor.value
                          : baseHeight;
                      return Container(
                        height: targetHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: _expandFull
                              ? BorderRadius.zero
                              : const BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  topRight: Radius.circular(50),
                                ),
                        ),
                        child: ClipRRect(
                          borderRadius: _expandFull
                              ? BorderRadius.zero
                              : const BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  topRight: Radius.circular(50),
                                ),
                          child: Stack(
                            children: [
                              // Original sign-in content (fades out)
                              AnimatedOpacity(
                                opacity: _hideAuthChildren ? 0 : 1,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Entry.offset(
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                        curve: Curves.easeInOut,
                                        child: Text(
                                          "Let's Sign you in",
                                          style: TextStyle(
                                            fontFamily: 'Sora',
                                            fontSize: 29,
                                            color: AppColors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Entry.opacity(
                                        visible: true,
                                        delay: Duration(milliseconds: 500),
                                        duration: const Duration(seconds: 1),
                                        curve: Curves.easeInOut,
                                        child: Text(
                                          "Smarter workouts, personalized by \n                AI your fitness journey\n                          redefined.",
                                          style: TextStyle(
                                            fontFamily: 'Sora',
                                            fontSize: 14,
                                            color: AppColors.secondaryGray,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Entry.offset(
                                        delay: Duration(milliseconds: 600),
                                        duration: const Duration(seconds: 1),
                                        curve: Curves.easeInOut,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 40.0,
                                          ),
                                          child: SizedBox(
                                            width: 250,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                context.read<AuthBloc>().add(
                                                  const AuthSignInWithGoogleRequested(),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.vibrantRed,
                                                foregroundColor:
                                                    AppColors.primaryBlack,
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 15,
                                                ),
                                                shadowColor: AppColors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Bootstrap.google,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 20),
                                                  const Text(
                                                    'Sign in with Google',
                                                    style: TextStyle(
                                                      fontFamily: 'Sora',
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Entry.offset(
                                        delay: Duration(milliseconds: 700),
                                        duration: const Duration(seconds: 1),
                                        curve: Curves.easeInOut,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 40.0,
                                          ),
                                          child: SizedBox(
                                            width: 250,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                context.read<AuthBloc>().add(
                                                  const AuthSignInWithAppleRequested(),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.vibrantRed,
                                                foregroundColor:
                                                    AppColors.primaryBlack,
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 15,
                                                ),
                                                shadowColor: AppColors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Bootstrap.apple,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 20),
                                                  const Text(
                                                    'Sign in with Apple',
                                                    style: TextStyle(
                                                      fontFamily: 'Sora',
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // New expanded content (fades in after animation)
                              if (_showExpandedContent)
                                Padding(
                                  padding: const EdgeInsets.only(top: 200.0),
                                  child: Center(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Entry.scale(
                                          duration: const Duration(seconds: 1),
                                          curve: Curves.easeInOut,

                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 20.0,
                                            ),
                                            child: Lottie.network(
                                              'https://lottie.host/1f330b2b-235b-467b-a072-dff21e9b352c/FkKsSsj6pM.json',
                                              height: 230,
                                            ),
                                          ),
                                        ),

                                        Entry.opacity(
                                          visible: true,
                                          delay: Duration(milliseconds: 500),
                                          duration: const Duration(seconds: 1),
                                          curve: Curves.easeInOut,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'HELLO!',
                                                style: TextStyle(
                                                  fontFamily: 'Sora',
                                                  fontSize: 20,
                                                  color:
                                                      AppColors.secondaryGray,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 3),

                                              Text(
                                                gUserDisplayName!
                                                    .split(' ')
                                                    .first,
                                                style: TextStyle(
                                                  fontFamily: 'Sora',
                                                  fontSize: 20,
                                                  color: AppColors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 3),

                                              Text(
                                                'I am',
                                                style: TextStyle(
                                                  fontFamily: 'Sora',
                                                  fontSize: 20,
                                                  color: AppColors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 3),
                                              ShaderMask(
                                                shaderCallback: (bounds) =>
                                                    LinearGradient(
                                                      colors: [
                                                        Colors.grey.shade900,
                                                        AppColors.vibrantRed,
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ).createShader(bounds),
                                                child: const Text(
                                                  "ALTRIX",
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontFamily: 'Sora',

                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Entry.opacity(
                                          visible: true,
                                          delay: Duration(milliseconds: 900),
                                          duration: const Duration(seconds: 1),
                                          curve: Curves.easeInOut,
                                          child: Text(
                                            " Your AI Fitness Companion \n       I’m here to guide you, \n                 step by step, \n      toward lasting progress.",
                                            style: TextStyle(
                                              fontFamily: 'Sora',
                                              fontSize: 14,
                                              color: AppColors.secondaryGray,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Entry.offset(
                                          xOffset: -200,
                                          yOffset: 0,
                                          delay: Duration(seconds: 1),
                                          duration: const Duration(seconds: 1),
                                          curve: Curves.easeInOut,
                                          child: TextButton(
                                            onPressed: () {},
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Here's what I can do for you",
                                                  style: TextStyle(
                                                    fontFamily: 'Sora',
                                                    fontSize: 16,
                                                    color:
                                                        AppColors.secondaryGray,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
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
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (isLoading)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
          ), // end Stack
        ); // end Scaffold
      },
    ); // end BlocConsumer
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

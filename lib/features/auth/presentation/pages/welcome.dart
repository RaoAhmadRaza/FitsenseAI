// ignore_for_file: avoid_unnecessary_containers
import 'package:entry/entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
// Removed nested app import; we navigate via named routes now
import 'package:icons_plus/icons_plus.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_bloc.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_event.dart';
import 'package:ai_fitness_tracker/logic/auth_bloc/auth_state.dart';
// Rely on root RepositoryProvider from main.dart

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showSecondScreen = false;
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/images/dl1.jpg", fit: BoxFit.cover),
            ),
            if (_showSecondScreen == false)
              Entry.opacity(
                visible: !_showSecondScreen,
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 70.0),
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
                      Padding(
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
                    ],
                  ),
                ),
              ),
            // second screen
            if (_showSecondScreen == true)
              Align(
                alignment: Alignment.bottomCenter,
                child: Entry.offset(
                  yOffset: 500,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.38,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(50),
                        topRight: Radius.circular(50),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Entry.offset(
                            duration: const Duration(milliseconds: 900),
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
                              padding: EdgeInsets.symmetric(horizontal: 40.0),
                              child: SizedBox(
                                width: 250,
                                child: ElevatedButton(
                                  onPressed: () {
                                    context.read<AuthBloc>().add(
                                      const AuthSignInWithGoogleRequested(),
                                    );
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                          fontWeight: FontWeight.bold,
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
                              padding: EdgeInsets.symmetric(horizontal: 40.0),
                              child: SizedBox(
                                width: 250,
                                child: ElevatedButton(
                                  onPressed: () {
                                    context.read<AuthBloc>().add(
                                      const AuthSignInWithAppleRequested(),
                                    );
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                          fontWeight: FontWeight.bold,
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
                ),
              ),
          ],
        ), // end Stack
      ), // end Scaffold
    ); // end BlocListener
  }
}

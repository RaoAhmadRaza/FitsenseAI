import 'package:intro_onboarding_slider/intro_onboarding_slider.dart';
import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:ai_fitness_tracker/app.dart';
import 'package:ai_fitness_tracker/features/auth/presentation/pages/welcome.dart';

class OnBoardingScreens extends StatelessWidget {
  const OnBoardingScreens({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: OnboardingPages());
  }
}

class OnboardingPages extends StatelessWidget {
  const OnboardingPages({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      OnboardingPageData.fromLottieNetwork(
        title: 'Personalized Plans, Powered by AI',
        description:
            'Get custom workouts tailored to your goals, schedule, and progress—updated automatically as you improve',
        url:
            'https://lottie.host/f8382b81-a8bd-4251-95d9-144e87c28013/KkjzUgwVAO.json',
      ),
      OnboardingPageData.fromLottieNetwork(
        title: 'Track Every Move in Real Time',
        description:
            'Your phone and wearables analyze reps, pace, and form using device sensors to keep you efficient and injury-free.',
        url:
            'https://lottie.host/30a62095-f250-4395-84db-2e15a0a92931/g15coIFMEY.json',
      ),
      OnboardingPageData.fromLottieNetwork(
        title: 'Progress That Works Offline',
        description:
            'Log workouts without internet; your data saves locally and syncs securely to the cloud when you’re back online.',
        url:
            'https://lottie.host/e733df50-1b42-4b8b-9dde-81dce80ce53b/c8uJPoHzkE.json',
      ),
      OnboardingPageData.fromLottieNetwork(
        title: 'Insights That Adapt to You',
        description:
            'Smart recommendations for intensity, recovery, and habits—helping you build sustainable, consistent fitness.',
        url:
            'https://lottie.host/b0318568-cdd0-493f-91c3-85c44221a3d5/55XkWrDGpR.json',
      ),
    ];
    return IntroOnboardingFlow(
      pages: pages,
      layoutStyle: IoLayoutStyle.compact,
      // Backdrop
      gradientStartColor: AppColors.white,
      gradientEndColor: AppColors.lightGray,
      // Indicators
      navActiveColor: AppColors.vibrantRed,
      navInactiveColor: AppColors.secondaryGray,
      // Text
      titleColor: AppColors.primaryBlack,
      descriptionColor: AppColors.secondaryGray,
      // Primary button
      primaryButtonBgColor: AppColors.vibrantRed,
      primaryButtonFgColor: AppColors.white,
      primaryButtonShadowColor: AppColors.white,
      // Skip / Next
      skipTextColor: AppColors.secondaryGray,
      nextButtonBgColor: AppColors.lightGray,
      nextButtonIconColor: AppColors.primaryBlack,

      showIndicatorOnLastPage: false,
      lastButtonStyle: IoLastButtonStyle.smallRounded,

      getStartedText: 'Continue',
      onSkip: () {
        // Navigate to the main app or home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      },
      onCompleted: () {
        // Navigate to the main app or home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:ai_fitness_tracker/app.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Sora',
        colorScheme: const ColorScheme.dark(),
      ),
      home: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dl1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
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
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              Text(
                'FitSense AI',
                style: TextStyle(
                  color: AppColors.primaryBlack,
                  fontFamily: 'Sora',
                  wordSpacing: -7,
                  letterSpacing: -6,
                  fontSize: 79,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const MyApp()),
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

                    child: Text(
                      'Start Moving',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 16,
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
    );
  }
}

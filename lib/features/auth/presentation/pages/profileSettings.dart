// ignore_for_file: unused_import, unused_shown_name
import 'package:ai_fitness_tracker/features/presentation/widgets/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../logic/auth_bloc/auth_bloc.dart';
import '../../../../logic/auth_bloc/auth_event.dart';
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
              IntrinsicHeight(
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
                          '12',
                          style: TextStyle(
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
                          '1H 20M',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Workout \n Minuets',
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
                          FontAwesomeIcons.dumbbell,
                          color: Colors.purpleAccent,
                          size: 30,
                        ),
                        SizedBox(height: 20),
                        Text(
                          '28',
                          style: TextStyle(
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
                      onPressed: () {},
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
                      onPressed: () {},
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
                        'Meal Plans',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Check your meal plan history and stats',
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
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
              TextButton(
                onPressed: () {},
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

import 'package:flutter/material.dart';

import '../../../presentation/widgets/colors.dart';
import 'inividualWorkout.dart';

class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _WorkoutHeader(),
            const _EquipmentSection(),
            const _ExercisesSection(),
            const _StartWorkoutButton(),
            const SizedBox(height: 100), // Bottom padding for nav bar
          ],
        ),
      ),
    );
  }
}

/// Main workout header with image, title, and workout details
class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          // Main content
          Positioned(
            top: 120,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WorkoutTitle(),
                const SizedBox(height: 20),
                const _WorkoutStats(),
                const SizedBox(height: 30),

                // Person with yoga mat image placeholder
              ],
            ),
          ),
          Positioned(
            top: 50,

            left: 130,

            child: Container(
              height: 390,
              width: 390,
              child: Image(
                fit: BoxFit.contain,
                image: AssetImage('assets/images/main.png'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Workout title and subtitle
class _WorkoutTitle extends StatelessWidget {
  const _WorkoutTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GET ACTIVE AGAIN',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'Sora',
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Chest, Core, Biceps',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// Workout statistics (Level and Time)
class _WorkoutStats extends StatelessWidget {
  const _WorkoutStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(label: 'Level', value: 'Beginner'),
        const SizedBox(width: 40),
        _StatItem(label: 'Time', value: '60 Min'),
      ],
    );
  }
}

/// Individual stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

/// Equipment needed section
class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection();

  static const List<Map<String, dynamic>> _equipment = [
    {
      'name': 'Exercise Mat',
      'image': 'assets/images/mat.png',
      'color': Colors.pink,
    },
    {
      'name': 'Dumbbells',
      'image': 'assets/images/dumbbell.png',
      'color': Colors.grey,
    },
    {
      'name': 'Treadmill',
      'image': 'assets/images/treadmill.png',
      'color': Colors.blue,
    },
    {
      'name': 'Weighted Rod',
      'image': 'assets/images/rod.png',
      'color': Colors.orange,
    },
    {
      'name': 'Bench',
      'image': 'assets/images/bench.png',
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Equipment\'s Needed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 90,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _equipment
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _EquipmentCard(
                          name: item['name'],
                          assetImage: item['image'],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual equipment card
class _EquipmentCard extends StatelessWidget {
  final String name;
  final String assetImage;

  const _EquipmentCard({required this.name, required this.assetImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 40,
              width: 40,

              child: Image(fit: BoxFit.contain, image: AssetImage(assetImage)),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Exercises section with list of exercises
class _ExercisesSection extends StatelessWidget {
  const _ExercisesSection();

  static const List<Map<String, String>> _exercises = [
    {
      'name': 'Treadmill',
      'target': 'Lower body',
      'duration': '20 min',
      'image': 'assets/images/dl1.jpg',
    },
    {
      'name': 'Bench Press',
      'target': 'Lower body',
      'duration': '3 sets X 10 reps X 75 lbs',
      'image': 'assets/images/incline-bench-press.jpg',
    },
    {
      'name': 'KB Bicep Curl',
      'target': 'Lower body',
      'duration': '3 sets X 10 reps X 75 lbs',
      'image': 'assets/images/barbell-curl.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exercises (${_exercises.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Add exercise functionality
                },
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.vibrantRed,
                  size: 20,
                ),
                label: const Text(
                  'Add Exercise',
                  style: TextStyle(
                    color: AppColors.vibrantRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Column(
            children: _exercises
                .map(
                  (exercise) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _ExerciseCard(
                      name: exercise['name']!,
                      target: exercise['target']!,
                      duration: exercise['duration']!,
                      imagePath: exercise['image']!,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Individual exercise card
class _ExerciseCard extends StatelessWidget {
  final String name;
  final String target;
  final String duration;
  final String imagePath;

  const _ExerciseCard({
    required this.name,
    required this.target,
    required this.duration,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drag handle
          Container(
            width: 20,
            child: Icon(
              Icons.drag_handle,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Exercise image
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Exercise details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  target,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          // Action button
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.refresh, color: Colors.grey.shade600, size: 16),
          ),
        ],
      ),
    );
  }
}

/// Start workout button
class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: () {
            // Start workout functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Starting workout...'),
                backgroundColor: AppColors.vibrantRed,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Inividualworkout()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.vibrantRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 2,
          ),
          child: const Text(
            'START WORKOUT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

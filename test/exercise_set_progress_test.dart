import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_tracker/features/workout/widgets/exercise_set_progress.dart';

void main() {
  group('ExerciseSetProgress', () {
    testWidgets('renders correct states for partial progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseSetProgress(totalSets: 3, completedSets: 1),
          ),
        ),
      );

      // Expect 3 chips
      expect(find.byType(AnimatedContainer), findsNWidgets(3));

      // Completed: first chip should contain check icon
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Active: should show the number 2
      expect(find.text('2'), findsOneWidget);

      // Pending: number 3 present
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('handles over-complete gracefully (clamp)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseSetProgress(totalSets: 2, completedSets: 5),
          ),
        ),
      );
      // Both should be completed -> two check icons
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('returns empty when totalSets is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseSetProgress(totalSets: 0, completedSets: 0),
          ),
        ),
      );
      // Row not built
      expect(find.byType(Row), findsNothing);
    });
  });
}

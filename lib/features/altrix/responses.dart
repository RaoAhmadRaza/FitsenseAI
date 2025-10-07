// Demo Altrix responses for prototyping the chat experience.
// This file provides a variety of message payloads you can use to mock
// assistant replies: plain text, tips, lists, mini plans, and suggestions.

import 'dart:math';

/// Lightweight shape for a demo response
/// Keys you may find on entries:
/// - id: String unique id
/// - type: String category like 'text' | 'tips' | 'plan' | 'warning' | 'quote' | 'list'
/// - title: Optional short title
/// - content: Primary textual content
/// - items: List of strings for bullet lists
/// - plan: Map describing a simple plan structure
/// - tags: List of strings for filtering (e.g., ['workout','beginner'])
/// - suggestions: List of strings with next-step prompts
/// Consumers should defensively access fields.
class AltrixDemoResponses {
  AltrixDemoResponses._();

  static final Random _rnd = Random();

  /// A diverse set of demo responses
  static const List<Map<String, Object?>> responses = [
    {
      'id': 'greet-1',
      'type': 'text',
      'title': 'Welcome',
      'content':
          'I\'m Altrix. Tell me your goal and time today, and I\'ll craft a plan you can do right now.',
      'tags': ['greeting', 'onboarding'],
      'suggestions': [
        'I have 20 minutes and dumbbells',
        'Design a 4-week strength plan',
        'What should I eat post workout?',
      ],
    },
    {
      'id': 'tips-recovery-1',
      'type': 'tips',
      'title': 'Faster Recovery Tonight',
      'items': [
        '10 minutes of easy walking after dinner',
        'Protein-rich snack (~25–35g) within 1–2 hours',
        'Magnesium (consult doctor) + 300–500ml water before bed',
        'Aim for 7–9 hours sleep, cool dark room',
      ],
      'tags': ['recovery', 'sleep', 'nutrition'],
      'suggestions': ['Guide me through a cooldown', 'Best protein options?'],
    },
    {
      'id': 'workout-quick-20min',
      'type': 'plan',
      'title': '20-Minute Full-Body (No Machines)',
      'plan': {
        'warmup': [
          '2 min brisk walk',
          '10 arm circles',
          '10 bodyweight squats',
        ],
        'main': [
          'EMOM 10 min: 10 push-ups, 15 air squats',
          'AMRAP 8 min: 8 reverse lunges/leg, 12 dumbbell rows',
        ],
        'cooldown': [
          '90s hamstring stretch',
          '90s quad stretch',
          '2 min nasal breathing',
        ],
      },
      'tags': ['workout', 'beginner', 'time-efficient', 'home'],
      'suggestions': [
        'Show me proper push-up form',
        'Swap bodyweight for dumbbells',
      ],
    },
    {
      'id': 'nutrition-post-1',
      'type': 'list',
      'title': 'Post-Workout Meals (Balanced)',
      'items': [
        'Greek yogurt bowl + berries + honey + granola',
        'Chicken, rice, veggies + olive oil',
        'Tofu stir-fry + soba noodles',
        'Protein smoothie: whey/pea + banana + oats + PB',
      ],
      'tags': ['nutrition', 'post-workout'],
      'suggestions': ['Calculate my macros', 'Vegetarian options only'],
    },
    {
      'id': 'form-squat-1',
      'type': 'text',
      'title': 'Squat Form Cue',
      'content':
          'Think “sit between your knees.” Keep ribs stacked over hips, knees track over toes, and push the floor away.',
      'tags': ['form', 'squat', 'technique'],
      'suggestions': [
        'What about deadlift setup?',
        'Front squat vs back squat?',
      ],
    },
    {
      'id': 'warning-general-1',
      'type': 'warning',
      'title': 'Safety First',
      'content':
          'If you have pain, dizziness, or a known medical condition, consult a medical professional before training.',
      'tags': ['safety', 'health'],
    },
    {
      'id': 'motivation-quote-1',
      'type': 'quote',
      'content': 'Small steps, consistently. That\'s how momentum is built.',
      'tags': ['mindset', 'motivation'],
      'suggestions': [
        'Give me a 10-minute beginner workout',
        'Daily habit tracker ideas',
      ],
    },
    {
      'id': 'hydration-1',
      'type': 'tips',
      'title': 'Hydration Targets',
      'items': [
        'Start your day with 300–500ml water',
        'Sip 150–250ml every 20–30 mins of exercise',
        'Electrolytes on hot/sweaty days',
      ],
      'tags': ['hydration', 'recovery'],
    },
    {
      'id': 'sleep-1',
      'type': 'tips',
      'title': 'Sleep Upgrades',
      'items': [
        'Consistent bedtime and wake time',
        'Dark, cool, quiet room (17–19°C)',
        'Limit screens 30–60 minutes before bed',
      ],
      'tags': ['sleep', 'recovery'],
    },
    {
      'id': 'habit-stack-1',
      'type': 'text',
      'title': 'Habit Stacking',
      'content':
          'Attach a 5-minute mobility routine to coffee time. Same cue, every day, tiny wins add up.',
      'tags': ['habits', 'mobility'],
    },
    {
      'id': 'warmup-quick-1',
      'type': 'list',
      'title': '4-Minute Warm-up',
      'items': [
        '1 min brisk walk or march in place',
        '10 hip hinges + 10 arm swings',
        '10 lunges total + 10 band pull-aparts',
      ],
      'tags': ['warmup', 'workout'],
    },
    {
      'id': 'cooldown-quick-1',
      'type': 'list',
      'title': '5-Minute Cooldown',
      'items': [
        '90s calf + hamstring stretch',
        '90s quad + hip flexor stretch',
        '2 min nasal breathing on the floor',
      ],
      'tags': ['cooldown', 'recovery'],
    },
    {
      'id': 'mobility-office-5min',
      'type': 'list',
      'title': '5-Min Office Mobility',
      'items': [
        'Neck circles x 5 each way',
        'Thoracic rotations x 8/side',
        'Chair hip openers x 10',
        'Ankle pumps x 20',
      ],
      'tags': ['mobility', 'office', 'quick'],
    },
    {
      'id': 'workout-beginner-3day',
      'type': 'plan',
      'title': 'Beginner 3-Day Split',
      'plan': {
        'days': [
          {
            'name': 'Day 1 – Push',
            'exercises': [
              'Incline push-ups 3x10–12',
              'DB overhead press 3x8–10',
              'Band chest fly 3x12',
            ],
          },
          {
            'name': 'Day 2 – Pull',
            'exercises': [
              'Assisted rows 3x10–12',
              'DB curls 3x10',
              'Face pulls 3x12',
            ],
          },
          {
            'name': 'Day 3 – Legs',
            'exercises': [
              'Goblet squat 3x8–10',
              'Hip hinge 3x10',
              'Split squat 3x8/leg',
            ],
          },
        ],
      },
      'tags': ['workout', 'beginner', 'split'],
      'suggestions': ['How to progress weekly?', 'Swap bands for bodyweight'],
    },
    {
      'id': 'running-couch-5k',
      'type': 'plan',
      'title': 'Couch to 5K (Simplified 4 Weeks)',
      'plan': {
        'weeks': [
          'Walk 3 min, jog 1 min x 5 (3 sessions)',
          'Walk 2 min, jog 2 min x 6 (3 sessions)',
          'Walk 1 min, jog 3 min x 6 (3 sessions)',
          'Jog 20–25 min continuous (2–3 sessions)',
        ],
      },
      'tags': ['running', 'beginner', 'endurance'],
    },
    {
      'id': 'weight-loss-basics',
      'type': 'text',
      'title': 'Weight Loss Pace',
      'content':
          'Target 0.25–0.75% of bodyweight lost per week with a modest calorie deficit, strength training, and adequate protein.',
      'tags': ['weight-loss', 'nutrition'],
      'suggestions': ['Estimate my calories', 'High-protein meal ideas'],
    },
    {
      'id': 'lean-bulk-1',
      'type': 'text',
      'title': 'Lean Bulk Guidance',
      'content':
          'Slight surplus (5–10% over maintenance), 1.6–2.2g/kg protein, progressive overload, sleep 7–9h.',
      'tags': ['muscle', 'nutrition'],
    },
    {
      'id': 'vegan-protein',
      'type': 'list',
      'title': 'Vegan Proteins',
      'items': [
        'Tofu/tempeh',
        'Seitan',
        'Lentils',
        'Chickpeas',
        'Edamame',
        'Pea protein',
      ],
      'tags': ['nutrition', 'vegan'],
    },
    {
      'id': 'home-no-equipment',
      'type': 'list',
      'title': 'No-Equipment Home Circuit',
      'items': [
        '3 rounds: 12 squats, 10 push-ups, 12 lunges/leg, 30s plank',
        'Rest 60–90s between rounds',
      ],
      'tags': ['workout', 'home', 'bodyweight'],
    },
    {
      'id': 'suggestions-1',
      'type': 'text',
      'title': 'Try Asking Me',
      'content':
          '“Build me a dumbbell-only push day.”\n“Make a 30-minute fat-burner.”\n“Fix my deadlift setup.”',
      'tags': ['prompting', 'assistant'],
    },
  ];

  /// Returns a random demo response.
  static Map<String, Object?> random() =>
      responses[_rnd.nextInt(responses.length)];

  /// Returns all responses with the provided tag (case-insensitive).
  static List<Map<String, Object?>> byTag(String tag) {
    final t = tag.toLowerCase();
    return responses
        .where(
          (e) =>
              (e['tags'] as List?)
                  ?.map((x) => x.toString().toLowerCase())
                  .contains(t) ==
              true,
        )
        .toList();
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../../../core/utils/formatters.dart';
import '../../../workout/widgets/exercise_set_progress.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../logic/session/session_cubit.dart';
import '../../../presentation/widgets/colors.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/models/session_runtime.dart';
import '../../../workout/widgets/exercise_queue.dart';
import '../../../../core/utils/plan_exercise_id.dart';

enum WorkoutState { ready, exercising, resting }

class Inividualworkout extends StatefulWidget {
  // Added optional sessionWorkoutId so we can resume an existing tracked session.
  final String? sessionWorkoutId;
  const Inividualworkout({super.key, this.sessionWorkoutId});

  @override
  State<Inividualworkout> createState() => _InividualworkoutState();
}

class _InividualworkoutState extends State<Inividualworkout> {
  WorkoutState currentState = WorkoutState.ready;
  String? get sessionWorkoutId => widget.sessionWorkoutId;

  // Exercise tracking
  int currentExercise = 1;
  int totalExercises = 3;
  int currentRound = 1;
  int totalRounds = 3;
  int currentReps = 0;
  int targetReps = 12;

  // Timer
  Timer? exerciseTimer;
  int seconds = 0;
  int minutes = 0;

  // Rest timer (accessibility live region)
  Timer? _restTimer;
  int _restRemaining = 0; // seconds
  int _lastRestAnnounced = -1; // throttle announcements

  // Focus for first interactive control when exercise starts/changes
  final FocusNode _repButtonFocus = FocusNode(debugLabel: 'repButton');

  // Exercise data
  String exerciseName = 'Incline Bench Press';
  String exerciseImage = 'assets/images/incline-bench-press.jpg';
  int weight = 70;

  bool _rehydrated = false; // prevent duplicate rehydration
  SessionRuntime? _runtime;
  bool _actionInFlight = false; // prevent double taps

  @override
  void initState() {
    super.initState();
    // Attempt to rehydrate if a session id was passed.
    if (sessionWorkoutId != null) {
      // Delay to ensure cubit/providers are ready in widget tree.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final cubit = context.read<SessionCubit>();
        await cubit.refresh();
        _rehydrateFromSession();
      });
    }
  }

  void _rehydrateFromSession() {
    if (_rehydrated) return;
    final cubit = context.read<SessionCubit>();
    final session = cubit.state.ongoing;
    if (session == null) return;
    // First try runtime box for authoritative UI ephemeral state
    final box = Hive.box<SessionRuntime>('sessionRuntimeBox');
    _runtime = box.get(session.workoutId);
    if (_runtime != null) {
      currentExercise = _runtime!.currentExerciseIndex;
      currentRound = _runtime!.currentRound;
      currentReps = _runtime!.currentRepsInSet;
      currentState = _runtime!.mode == 'exercising'
          ? WorkoutState.exercising
          : WorkoutState.ready; // resting treated as ready for now
      // Reconstruct timer baseline
      int base = _runtime!.accumulatedExerciseSeconds;
      if (_runtime!.exerciseStartedAt != null &&
          currentState == WorkoutState.exercising) {
        base += DateTime.now()
            .difference(_runtime!.exerciseStartedAt!)
            .inSeconds;
      }
      minutes = base ~/ 60;
      seconds = base % 60;
      if (currentState == WorkoutState.exercising) {
        _startPassiveTimer();
      }
    } else {
      // Fallback to heuristic if runtime absent.
      if (session.progress.isNotEmpty) {
        final last = session.progress.last;
        final parts = last.exerciseId.split('_');
        if (parts.length == 2) {
          final idx = int.tryParse(parts[1]);
          if (idx != null) currentExercise = idx;
        }
        currentReps = last.completedReps % targetReps;
        currentRound = (last.completedSets % totalRounds) + 1;
        if (last.completedReps > 0 || last.completedSets > 0) {
          currentState = WorkoutState.exercising;
          _startPassiveTimer();
        }
      }
    }
    _rehydrated = true;
    setState(() {});
  }

  void _announceExerciseChange() {
    // Announce exercise change politely for screen readers.
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    SemanticsService.announce(
      'Exercise $currentExercise: $exerciseName',
      direction,
    );
  }

  void _startPassiveTimer() {
    exerciseTimer?.cancel();
    exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        seconds++;
        if (seconds >= 60) {
          minutes++;
          seconds = 0;
        }
      });
    });
  }

  void startExercise() {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    final sessionCubit = context.read<SessionCubit>();
    final effectiveWorkoutId =
        sessionWorkoutId ?? 'workout_${DateTime.now().millisecondsSinceEpoch}';

    // Look at runtime BEFORE any reset to detect true resume.
    final preRuntime = sessionCubit.getRuntime(effectiveWorkoutId);
    final bool isResume = preRuntime != null && preRuntime.paused;

    if (!isResume && currentState != WorkoutState.exercising) {
      // Fresh start path: reset counters.
      setState(() {
        currentState = WorkoutState.exercising;
        seconds = 0;
        minutes = 0;
        currentReps = 0;
      });
      exerciseTimer?.cancel();
      exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          seconds++;
          if (seconds >= 60) {
            minutes++;
            seconds = 0;
          }
        });
      });
    } else if (isResume) {
      // Resume path: reconstruct timer from accumulated seconds only if we haven't already.
      final base = preRuntime.accumulatedExerciseSeconds;
      if ((minutes * 60 + seconds) != base) {
        setState(() {
          minutes = base ~/ 60;
          seconds = base % 60;
          currentState = WorkoutState.exercising;
        });
      } else if (currentState != WorkoutState.exercising) {
        setState(() => currentState = WorkoutState.exercising);
      }
      // Start passive timer if not already running
      exerciseTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          seconds++;
          if (seconds >= 60) {
            minutes++;
            seconds = 0;
          }
        });
      });
    }

    // Backend lifecycle: ensure session exists then branch start vs resume logic.
    sessionCubit.startSession(effectiveWorkoutId).then((session) async {
      if (session == null) {
        if (mounted) setState(() => _actionInFlight = false);
        return;
      }
      final runtime = sessionCubit.getRuntime(session.workoutId);
      if (runtime != null && runtime.paused) {
        // Resume semantics
        await sessionCubit.resumeSession();
        if (mounted) setState(() => _actionInFlight = false);
        // Focus the rep button after resume
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _repButtonFocus.requestFocus();
        });
        return; // Do not startExercise again.
      }
      // Fresh start semantics
      sessionCubit.startExercise(_exerciseTrackingId());
      if (mounted) setState(() => _actionInFlight = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _repButtonFocus.requestFocus();
      });
    });
  }

  void incrementReps() {
    setState(() {
      currentReps++;
      if (currentReps >= targetReps) {
        completeSet();
      }
    });
    context.read<SessionCubit>().incrementRep(_exerciseTrackingId());
  }

  void completeSet() {
    exerciseTimer?.cancel();

    // Log set to backend
    context.read<SessionCubit>().completeSet(
      _exerciseTrackingId(),
      repsInSet: currentReps,
      weight: weight,
      durationSeconds: (minutes * 60) + seconds,
    );
    final sessionCubit = context.read<SessionCubit>();
    final session = sessionCubit.state.ongoing;
    final runtime = session != null
        ? sessionCubit.getRuntime(session.workoutId)
        : null;

    setState(() {
      if (currentRound < totalRounds) {
        currentRound++;
        // Enter resting state between sets
        _startRestTimer(60);
      } else if (session != null && runtime?.planId != null) {
        // For plan sessions, use deterministic advancement based on plan length.
        final planId = runtime!.planId!;
        final nextIndex = currentExercise + 1;
        // Try to derive total exercises from session progress length if larger
        totalExercises = session.progress.length > totalExercises
            ? session.progress.length
            : totalExercises;
        if (nextIndex <= totalExercises) {
          currentExercise = nextIndex;
          currentRound = 1;
          _startRestTimer(60); // rest before next exercise
          final exId = PlanExerciseId.build(planId, nextIndex);
          // trigger backend to mark as active
          sessionCubit.startExercise(exId);
          _announceExerciseChange();
        } else {
          currentState = WorkoutState.ready;
          // TODO: analytics: session_complete(planSession=$planId)
          sessionCubit.completeSession();
          // Navigate to summary after a slight frame delay to ensure state refresh occurs.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamed('/session/summary/${session.workoutId}');
            }
          });
        }
      } else if (currentExercise < totalExercises) {
        // Legacy non-plan path
        currentExercise++;
        currentRound = 1;
        _startRestTimer(60);
        updateExerciseData();
        _announceExerciseChange();
      } else {
        currentState = WorkoutState.ready;
        final s = context.read<SessionCubit>();
        // TODO: analytics: session_complete(legacySession)
        s.completeSession();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && session != null) {
            Navigator.of(
              context,
            ).pushNamed('/session/summary/${session.workoutId}');
          }
        });
      }
    });
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    _restRemaining = seconds;
    currentState = WorkoutState.resting;
    _lastRestAnnounced = -1;
    // Immediate polite announce
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    SemanticsService.announce(
      'Rest $_restRemaining seconds remaining',
      direction,
    );
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) {
          t.cancel();
          currentState = WorkoutState.ready; // ready to start next set/exercise
        }
      });
      // Throttled announcements every 10s and final 5s countdown
      if (_restRemaining > 0 &&
          (_restRemaining % 10 == 0 || _restRemaining <= 5)) {
        if (_restRemaining != _lastRestAnnounced) {
          _lastRestAnnounced = _restRemaining;
          final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
          SemanticsService.announce(
            'Rest $_restRemaining seconds remaining',
            dir,
          );
        }
      }
    });
  }

  void updateExerciseData() {
    // Example: Update for different exercises
    switch (currentExercise) {
      case 2:
        exerciseName = 'Dumbbell Curl';
        exerciseImage = 'assets/images/barbell-curl.jpg';
        weight = 25;
        break;
      case 3:
        exerciseName = 'Bench Press';
        exerciseImage = 'assets/images/bench.png';
        weight = 135;
        break;
    }
  }

  // showWorkoutComplete dialog removed in favor of summary screen navigation.

  @override
  void dispose() {
    exerciseTimer?.cancel();
    _restTimer?.cancel();
    _repButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocBuilder<SessionCubit, SessionState>(
          builder: (context, sessionState) {
            // If a session just appeared & not yet rehydrated, try now.
            if (!_rehydrated && sessionWorkoutId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _rehydrateFromSession();
              });
            }
            // Removed paused overlay; we no longer compute paused flag here.
            // Derive planId & active index if plan session
            final session = sessionState.ongoing;
            final runtime = session != null
                ? context.read<SessionCubit>().getRuntime(session.workoutId)
                : null;
            final planId = runtime?.planId;
            final activeIndex =
                runtime?.currentExerciseIndex ?? currentExercise;
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      if (planId != null)
                        ExerciseQueue(planId: planId, activeIndex: activeIndex),
                      if (planId != null) const SizedBox(height: 8),
                      // Header with back button and exercise count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Back. Pause session and go back',
                            child: ElevatedButton(
                              onPressed: () async {
                                final cubit = context.read<SessionCubit>();
                                await cubit.pauseSession();
                                if (mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(48, 48),
                                maximumSize: const Size(56, 56),
                                elevation: 3,
                                shadowColor: Colors.black,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: Colors.white,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                          Text(
                            sessionWorkoutId == null
                                ? 'Exercise $currentExercise/$totalExercises'
                                : 'Session ${sessionWorkoutId!.substring(0, sessionWorkoutId!.length > 6 ? 6 : sessionWorkoutId!.length)} · Ex $currentExercise/$totalExercises',
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontFamily: 'Sora',
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 40), // Balance the row
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Dynamic title based on state
                      Text(
                        currentState == WorkoutState.exercising
                            ? 'Let\'s Go!'
                            : 'Are You Ready?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Sora',
                          fontSize: 28,
                          letterSpacing: -1,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Exercise GIF container
                      Container(
                        height: 300,
                        width: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            'https://static.exercisedb.dev/media/VPPtusI.gif',
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 50,
                                    ),
                                    SizedBox(height: 10),
                                    Text('Failed to load exercise GIF'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Dynamic content based on workout state
                      if (currentState == WorkoutState.exercising) ...[
                        _buildExerciseControls(),
                      ] else if (currentState == WorkoutState.resting) ...[
                        _buildRestTimer(),
                      ] else ...[
                        _buildExerciseDetails(),
                        const SizedBox(height: 30),
                        ExerciseSetProgress(
                          totalSets: totalRounds,
                          completedSets: (currentRound - 1).clamp(
                            0,
                            totalRounds,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildRepsAndWeightInputs(),
                        const SizedBox(height: 40),
                        _buildStartButton(sessionState),
                      ],
                    ],
                  ),
                ),
                // Paused overlay removed intentionally (logic retained).
                // If future visual indicator desired, reintroduce a lightweight badge instead of a full-screen scrim.
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExerciseControls() {
    String timeDisplay = formatDuration(minutes * 60 + seconds);

    return Column(
      children: [
        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            timeDisplay,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              fontFamily: 'Sora',
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Rep counter with accessibility semantics (live region style announcement on change)
        Semantics(
          label: 'Repetitions: $currentReps of $targetReps',
          // Marking as liveRegion helps screen readers announce updates (Flutter semantics flag)
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: AppColors.vibrantRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '$currentReps / $targetReps',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Sora',
                    color: AppColors.vibrantRed,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'reps',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Sora',
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Rep increment button with semantics
        Semantics(
          button: true,
          label: 'Complete rep. Currently $currentReps of $targetReps',
          onTap: incrementReps,
          child: ElevatedButton(
            focusNode: _repButtonFocus,
            onPressed: incrementReps,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.vibrantRed,
              minimumSize: const Size(220, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Complete Rep',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Sora',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 1),

        // Finish set early button
        TextButton(
          onPressed: completeSet,
          child: const Text(
            'Finish Set',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseDetails() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(
              image: AssetImage(exerciseImage),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exerciseName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Sora',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$totalRounds sets x $targetReps reps',
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                fontFamily: 'Sora',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Rest 60s',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontFamily: 'Sora',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(width: 40),
        Text(
          'Round $currentRound/$totalRounds',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Sora',
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildRepsAndWeightInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 50,
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.blueGrey.withOpacity(0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$targetReps',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Sora',
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 60),
              const Text(
                'reps',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Sora',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Container(
          height: 50,
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.blueGrey.withOpacity(0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$weight',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Sora',
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 60),
              const Text(
                'lbs',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Sora',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(SessionState sessionState) {
    final session = sessionState.ongoing;
    String label = 'Start Exercise';
    if (session != null) {
      final runtime = context.read<SessionCubit>().getRuntime(
        session.workoutId,
      );
      if (runtime != null && runtime.paused) {
        label = 'Resume Exercise';
      } else {
        // If progress exists for current exercise, label becomes Resume / Continue
        final prog = session.progress
            .where((p) => p.exerciseId == _exerciseTrackingId())
            .toList();
        if (prog.isNotEmpty &&
            (prog.first.completedReps > 0 || prog.first.completedSets > 0)) {
          label = 'Resume Exercise';
        } else {
          // If other exercises have progress, maybe we are starting a new one
          if (session.progress.isNotEmpty) label = 'Start Next Exercise';
        }
      }
    }
    final semanticLabel = _actionInFlight
        ? 'Please wait. Starting session'
        : label == 'Start Exercise'
        ? 'Start exercise $currentExercise of $totalExercises: $exerciseName'
        : label == 'Start Next Exercise'
        ? 'Start next exercise $currentExercise of $totalExercises: $exerciseName'
        : 'Resume exercise $currentExercise: $exerciseName';
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ElevatedButton(
        onPressed: _actionInFlight ? null : startExercise,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vibrantRed,
          minimumSize: const Size(320, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          _actionInFlight ? 'Please wait…' : label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Sora',
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Returns deterministic exercise tracking id. If this is a plan-derived session,
  // use plan_<planId>ex<index>; otherwise fallback to legacy exercise_<n> pattern.
  String _exerciseTrackingId() {
    final session = context.read<SessionCubit>().state.ongoing;
    if (session != null) {
      final runtime = context.read<SessionCubit>().getRuntime(
        session.workoutId,
      );
      final planId = runtime?.planId;
      if (planId != null) {
        return PlanExerciseId.build(planId, currentExercise);
      }
    }
    return 'exercise_$currentExercise';
  }

  Widget _buildRestTimer() {
    final remaining = _restRemaining.clamp(0, 9999);
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          label: 'Rest $remaining seconds remaining',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Rest: ${remaining}s',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Sora',
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _restTimer?.cancel();
            setState(() {
              currentState = WorkoutState.ready;
              _restRemaining = 0;
            });
          },
          child: const Text(
            'Skip Rest',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/session/session_cubit.dart';
import '../models/workout_plan.dart';
import 'app_routes.dart';

/// Centralized navigation helpers for starting and resuming sessions.
/// Encapsulates session creation + route pushes so analytics / guards
/// can be injected in one place later.
class AppNavigator {
  AppNavigator._();

  static Future<void> startPlan(BuildContext context, WorkoutPlan plan) async {
    // Defensive: avoid double-tap triggering multiple starts.
    final marker = StartPlanInFlightMarker.of(context);
    if (marker?.inFlight == true) return;
    marker?.setInFlight(true);
    try {
      final sessionCubit = context.read<SessionCubit>();
      // TODO: analytics: plan_start(${plan.id})
      final session = await sessionCubit.startPlanSession(plan);
      if (session == null || !context.mounted) return;
      // TODO: analytics: session_started(${session.workoutId})
      Navigator.of(context).pushNamed(AppRoutes.workout(session.workoutId));
    } finally {
      StartPlanInFlightMarker.of(context)?.setInFlight(false);
    }
  }

  static void resumeSession(BuildContext context, String workoutId) {
    // If already on the workout route for this id, skip push.
    final modal = ModalRoute.of(context);
    final settings = modal?.settings;
    if (settings is RouteSettings &&
        settings.name == AppRoutes.workout(workoutId)) {
      return;
    }
    // TODO: analytics: session_resume($workoutId)
    Navigator.of(context).pushNamed(AppRoutes.workout(workoutId));
  }

  static void sessionSummary(BuildContext context, String sessionId) {
    // TODO: analytics: session_summary_view($sessionId)
    Navigator.of(context).pushNamed(AppRoutes.sessionSummary(sessionId));
  }
}

/// An inherited widget to track whether a start plan action is already running.
class StartPlanInFlightMarker extends InheritedWidget {
  final bool inFlight;
  final void Function(bool) setInFlight;
  const StartPlanInFlightMarker({
    required this.inFlight,
    required this.setInFlight,
    required super.child,
  });

  static StartPlanInFlightMarker? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StartPlanInFlightMarker>();

  @override
  bool updateShouldNotify(covariant StartPlanInFlightMarker oldWidget) =>
      oldWidget.inFlight != inFlight;
}

/// Convenience widget to wrap a subtree where start plan actions may occur.
class StartPlanActionScope extends StatefulWidget {
  final Widget child;
  const StartPlanActionScope({super.key, required this.child});

  @override
  State<StartPlanActionScope> createState() => _StartPlanActionScopeState();
}

class _StartPlanActionScopeState extends State<StartPlanActionScope> {
  bool _inFlight = false;
  void _set(bool v) => setState(() => _inFlight = v);
  @override
  Widget build(BuildContext context) => StartPlanInFlightMarker(
    inFlight: _inFlight,
    setInFlight: _set,
    child: widget.child,
  );
}

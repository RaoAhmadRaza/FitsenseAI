import 'package:hive/hive.dart';
import '../models/workout_session.dart';

enum StatsScope { today, last7Days, all }

class MinutesBreakdown {
  final int todaySeconds;
  final int weekSeconds; // last 7 days including today
  final int allSeconds;
  final bool hasOngoing;
  const MinutesBreakdown({
    required this.todaySeconds,
    required this.weekSeconds,
    required this.allSeconds,
    required this.hasOngoing,
  });
}

class StatsService {
  static DateTime _startOfToday(DateTime now) => DateTime(now.year, now.month, now.day);
  static bool _isWithinScope(DateTime dt, StatsScope scope, DateTime now) {
    final startOfToday = _startOfToday(now);
    switch (scope) {
      case StatsScope.today:
        return dt.isAfter(startOfToday) || dt.isAtSameMomentAs(startOfToday);
      case StatsScope.last7Days:
        final start = startOfToday.subtract(const Duration(days: 6));
        return (dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
            dt.isBefore(startOfToday.add(const Duration(days: 1)));
      case StatsScope.all:
        return true;
    }
  }

  static int secondsForScope(Iterable<WorkoutSession> sessions, StatsScope scope, {bool includeOngoing = true, DateTime? now}) {
    final n = now ?? DateTime.now();
    int total = 0;
    for (final s in sessions) {
      if (_isWithinScope(s.date, scope, n)) {
        if (s.completed) {
          total += s.durationSeconds;
        } else if (includeOngoing) {
          total += s.durationSeconds;
        }
      }
    }
    return total;
  }

  static bool hasOngoing(Iterable<WorkoutSession> sessions) => sessions.any((s) => !s.completed);

  static MinutesBreakdown computeFromBox(Box<WorkoutSession> box, {bool includeOngoing = true, DateTime? now}) {
    final sessions = box.values.toList(growable: false);
    final t = secondsForScope(sessions, StatsScope.today, includeOngoing: includeOngoing, now: now);
    final w = secondsForScope(sessions, StatsScope.last7Days, includeOngoing: includeOngoing, now: now);
    final a = secondsForScope(sessions, StatsScope.all, includeOngoing: includeOngoing, now: now);
    return MinutesBreakdown(
      todaySeconds: t,
      weekSeconds: w,
      allSeconds: a,
      hasOngoing: hasOngoing(sessions),
    );
  }

  static MinutesBreakdown computeScoped(
    Iterable<WorkoutSession> sessions, {
    bool includeOngoing = true,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    return MinutesBreakdown(
      todaySeconds: secondsForScope(sessions, StatsScope.today, includeOngoing: includeOngoing, now: n),
      weekSeconds: secondsForScope(sessions, StatsScope.last7Days, includeOngoing: includeOngoing, now: n),
      allSeconds: secondsForScope(sessions, StatsScope.all, includeOngoing: includeOngoing, now: n),
      hasOngoing: hasOngoing(sessions),
    );
  }
}

/// Formatting helpers for durations and friendly dates.
/// Simple, locale-light implementations (future i18n can replace these).
import 'package:intl/intl.dart';

String formatDuration(int seconds) {
  final clamped = seconds < 0 ? 0 : seconds;
  final hrs = clamped ~/ 3600;
  final mins = (clamped % 3600) ~/ 60;
  final secs = clamped % 60;
  if (hrs > 0) {
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

String formatFriendlyDate(DateTime dt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final other = DateTime(dt.year, dt.month, dt.day);
  final diffDays = other.difference(today).inDays;
  if (diffDays == 0) return 'Today';
  if (diffDays == -1) return 'Yesterday';
  // Simple month & day format (e.g., Sep 17)
  return DateFormat('MMM d').format(dt);
}

import '../application_tracking/application_models.dart';
import '../session/session_models.dart';

class DailyUsagePoint {
  const DailyUsagePoint(this.date, this.duration);
  final DateTime date;
  final Duration duration;
}

class UsageSummary {
  const UsageSummary({
    required this.today,
    required this.sevenDayAverage,
    required this.thisWeek,
    required this.sessionsToday,
    required this.lastSevenDays,
  });
  final Duration today;
  final Duration sevenDayAverage;
  final Duration thisWeek;
  final int sessionsToday;
  final List<DailyUsagePoint> lastSevenDays;
}

abstract final class UsageAnalytics {
  static UsageSummary summarize(
    Iterable<ComputerSession> sessions, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = _date(current);
    final totals = <DateTime, Duration>{};
    for (final session in sessions) {
      final day = _date(session.startedAt);
      totals[day] = (totals[day] ?? Duration.zero) + session.activeDuration;
    }
    final points = [
      for (var offset = 6; offset >= 0; offset--)
        DailyUsagePoint(
          today.subtract(Duration(days: offset)),
          totals[today.subtract(Duration(days: offset))] ?? Duration.zero,
        ),
    ];
    final sevenDayTotal = points.fold(
      Duration.zero,
      (total, point) => total + point.duration,
    );
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekTotal = totals.entries
        .where(
          (entry) =>
              !entry.key.isBefore(weekStart) && !entry.key.isAfter(today),
        )
        .fold(Duration.zero, (total, entry) => total + entry.value);
    return UsageSummary(
      today: totals[today] ?? Duration.zero,
      sevenDayAverage: Duration(
        microseconds: sevenDayTotal.inMicroseconds ~/ 7,
      ),
      thisWeek: weekTotal,
      sessionsToday: sessions
          .where((session) => _date(session.startedAt) == today)
          .length,
      lastSevenDays: points,
    );
  }

  static List<ApplicationUsage> applicationTotals(
    Iterable<ComputerSession> sessions, {
    required DateTime from,
  }) {
    final totals = <String, ApplicationUsage>{};
    for (final session in sessions.where(
      (value) => !value.startedAt.isBefore(from),
    )) {
      for (final usage in session.applicationUsage) {
        final previous = totals[usage.applicationId];
        totals[usage.applicationId] = usage.copyWith(
          activeDuration:
              (previous?.activeDuration ?? Duration.zero) +
              usage.activeDuration,
        );
      }
    }
    final result = totals.values.toList()
      ..sort((a, b) => b.activeDuration.compareTo(a.activeDuration));
    return result;
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

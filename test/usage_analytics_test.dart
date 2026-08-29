import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/analytics/usage_analytics.dart';
import 'package:lapse/features/application_tracking/application_models.dart';
import 'package:lapse/features/session/session_models.dart';

ComputerSession session(
  DateTime start,
  Duration duration, {
  List<ApplicationUsage> apps = const [],
}) => ComputerSession(
  id: start.toIso8601String(),
  startedAt: start,
  activeDuration: duration,
  tasks: const [],
  applicationUsage: apps,
);

void main() {
  test('calculates daily totals, zero days, 7-day average and week total', () {
    final now = DateTime(2026, 8, 28, 12); // Friday
    final summary = UsageAnalytics.summarize([
      session(DateTime(2026, 8, 28, 9), const Duration(hours: 2)),
      session(DateTime(2026, 8, 28, 14), const Duration(hours: 1)),
      session(DateTime(2026, 8, 26, 9), const Duration(hours: 4)),
      session(DateTime(2026, 8, 20), const Duration(hours: 9)),
    ], now: now);

    expect(summary.today, const Duration(hours: 3));
    expect(summary.sessionsToday, 2);
    expect(summary.thisWeek, const Duration(hours: 7));
    expect(summary.sevenDayAverage, const Duration(hours: 1));
    expect(
      summary.lastSevenDays.where((point) => point.duration == Duration.zero),
      hasLength(5),
    );
  });

  test('aggregates application usage across sessions', () {
    const editor = ApplicationUsage(
      applicationId: 'editor',
      displayName: 'Editor',
      executableName: 'editor.exe',
      activeDuration: Duration(minutes: 20),
    );
    final totals = UsageAnalytics.applicationTotals([
      session(DateTime(2026, 8, 28), Duration.zero, apps: const [editor]),
      session(
        DateTime(2026, 8, 29),
        Duration.zero,
        apps: [editor.copyWith(activeDuration: const Duration(minutes: 10))],
      ),
    ], from: DateTime(2026, 8, 23));
    expect(totals.single.activeDuration, const Duration(minutes: 30));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/session/active_time_accumulator.dart';
import 'package:lapse/features/session/session_models.dart';

import 'test_fakes.dart';

void main() {
  test(
    'accumulates only active intervals through idle and lock transitions',
    () {
      final clock = FakeClock();
      final accumulator = ActiveTimeAccumulator(
        persistedDuration: Duration.zero,
        clock: clock,
      );

      accumulator.transitionTo(UserActivityState.active);
      clock.advance(const Duration(minutes: 12));
      accumulator.transitionTo(UserActivityState.idle);
      clock.advance(const Duration(minutes: 4));
      accumulator.transitionTo(UserActivityState.active);
      clock.advance(const Duration(minutes: 3));
      accumulator.transitionTo(UserActivityState.locked);
      clock.advance(const Duration(hours: 1));
      accumulator.transitionTo(UserActivityState.active);
      clock.advance(const Duration(seconds: 20));

      expect(accumulator.current, const Duration(minutes: 15, seconds: 20));
    },
  );

  test('reconstructs display from persisted duration and a new interval', () {
    final clock = FakeClock();
    final accumulator = ActiveTimeAccumulator(
      persistedDuration: const Duration(hours: 2, minutes: 4),
      clock: clock,
    );

    accumulator.transitionTo(UserActivityState.active);
    clock.advance(const Duration(minutes: 6, seconds: 30));

    expect(
      accumulator.current,
      const Duration(hours: 2, minutes: 10, seconds: 30),
    );
  });
}

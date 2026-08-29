import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/application_tracking/application_models.dart';
import 'package:lapse/features/application_tracking/application_usage_accumulator.dart';

import 'test_fakes.dart';

ForegroundApplication app(String name) => ForegroundApplication(
  processId: name.hashCode,
  executablePath: 'C:\\Apps\\$name.exe',
  executableName: '$name.exe',
  displayName: name,
  observedAt: DateTime(2026, 8, 29),
);

void main() {
  test('counts foreground apps only across active intervals', () {
    final clock = FakeClock();
    final tracker = ApplicationUsageAccumulator(clock: clock);
    tracker.observe(app('VS Code'));
    tracker.setActive(true);
    clock.advance(const Duration(minutes: 20));
    tracker.observe(app('Browser'));
    clock.advance(const Duration(minutes: 15));
    tracker.setActive(false);
    clock.advance(const Duration(minutes: 15));
    tracker.setActive(true);
    clock.advance(const Duration(minutes: 10));
    tracker.setActive(false);

    final usage = {
      for (final item in tracker.snapshot())
        item.displayName: item.activeDuration,
    };
    expect(usage['VS Code'], const Duration(minutes: 20));
    expect(usage['Browser'], const Duration(minutes: 25));
  });

  test('pause, null foreground and terminated process add no time', () {
    final clock = FakeClock();
    final tracker = ApplicationUsageAccumulator(clock: clock);
    tracker.observe(app('Editor'));
    tracker.setActive(true);
    clock.advance(const Duration(minutes: 5));
    tracker.setActive(false);
    clock.advance(const Duration(minutes: 20));
    tracker.setActive(true);
    tracker.observe(null);
    clock.advance(const Duration(minutes: 10));
    tracker.observe(app('Browser'));
    clock.advance(const Duration(minutes: 3));
    tracker.observe(null);
    clock.advance(const Duration(minutes: 4));

    final usage = {
      for (final item in tracker.snapshot())
        item.displayName: item.activeDuration,
    };
    expect(usage['Editor'], const Duration(minutes: 5));
    expect(usage['Browser'], const Duration(minutes: 3));
  });

  test('replaces generic engine metadata with the actual application', () {
    final tracker = ApplicationUsageAccumulator(
      clock: FakeClock(),
      persisted: const [
        ApplicationUsage(
          applicationId: r'c:\fortniteclient-win64-shipping.exe',
          displayName: 'Unreal Engine',
          executableName: 'FortniteClient-Win64-Shipping.exe',
          activeDuration: Duration(minutes: 14),
        ),
      ],
    );

    expect(tracker.snapshot().single.displayName, 'Fortnite');
    expect(
      applicationDisplayName(
        executableName: 'HogwartsLegacy-Win64-Shipping.exe',
        reportedDisplayName: 'Unreal Engine',
        windowTitle: 'Hogwarts Legacy',
      ),
      'Hogwarts Legacy',
    );
    expect(
      applicationDisplayName(
        executableName: 'MyUnityGame.exe',
        reportedDisplayName: 'Unity Player',
        windowTitle: 'My Unity Game',
      ),
      'My Unity Game',
    );
  });

  test(
    'keeps reliable product names and improves generic Windows metadata',
    () {
      expect(
        applicationDisplayName(
          executableName: 'Code.exe',
          reportedDisplayName: 'Visual Studio Code',
          windowTitle: 'main.dart - lapse - Visual Studio Code',
        ),
        'Visual Studio Code',
      );
      expect(
        applicationDisplayName(
          executableName: 'SnippingTool.exe',
          reportedDisplayName: 'Microsoft® Windows® Operating System',
          windowTitle: 'Snipping Tool',
        ),
        'Snipping Tool',
      );
    },
  );
}

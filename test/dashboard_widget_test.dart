// Dashboard widget tests do not load the Windows embedder's Windowing symbols.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/app/lapse_theme.dart';
import 'package:lapse/features/application_tracking/application_models.dart';
import 'package:lapse/features/dashboard/dashboard_window.dart';
import 'package:lapse/features/session/session_controller.dart';
import 'package:lapse/features/session/session_models.dart';

import 'test_fakes.dart';

void main() {
  isWindowingEnabled = false;

  testWidgets('dashboard renders analytics and navigates all desktop pages', (
    tester,
  ) async {
    final persistence = MemoryPersistence(
      PersistedAppState(
        bootId: 'boot-a',
        session: ComputerSession(
          id: 'current',
          startedAt: DateTime.now(),
          activeDuration: const Duration(hours: 2),
          tasks: const [
            SessionTask(id: 'one', title: 'Task', isCompleted: true),
          ],
          applicationUsage: const [
            ApplicationUsage(
              applicationId: 'editor',
              displayName: 'Editor',
              executableName: 'editor.exe',
              activeDuration: Duration(minutes: 45),
            ),
          ],
        ),
        preferences: const LapsePreferences(),
      ),
    );
    final controller = SessionController(
      activityDetector: FakeActivityDetector(),
      persistence: persistence,
      platform: FakePlatform(),
      clock: FakeClock(),
    );
    await controller.initialize();
    final page = ValueNotifier(DashboardPage.dashboard);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLapseTheme(),
        home: SizedBox(
          width: 1000,
          height: 680,
          child: DashboardWindow(controller: controller, page: page),
        ),
      ),
    );
    expect(find.text('Active time'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    final chart = find.byKey(const Key('usageChart'));
    final chartRect = tester.getRect(chart);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: chartRect.center);
    await mouse.moveTo(chartRect.center);
    await tester.pump();
    expect(find.byKey(const Key('chartTooltip')), findsOneWidget);
    expect(find.text('active · 7-day share'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const Key('chartTooltip')), findsNothing);

    await tester.tap(find.text('Applications').first);
    await tester.pump();
    expect(find.text('Editor'), findsOneWidget);

    await tester.tap(find.text('Sessions').first);
    await tester.pump();
    expect(find.textContaining('Active'), findsWidgets);

    await tester.tap(find.text('Settings').first);
    await tester.pump();
    expect(find.text('Start with Windows'), findsOneWidget);
    expect(find.text('Always on top'), findsOneWidget);

    controller.dispose();
    page.dispose();
  });
}

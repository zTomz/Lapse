// The test disables an internal experimental flag because the test process does
// not load the Windows embedder's Windowing FFI symbols.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/app/lapse_theme.dart';
import 'package:lapse/features/overlay/overlay_window.dart';
import 'package:lapse/features/session/session_controller.dart';

import 'test_fakes.dart';

void main() {
  isWindowingEnabled = false;

  Future<SessionController> createController() async {
    final controller = SessionController(
      activityDetector: FakeActivityDetector(),
      persistence: MemoryPersistence(),
      platform: FakePlatform(),
      clock: FakeClock(),
    );
    await controller.initialize();
    return controller;
  }

  Future<void> pumpOverlay(WidgetTester tester, SessionController controller) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildLapseTheme(),
          home: SizedBox(
            width: 312,
            height: 356,
            child: OverlayWindow(
              controller: controller,
              onOpenDashboard: () {},
            ),
          ),
        ),
      );

  testWidgets('adds a task and changes to the collapsed overlay', (
    tester,
  ) async {
    final detector = FakeActivityDetector();
    final controller = SessionController(
      activityDetector: detector,
      persistence: MemoryPersistence(),
      platform: FakePlatform(),
      clock: FakeClock(),
    );
    await controller.initialize();
    var dashboardRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLapseTheme(),
        home: SizedBox(
          width: 312,
          height: 356,
          child: OverlayWindow(
            controller: controller,
            onOpenDashboard: () => dashboardRequested = true,
          ),
        ),
      ),
    );

    expect(find.text('No tasks for this session'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('taskEditor')),
      'Reply to email',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Reply to email'), findsOneWidget);
    expect(controller.state.session.tasks, hasLength(1));

    await tester.tap(find.byKey(const Key('pauseButton')));
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);
    expect(controller.state.session.isPaused, isTrue);

    await tester.tap(find.byKey(const Key('launchButton')));
    expect(dashboardRequested, isTrue);

    await tester.tap(find.byKey(const Key('collapseButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expandButton')), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    controller.dispose();
  });

  testWidgets('empty add input closes when focus is lost', (tester) async {
    final controller = await createController();
    await pumpOverlay(tester, controller);
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await tester.pump();
    expect(find.byKey(const Key('taskEditor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sessionTimer')));
    await tester.pump();
    expect(find.byKey(const Key('taskEditor')), findsNothing);
    expect(controller.state.session.tasks, isEmpty);
    controller.dispose();
  });

  testWidgets('Enter and confirmation add trimmed valid tasks', (tester) async {
    final controller = await createController();
    await pumpOverlay(tester, controller);
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskEditor')), '  First  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(controller.state.session.tasks.single.title, 'First');

    await tester.tap(find.byKey(const Key('addTaskButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskEditor')), 'Second');
    await tester.pump();
    await tester.tap(find.byKey(const Key('addTaskConfirm')));
    await tester.pump();
    expect(controller.state.session.tasks.last.title, 'Second');
    controller.dispose();
  });

  testWidgets('whitespace is disabled and Escape cancels add', (tester) async {
    final controller = await createController();
    await pumpOverlay(tester, controller);
    await tester.tap(find.byKey(const Key('addTaskButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskEditor')), '   ');
    await tester.pump();
    final confirm = tester.widget<IconButton>(
      find.byKey(const Key('addTaskConfirm')),
    );
    expect(confirm.onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('taskEditor')), findsNothing);
    expect(controller.state.session.tasks, isEmpty);
    controller.dispose();
  });

  testWidgets('edit supports Enter, checkmark and Escape restore', (
    tester,
  ) async {
    final controller = (await createController())..addTask('Original');
    await pumpOverlay(tester, controller);

    await tester.tap(find.byTooltip('Edit task'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskEditor')), 'Via Enter');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(controller.state.session.tasks.single.title, 'Via Enter');

    await tester.tap(find.byTooltip('Edit task'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskEditor')), 'Via Check');
    await tester.tap(find.byKey(const Key('editTaskConfirm')));
    await tester.pump();
    expect(controller.state.session.tasks.single.title, 'Via Check');

    await tester.tap(find.byTooltip('Edit task'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('taskEditor')), 'Discard me');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.state.session.tasks.single.title, 'Via Check');
    controller.dispose();
  });
}

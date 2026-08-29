// The test disables an internal experimental flag because the test process does
// not load the Windows embedder's Windowing FFI symbols.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/_features.dart' show isWindowingEnabled;
import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/app/lapse_theme.dart';
import 'package:lapse/features/overlay/overlay_window.dart';
import 'package:lapse/features/session/session_controller.dart';

import 'test_fakes.dart';

void main() {
  isWindowingEnabled = false;
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

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLapseTheme(),
        home: SizedBox(
          width: 312,
          height: 356,
          child: OverlayWindow(controller: controller),
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

    await tester.tap(find.byKey(const Key('collapseButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expandButton')), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    controller.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/session/session_controller.dart';
import 'package:lapse/features/session/session_models.dart';

import 'test_fakes.dart';

void main() {
  PersistedAppState persistedState({String bootId = 'boot-a'}) =>
      PersistedAppState(
        bootId: bootId,
        session: ComputerSession(
          id: 'session-1',
          startedAt: DateTime(2026, 8, 29, 9),
          activeDuration: const Duration(minutes: 42),
          tasks: const [SessionTask(id: 'task-1', title: 'Keep me')],
        ),
        preferences: const LapsePreferences(overlayMode: OverlayMode.collapsed),
      );

  test('restores the current session and tasks on the same boot', () async {
    final persistence = MemoryPersistence(persistedState());
    final detector = FakeActivityDetector();
    final controller = SessionController(
      activityDetector: detector,
      persistence: persistence,
      platform: FakePlatform(),
      clock: FakeClock(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.state.session.id, 'session-1');
    expect(controller.state.session.tasks.single.title, 'Keep me');
    expect(controller.state.displayDuration, const Duration(minutes: 42));
    expect(controller.state.preferences.overlayMode, OverlayMode.collapsed);
  });

  test(
    'starts a fresh task list on a new boot but keeps preferences',
    () async {
      final detector = FakeActivityDetector();
      final controller = SessionController(
        activityDetector: detector,
        persistence: MemoryPersistence(persistedState(bootId: 'old-boot')),
        platform: FakePlatform(currentBootId: 'new-boot'),
        clock: FakeClock(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.state.session.id, isNot('session-1'));
      expect(controller.state.session.tasks, isEmpty);
      expect(controller.state.displayDuration, Duration.zero);
      expect(controller.state.preferences.overlayMode, OverlayMode.collapsed);
    },
  );

  test('adds, toggles, edits and deletes tasks', () async {
    final detector = FakeActivityDetector();
    final controller = SessionController(
      activityDetector: detector,
      persistence: MemoryPersistence(),
      platform: FakePlatform(),
      clock: FakeClock(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    controller.addTask('Write tests');
    final task = controller.state.session.tasks.single;
    expect(task.title, 'Write tests');

    controller.toggleTask(task.id);
    expect(controller.state.session.tasks.single.isCompleted, isTrue);

    controller.editTask(task.id, 'Ship tests');
    expect(controller.state.session.tasks.single.title, 'Ship tests');

    controller.deleteTask(task.id);
    expect(controller.state.session.tasks, isEmpty);
  });
}

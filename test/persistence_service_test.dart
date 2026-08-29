import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/session/session_models.dart';
import 'package:lapse/services/persistence_service.dart';

void main() {
  late Directory directory;
  late JsonPersistenceService persistence;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lapse_test_');
    persistence = JsonPersistenceService(directory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('serializes and restores typed state', () async {
    final expected = PersistedAppState(
      bootId: 'boot-a',
      session: ComputerSession(
        id: 'session-a',
        startedAt: DateTime(2026, 8, 29, 10),
        activeDuration: const Duration(seconds: 95),
        tasks: const [
          SessionTask(id: 'task-a', title: 'Persist me', isCompleted: true),
        ],
      ),
      preferences: const LapsePreferences(windowX: 123, windowY: 45),
      sessionHistory: [
        ComputerSession(
          id: 'old',
          startedAt: DateTime(2026, 8, 28),
          endedAt: DateTime(2026, 8, 28, 12),
          activeDuration: const Duration(hours: 2),
          tasks: const [],
        ),
      ],
    );

    await persistence.save(expected);
    final restored = await persistence.load();

    expect(restored?.bootId, 'boot-a');
    expect(restored?.session.activeDuration, const Duration(seconds: 95));
    expect(restored?.session.tasks.single.isCompleted, isTrue);
    expect(restored?.preferences.windowX, 123);
    expect(restored?.sessionHistory.single.id, 'old');
  });

  test('migrates schema 1 state with empty analytics defaults', () {
    final restored = PersistedAppState.decode('''
{"schemaVersion":1,"bootId":"boot-old","session":{"id":"s","startedAt":"2026-08-29T08:00:00.000Z","activeMilliseconds":10,"tasks":[]},"preferences":{}}
''');
    expect(restored.sessionHistory, isEmpty);
    expect(restored.session.applicationUsage, isEmpty);
    expect(restored.preferences.dashboardWidth, 1000);
  });

  test('returns null for missing and corrupted data', () async {
    expect(await persistence.load(), isNull);
    await directory.create(recursive: true);
    await File('${directory.path}${Platform.pathSeparator}state.json')
        .writeAsString('{broken');
    expect(await persistence.load(), isNull);
  });
}

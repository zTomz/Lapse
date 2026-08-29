import 'dart:async';

import 'package:lapse/features/session/active_time_accumulator.dart';
import 'package:lapse/features/application_tracking/application_models.dart';
import 'package:lapse/features/session/session_models.dart';
import 'package:lapse/services/activity_detector.dart';
import 'package:lapse/services/persistence_service.dart';
import 'package:lapse/services/platform_service.dart';

class FakeClock implements MonotonicClock {
  Duration value = Duration.zero;

  void advance(Duration duration) => value += duration;

  @override
  Duration get elapsed => value;
}

class FakeActivityDetector implements ActivityDetector {
  FakeActivityDetector([this.value = UserActivityState.active]);

  UserActivityState value;
  final controller = StreamController<UserActivityState>.broadcast();

  void emit(UserActivityState next) {
    value = next;
    controller.add(next);
  }

  @override
  Future<UserActivityState> currentState() async => value;

  @override
  Stream<UserActivityState> get states => controller.stream;

  @override
  void dispose() => controller.close();
}

class MemoryPersistence implements PersistenceService {
  MemoryPersistence([this.value]);
  PersistedAppState? value;

  @override
  Future<PersistedAppState?> load() async => value;

  @override
  Future<void> save(PersistedAppState state) async => value = state;
}

class FakePlatform implements PlatformService {
  FakePlatform({this.currentBootId = 'boot-a'});

  String currentBootId;
  bool hidden = false;
  bool quitCalled = false;
  bool autostart = true;
  bool topmost = true;
  double? resizedWidth;
  double? resizedHeight;
  final eventController = StreamController<PlatformEvent>.broadcast();

  @override
  Future<ActivitySnapshot> activitySnapshot() async => const ActivitySnapshot(
    idleDuration: Duration.zero,
    isLocked: false,
    isSleeping: false,
  );

  @override
  Future<String> bootId() async => currentBootId;

  @override
  Future<ForegroundApplication?> foregroundApplication() async => null;

  @override
  Stream<PlatformEvent> get events => eventController.stream;

  @override
  Future<WindowPosition?> beginDrag() async => const WindowPosition(10, 20);

  @override
  Future<void> configureOverlay({
    required bool alwaysOnTop,
    double? x,
    double? y,
  }) async {
    topmost = alwaysOnTop;
  }

  @override
  Future<void> configureDashboard({double? x, double? y}) async {}

  @override
  Future<WindowBounds?> dashboardBounds() async =>
      const WindowBounds(20, 30, 1000, 680);

  @override
  Future<void> hide() async => hidden = true;

  @override
  Future<bool> isAutostartEnabled() async => autostart;

  @override
  Future<void> quit() async => quitCalled = true;

  @override
  Future<void> resize(double width, double height) async {
    resizedWidth = width;
    resizedHeight = height;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async => topmost = value;

  @override
  Future<void> setAutostartEnabled(bool value) async => autostart = value;

  @override
  Future<void> show() async => hidden = false;

  @override
  Future<void> updateTray({
    required bool collapsed,
    required bool autostart,
    required bool alwaysOnTop,
  }) async {}
}

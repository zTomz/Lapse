import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_constants.dart';
import '../../services/activity_detector.dart';
import '../../services/persistence_service.dart';
import '../../services/platform_service.dart';
import '../../services/windows_activity_detector.dart';
import 'active_time_accumulator.dart';
import 'session_models.dart';

part 'session_controller.g.dart';

@Riverpod(keepAlive: true)
SessionController sessionController(Ref ref) {
  final platform = WindowsPlatformService();
  final detector = WindowsActivityDetector(platform);
  final controller = SessionController(
    activityDetector: detector,
    persistence: JsonPersistenceService(),
    platform: platform,
  );
  ref.onDispose(controller.dispose);
  unawaited(controller.initialize());
  return controller;
}

class SessionController extends ChangeNotifier {
  SessionController({
    required this._activityDetector,
    required this._persistence,
    required this._platform,
    MonotonicClock? clock,
    DateTime Function()? now,
  }) : _clock = clock ?? StopwatchClock(),
       _now = now ?? DateTime.now,
       _state = SessionViewState(
         session: ComputerSession(
           id: _newId(),
           startedAt: (now ?? DateTime.now)(),
           activeDuration: Duration.zero,
           tasks: const [],
         ),
         preferences: const LapsePreferences(),
         activityState: UserActivityState.idle,
         displayDuration: Duration.zero,
       );

  final ActivityDetector _activityDetector;
  final PersistenceService _persistence;
  final PlatformService _platform;
  final MonotonicClock _clock;
  final DateTime Function() _now;
  SessionViewState _state;
  ActiveTimeAccumulator? _accumulator;
  StreamSubscription<UserActivityState>? _activitySubscription;
  StreamSubscription<PlatformEvent>? _platformSubscription;
  Timer? _displayTimer;
  Timer? _checkpointTimer;
  String _bootId = 'unknown-boot';
  void Function(Size size)? _windowResizer;

  SessionViewState get state => _state;

  void attachWindowResizer(void Function(Size size) resize) {
    _windowResizer = resize;
  }

  Future<void> initialize() async {
    try {
      _bootId = await _platform.bootId();
      final persisted = await _persistence.load();
      final sameBoot = persisted?.bootId == _bootId;
      final session = sameBoot
          ? persisted!.session
          : ComputerSession(
              id: _newId(),
              startedAt: _now(),
              activeDuration: Duration.zero,
              tasks: const [],
            );
      final preferences = persisted?.preferences ?? const LapsePreferences();
      _accumulator = ActiveTimeAccumulator(
        persistedDuration: session.activeDuration,
        clock: _clock,
      );
      final activity = await _safeCurrentActivity();
      _accumulator!.transitionTo(activity);
      _state = SessionViewState(
        session: session,
        preferences: preferences,
        activityState: activity,
        displayDuration: _accumulator!.current,
        isReady: true,
      );
      notifyListeners();
      developer.log(
        sameBoot
            ? 'Restored current computer session'
            : 'Started a new computer session',
        name: 'Lapse',
      );
      _activitySubscription = _activityDetector.states.listen(_onActivityState);
      _platformSubscription = _platform.events.listen(_onPlatformEvent);
      _displayTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refreshDisplay(),
      );
      _checkpointTimer = Timer.periodic(
        AppConstants.persistenceCheckpoint,
        (_) => unawaited(persist()),
      );
      await _platform.configureOverlay(
        alwaysOnTop: preferences.alwaysOnTop,
        x: preferences.windowX,
        y: preferences.windowY,
      );
      await _applyWindowMode();
      await _setAutostart(preferences.autostart, updateState: false);
      await _updateTray();
      await persist();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Initialization failed',
        name: 'Lapse',
        error: error,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isReady: true,
        errorMessage: 'Some Windows features are unavailable.',
      );
      notifyListeners();
    }
  }

  Future<UserActivityState> _safeCurrentActivity() async {
    try {
      return await _activityDetector.currentState();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Activity detection failed; pausing timer',
        name: 'Lapse',
        error: error,
        stackTrace: stackTrace,
      );
      return UserActivityState.idle;
    }
  }

  void _onActivityState(UserActivityState next) {
    if (next == _state.activityState) return;
    developer.log(
      '${_state.activityState.name} -> ${next.name}',
      name: 'Lapse',
    );
    _accumulator?.transitionTo(next);
    _state = _state.copyWith(
      activityState: next,
      displayDuration: _accumulator?.current,
    );
    notifyListeners();
    unawaited(persist());
  }

  void _refreshDisplay() {
    final accumulator = _accumulator;
    if (accumulator == null) return;
    _state = _state.copyWith(displayDuration: accumulator.current);
    notifyListeners();
  }

  Future<void> _onPlatformEvent(PlatformEvent event) async {
    switch (event) {
      case PlatformEvent.trayOpen:
        await _platform.show();
      case PlatformEvent.trayToggle:
        await toggleOverlayMode();
        await _platform.show();
      case PlatformEvent.trayAutostart:
        await setAutostart(!_state.preferences.autostart);
      case PlatformEvent.trayTopmost:
        await setAlwaysOnTop(!_state.preferences.alwaysOnTop);
      case PlatformEvent.trayQuit:
        await quit();
      case PlatformEvent.locked:
      case PlatformEvent.unlocked:
      case PlatformEvent.suspend:
      case PlatformEvent.resume:
        break;
    }
  }

  void addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _updateTasks([
      ..._state.session.tasks,
      SessionTask(id: _newId(), title: trimmed),
    ]);
  }

  void toggleTask(String id) => _updateTasks([
    for (final task in _state.session.tasks)
      if (task.id == id)
        task.copyWith(isCompleted: !task.isCompleted)
      else
        task,
  ]);

  void editTask(String id, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _updateTasks([
      for (final task in _state.session.tasks)
        if (task.id == id) task.copyWith(title: trimmed) else task,
    ]);
  }

  void deleteTask(String id) => _updateTasks(
    _state.session.tasks.where((task) => task.id != id).toList(),
  );

  void _updateTasks(List<SessionTask> tasks) {
    _state = _state.copyWith(
      session: _state.session.copyWith(tasks: List.unmodifiable(tasks)),
    );
    notifyListeners();
    unawaited(persist());
  }

  Future<void> toggleOverlayMode() async {
    final mode = _state.preferences.overlayMode == OverlayMode.expanded
        ? OverlayMode.collapsed
        : OverlayMode.expanded;
    _state = _state.copyWith(
      preferences: _state.preferences.copyWith(overlayMode: mode),
    );
    notifyListeners();
    await _applyWindowMode();
    await _updateTray();
    await persist();
  }

  Future<void> _applyWindowMode() async {
    final size = _state.preferences.overlayMode == OverlayMode.expanded
        ? AppConstants.expandedSize
        : AppConstants.collapsedSize;
    final resize = _windowResizer;
    if (resize != null) {
      resize(size);
    } else {
      await _platform.resize(size.width, size.height);
    }
  }

  Future<void> beginDrag() async {
    final position = await _platform.beginDrag();
    if (position == null) return;
    _state = _state.copyWith(
      preferences: _state.preferences.copyWith(
        windowX: position.x,
        windowY: position.y,
      ),
    );
    await persist();
  }

  Future<void> hide() async {
    await persist();
    await _platform.hide();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    _state = _state.copyWith(
      preferences: _state.preferences.copyWith(alwaysOnTop: value),
    );
    notifyListeners();
    try {
      await _platform.setAlwaysOnTop(value);
      await _updateTray();
      await persist();
    } on Object catch (error) {
      developer.log(
        'Unable to change always-on-top',
        name: 'Lapse',
        error: error,
      );
    }
  }

  Future<void> setAutostart(bool value) =>
      _setAutostart(value, updateState: true);

  Future<void> _setAutostart(bool value, {required bool updateState}) async {
    try {
      await _platform.setAutostartEnabled(value);
      if (updateState) {
        _state = _state.copyWith(
          preferences: _state.preferences.copyWith(autostart: value),
        );
        notifyListeners();
        await _updateTray();
        await persist();
      }
    } on Object catch (error) {
      developer.log('Unable to update autostart', name: 'Lapse', error: error);
    }
  }

  Future<void> _updateTray() => _platform.updateTray(
    collapsed: _state.preferences.overlayMode == OverlayMode.collapsed,
    autostart: _state.preferences.autostart,
    alwaysOnTop: _state.preferences.alwaysOnTop,
  );

  Future<void> persist() async {
    final accumulator = _accumulator;
    if (accumulator == null) return;
    final duration = accumulator.checkpoint();
    final session = _state.session.copyWith(activeDuration: duration);
    _state = _state.copyWith(session: session, displayDuration: duration);
    await _persistence.save(
      PersistedAppState(
        bootId: _bootId,
        session: session,
        preferences: _state.preferences,
      ),
    );
  }

  Future<void> quit() async {
    await persist();
    await _platform.quit();
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _checkpointTimer?.cancel();
    unawaited(_activitySubscription?.cancel());
    unawaited(_platformSubscription?.cancel());
    _activityDetector.dispose();
    super.dispose();
  }
}

int _idSequence = 0;

String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

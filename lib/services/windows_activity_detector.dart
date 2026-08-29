import 'dart:async';

import '../app/app_constants.dart';
import '../features/session/session_models.dart';
import 'activity_detector.dart';
import 'platform_service.dart';

class WindowsActivityDetector implements ActivityDetector {
  WindowsActivityDetector(
    this._platform, {
    this._idleTimeout = AppConstants.idleTimeout,
    Duration pollInterval = AppConstants.activityPollInterval,
  }) {
    _platformSubscription = _platform.events.listen((event) {
      if (event.index <= PlatformEvent.resume.index) unawaited(_poll());
    });
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  final PlatformService _platform;
  final Duration _idleTimeout;
  final _states = StreamController<UserActivityState>.broadcast();
  Timer? _timer;
  StreamSubscription<PlatformEvent>? _platformSubscription;
  UserActivityState? _lastState;
  bool _polling = false;

  @override
  Stream<UserActivityState> get states => _states.stream;

  @override
  Future<UserActivityState> currentState() async {
    final snapshot = await _platform.activitySnapshot();
    if (snapshot.isSleeping) return UserActivityState.sleeping;
    if (snapshot.isLocked) return UserActivityState.locked;
    if (snapshot.idleDuration >= _idleTimeout) return UserActivityState.idle;
    return UserActivityState.active;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final next = await currentState();
      if (next != _lastState) {
        _lastState = next;
        _states.add(next);
      }
    } on Object {
      if (_lastState != UserActivityState.idle) {
        _lastState = UserActivityState.idle;
        _states.add(UserActivityState.idle);
      }
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_platformSubscription?.cancel());
    unawaited(_states.close());
  }
}

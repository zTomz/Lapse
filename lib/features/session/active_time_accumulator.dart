import 'session_models.dart';

abstract interface class MonotonicClock {
  Duration get elapsed;
}

class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();
  final Stopwatch _stopwatch;
  @override
  Duration get elapsed => _stopwatch.elapsed;
}

class ActiveTimeAccumulator {
  ActiveTimeAccumulator({
    required Duration persistedDuration,
    required this._clock,
  }) : _accumulated = persistedDuration;

  final MonotonicClock _clock;
  Duration _accumulated;
  Duration? _activeSince;

  Duration get current {
    final activeSince = _activeSince;
    return activeSince == null
        ? _accumulated
        : _accumulated + (_clock.elapsed - activeSince);
  }

  void transitionTo(UserActivityState state) {
    final now = _clock.elapsed;
    if (state == UserActivityState.active) {
      _activeSince ??= now;
      return;
    }
    final activeSince = _activeSince;
    if (activeSince != null) {
      _accumulated += now - activeSince;
      _activeSince = null;
    }
  }

  Duration checkpoint() {
    final now = _clock.elapsed;
    final activeSince = _activeSince;
    if (activeSince != null) {
      _accumulated += now - activeSince;
      _activeSince = now;
    }
    return _accumulated;
  }
}

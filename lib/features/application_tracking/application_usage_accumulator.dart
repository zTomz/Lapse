import '../session/active_time_accumulator.dart';
import 'application_models.dart';

class ApplicationUsageAccumulator {
  ApplicationUsageAccumulator({
    required this._clock,
    Iterable<ApplicationUsage> persisted = const [],
  }) : _usage = {
         for (final usage in persisted)
           usage.applicationId: usage.copyWith(
             displayName: applicationDisplayName(
               executableName: usage.executableName,
               reportedDisplayName: usage.displayName,
             ),
           ),
       };

  final MonotonicClock _clock;
  final Map<String, ApplicationUsage> _usage;
  ForegroundApplication? _currentApplication;
  Duration? _activeSince;
  bool _isActive = false;

  void setActive(bool active) {
    if (active == _isActive) return;
    _commit();
    _isActive = active;
    if (active && _currentApplication != null) {
      _activeSince = _clock.elapsed;
    }
  }

  void observe(ForegroundApplication? application) {
    if (_currentApplication?.id == application?.id) {
      if (application != null) {
        _currentApplication = application;
        final previous = _usage[application.id];
        if (previous != null) {
          _usage[application.id] = previous.copyWith(
            displayName: application.resolvedDisplayName,
            executableName: application.executableName,
          );
        }
      }
      return;
    }
    _commit();
    _currentApplication = application;
    if (_isActive && application != null) {
      _activeSince = _clock.elapsed;
    }
  }

  List<ApplicationUsage> snapshot() {
    final result = Map<String, ApplicationUsage>.of(_usage);
    final application = _currentApplication;
    final activeSince = _activeSince;
    if (_isActive && application != null && activeSince != null) {
      _addTo(result, application, _clock.elapsed - activeSince);
    }
    return result.values.toList(growable: false);
  }

  List<ApplicationUsage> checkpoint() {
    _commit();
    if (_isActive && _currentApplication != null) {
      _activeSince = _clock.elapsed;
    }
    return _usage.values.toList(growable: false);
  }

  void _commit() {
    final application = _currentApplication;
    final activeSince = _activeSince;
    if (_isActive && application != null && activeSince != null) {
      _addTo(_usage, application, _clock.elapsed - activeSince);
    }
    _activeSince = null;
  }

  static void _addTo(
    Map<String, ApplicationUsage> target,
    ForegroundApplication application,
    Duration duration,
  ) {
    if (duration <= Duration.zero) return;
    final previous = target[application.id];
    target[application.id] = ApplicationUsage(
      applicationId: application.id,
      displayName: application.resolvedDisplayName,
      executableName: application.executableName,
      activeDuration: (previous?.activeDuration ?? Duration.zero) + duration,
    );
  }
}

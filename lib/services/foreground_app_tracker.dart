import 'dart:async';

import '../features/application_tracking/application_models.dart';
import 'platform_service.dart';

abstract interface class ForegroundAppTracker {
  Stream<ForegroundApplication?> get activeApplication;
  Future<ForegroundApplication?> currentApplication();
  void dispose();
}

class WindowsForegroundAppTracker implements ForegroundAppTracker {
  WindowsForegroundAppTracker(
    this._platform, {
    Duration pollInterval = const Duration(seconds: 1),
  }) {
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  final PlatformService _platform;
  final _controller = StreamController<ForegroundApplication?>.broadcast();
  Timer? _timer;
  String? _lastSignature;
  bool _polling = false;

  @override
  Stream<ForegroundApplication?> get activeApplication => _controller.stream;

  @override
  Future<ForegroundApplication?> currentApplication() =>
      _platform.foregroundApplication();

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final application = await currentApplication();
      final signature = application == null
          ? null
          : '${application.id}\u0000${application.displayName}\u0000${application.windowTitle}';
      if (signature != _lastSignature) {
        _lastSignature = signature;
        _controller.add(application);
      }
    } on Object {
      if (_lastSignature != null) {
        _lastSignature = null;
        _controller.add(null);
      }
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_controller.close());
  }
}

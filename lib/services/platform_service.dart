import 'dart:async';

import 'package:flutter/services.dart';

import '../app/app_constants.dart';

enum PlatformEvent {
  locked,
  unlocked,
  suspend,
  resume,
  trayOpen,
  trayToggle,
  trayAutostart,
  trayTopmost,
  trayQuit,
}

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.idleDuration,
    required this.isLocked,
    required this.isSleeping,
  });
  final Duration idleDuration;
  final bool isLocked;
  final bool isSleeping;
}

class WindowPosition {
  const WindowPosition(this.x, this.y);
  final double x;
  final double y;
}

abstract interface class PlatformService {
  Stream<PlatformEvent> get events;
  Future<ActivitySnapshot> activitySnapshot();
  Future<String> bootId();
  Future<void> configureOverlay({
    required bool alwaysOnTop,
    double? x,
    double? y,
  });
  Future<WindowPosition?> beginDrag();
  Future<void> resize(double width, double height);
  Future<void> show();
  Future<void> hide();
  Future<void> setAlwaysOnTop(bool value);
  Future<bool> isAutostartEnabled();
  Future<void> setAutostartEnabled(bool value);
  Future<void> updateTray({
    required bool collapsed,
    required bool autostart,
    required bool alwaysOnTop,
  });
  Future<void> quit();
}

class WindowsPlatformService implements PlatformService {
  WindowsPlatformService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(AppConstants.nativeChannel) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final _events = StreamController<PlatformEvent>.broadcast();

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'nativeEvent') return null;
    final event = PlatformEvent.values
        .where((value) => value.name == call.arguments)
        .firstOrNull;
    if (event != null) _events.add(event);
    return null;
  }

  @override
  Stream<PlatformEvent> get events => _events.stream;

  @override
  Future<ActivitySnapshot> activitySnapshot() async {
    final value =
        await _channel.invokeMapMethod<String, Object?>('activitySnapshot') ??
        const {};
    return ActivitySnapshot(
      idleDuration: Duration(
        milliseconds: (value['idleMilliseconds'] as num?)?.toInt() ?? 0,
      ),
      isLocked: value['locked'] as bool? ?? false,
      isSleeping: value['sleeping'] as bool? ?? false,
    );
  }

  @override
  Future<String> bootId() async =>
      await _channel.invokeMethod<String>('bootId') ?? 'unknown-boot';

  @override
  Future<void> configureOverlay({
    required bool alwaysOnTop,
    double? x,
    double? y,
  }) => _channel.invokeMethod<void>('configureOverlay', {
    'alwaysOnTop': alwaysOnTop,
    'x': x,
    'y': y,
  });

  @override
  Future<WindowPosition?> beginDrag() async {
    final value = await _channel.invokeMapMethod<String, Object?>('beginDrag');
    if (value == null) return null;
    return WindowPosition(
      (value['x'] as num).toDouble(),
      (value['y'] as num).toDouble(),
    );
  }

  @override
  Future<void> resize(double width, double height) =>
      _channel.invokeMethod<void>('resize', {'width': width, 'height': height});
  @override
  Future<void> show() => _channel.invokeMethod<void>('show');
  @override
  Future<void> hide() => _channel.invokeMethod<void>('hide');
  @override
  Future<void> setAlwaysOnTop(bool value) =>
      _channel.invokeMethod<void>('setAlwaysOnTop', value);
  @override
  Future<bool> isAutostartEnabled() async =>
      await _channel.invokeMethod<bool>('isAutostartEnabled') ?? false;
  @override
  Future<void> setAutostartEnabled(bool value) =>
      _channel.invokeMethod<void>('setAutostartEnabled', value);
  @override
  Future<void> updateTray({
    required bool collapsed,
    required bool autostart,
    required bool alwaysOnTop,
  }) => _channel.invokeMethod<void>('updateTray', {
    'collapsed': collapsed,
    'autostart': autostart,
    'alwaysOnTop': alwaysOnTop,
  });
  @override
  Future<void> quit() => _channel.invokeMethod<void>('quit');
}

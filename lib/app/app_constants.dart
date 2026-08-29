import 'package:flutter/widgets.dart';

abstract final class AppConstants {
  static const String name = 'Lapse';
  static const String nativeChannel = 'dev.lapse/windows';
  static const Duration idleTimeout = Duration(minutes: 5);
  static const Duration activityPollInterval = Duration(seconds: 1);
  static const Duration persistenceCheckpoint = Duration(seconds: 30);
  static const Size expandedSize = Size(312, 356);
  static const Size collapsedSize = Size(228, 52);
}

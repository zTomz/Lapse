import '../features/session/session_models.dart';

abstract interface class ActivityDetector {
  Stream<UserActivityState> get states;
  Future<UserActivityState> currentState();
  void dispose();
}

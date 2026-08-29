import 'dart:convert';

import '../application_tracking/application_models.dart';

enum UserActivityState { active, paused, idle, locked, sleeping }

enum OverlayMode { expanded, collapsed }

class SessionTask {
  const SessionTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  SessionTask copyWith({String? title, bool? isCompleted}) => SessionTask(
    id: id,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
  };

  factory SessionTask.fromJson(Map<String, Object?> json) => SessionTask(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

class ComputerSession {
  const ComputerSession({
    required this.id,
    required this.startedAt,
    required this.activeDuration,
    required this.tasks,
    this.endedAt,
    this.isPaused = false,
    this.applicationUsage = const [],
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration activeDuration;
  final List<SessionTask> tasks;
  final bool isPaused;
  final List<ApplicationUsage> applicationUsage;

  ComputerSession copyWith({
    Duration? activeDuration,
    List<SessionTask>? tasks,
    DateTime? endedAt,
    bool? isPaused,
    List<ApplicationUsage>? applicationUsage,
  }) => ComputerSession(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    activeDuration: activeDuration ?? this.activeDuration,
    tasks: tasks ?? this.tasks,
    isPaused: isPaused ?? this.isPaused,
    applicationUsage: applicationUsage ?? this.applicationUsage,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'activeMilliseconds': activeDuration.inMilliseconds,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'isPaused': isPaused,
    'applicationUsage': applicationUsage
        .map((usage) => usage.toJson())
        .toList(),
  };

  factory ComputerSession.fromJson(Map<String, Object?> json) {
    final rawTasks = json['tasks'] as List<Object?>? ?? const [];
    return ComputerSession(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
      endedAt: switch (json['endedAt']) {
        final String value => DateTime.parse(value).toLocal(),
        _ => null,
      },
      activeDuration: Duration(
        milliseconds: (json['activeMilliseconds'] as num?)?.toInt() ?? 0,
      ),
      tasks: rawTasks
          .map((value) => SessionTask.fromJson(value! as Map<String, Object?>))
          .toList(growable: false),
      isPaused: json['isPaused'] as bool? ?? false,
      applicationUsage: (json['applicationUsage'] as List<Object?>? ?? const [])
          .map(
            (value) =>
                ApplicationUsage.fromJson(value! as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }
}

class LapsePreferences {
  const LapsePreferences({
    this.overlayMode = OverlayMode.expanded,
    this.alwaysOnTop = true,
    this.autostart = true,
    this.windowX,
    this.windowY,
    this.dashboardX,
    this.dashboardY,
    this.dashboardWidth = 1000,
    this.dashboardHeight = 680,
  });

  final OverlayMode overlayMode;
  final bool alwaysOnTop;
  final bool autostart;
  final double? windowX;
  final double? windowY;
  final double? dashboardX;
  final double? dashboardY;
  final double dashboardWidth;
  final double dashboardHeight;

  LapsePreferences copyWith({
    OverlayMode? overlayMode,
    bool? alwaysOnTop,
    bool? autostart,
    double? windowX,
    double? windowY,
    double? dashboardX,
    double? dashboardY,
    double? dashboardWidth,
    double? dashboardHeight,
  }) => LapsePreferences(
    overlayMode: overlayMode ?? this.overlayMode,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    autostart: autostart ?? this.autostart,
    windowX: windowX ?? this.windowX,
    windowY: windowY ?? this.windowY,
    dashboardX: dashboardX ?? this.dashboardX,
    dashboardY: dashboardY ?? this.dashboardY,
    dashboardWidth: dashboardWidth ?? this.dashboardWidth,
    dashboardHeight: dashboardHeight ?? this.dashboardHeight,
  );

  Map<String, Object?> toJson() => {
    'overlayMode': overlayMode.name,
    'alwaysOnTop': alwaysOnTop,
    'autostart': autostart,
    'windowX': windowX,
    'windowY': windowY,
    'dashboardX': dashboardX,
    'dashboardY': dashboardY,
    'dashboardWidth': dashboardWidth,
    'dashboardHeight': dashboardHeight,
  };

  factory LapsePreferences.fromJson(Map<String, Object?> json) {
    final modeName = json['overlayMode'] as String?;
    return LapsePreferences(
      overlayMode:
          OverlayMode.values
              .where((mode) => mode.name == modeName)
              .firstOrNull ??
          OverlayMode.expanded,
      alwaysOnTop: json['alwaysOnTop'] as bool? ?? true,
      autostart: json['autostart'] as bool? ?? true,
      windowX: (json['windowX'] as num?)?.toDouble(),
      windowY: (json['windowY'] as num?)?.toDouble(),
      dashboardX: (json['dashboardX'] as num?)?.toDouble(),
      dashboardY: (json['dashboardY'] as num?)?.toDouble(),
      dashboardWidth: (json['dashboardWidth'] as num?)?.toDouble() ?? 1000,
      dashboardHeight: (json['dashboardHeight'] as num?)?.toDouble() ?? 680,
    );
  }
}

class PersistedAppState {
  const PersistedAppState({
    required this.bootId,
    required this.session,
    required this.preferences,
    this.sessionHistory = const [],
  });

  static const schemaVersion = 2;
  final String bootId;
  final ComputerSession session;
  final LapsePreferences preferences;
  final List<ComputerSession> sessionHistory;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': schemaVersion,
    'bootId': bootId,
    'session': session.toJson(),
    'preferences': preferences.toJson(),
    'sessionHistory': sessionHistory
        .map((session) => session.toJson())
        .toList(),
  });

  factory PersistedAppState.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > schemaVersion) {
      throw const FormatException('Unsupported Lapse data schema');
    }
    return PersistedAppState(
      bootId: json['bootId'] as String,
      session: ComputerSession.fromJson(
        json['session']! as Map<String, Object?>,
      ),
      preferences: LapsePreferences.fromJson(
        json['preferences']! as Map<String, Object?>,
      ),
      sessionHistory: (json['sessionHistory'] as List<Object?>? ?? const [])
          .map(
            (value) => ComputerSession.fromJson(value! as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }
}

class SessionViewState {
  const SessionViewState({
    required this.session,
    required this.preferences,
    required this.activityState,
    required this.displayDuration,
    this.isReady = false,
    this.errorMessage,
    this.sessionHistory = const [],
  });

  final ComputerSession session;
  final LapsePreferences preferences;
  final UserActivityState activityState;
  final Duration displayDuration;
  final bool isReady;
  final String? errorMessage;
  final List<ComputerSession> sessionHistory;

  List<ComputerSession> get allSessions => [...sessionHistory, session];

  int get completedTaskCount =>
      session.tasks.where((task) => task.isCompleted).length;

  SessionViewState copyWith({
    ComputerSession? session,
    LapsePreferences? preferences,
    UserActivityState? activityState,
    Duration? displayDuration,
    bool? isReady,
    String? errorMessage,
    List<ComputerSession>? sessionHistory,
  }) => SessionViewState(
    session: session ?? this.session,
    preferences: preferences ?? this.preferences,
    activityState: activityState ?? this.activityState,
    displayDuration: displayDuration ?? this.displayDuration,
    isReady: isReady ?? this.isReady,
    errorMessage: errorMessage,
    sessionHistory: sessionHistory ?? this.sessionHistory,
  );
}

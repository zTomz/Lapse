import 'dart:convert';

enum UserActivityState { active, idle, locked, sleeping }

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
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration activeDuration;
  final List<SessionTask> tasks;

  ComputerSession copyWith({
    Duration? activeDuration,
    List<SessionTask>? tasks,
    DateTime? endedAt,
  }) => ComputerSession(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    activeDuration: activeDuration ?? this.activeDuration,
    tasks: tasks ?? this.tasks,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'activeMilliseconds': activeDuration.inMilliseconds,
    'tasks': tasks.map((task) => task.toJson()).toList(),
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
  });

  final OverlayMode overlayMode;
  final bool alwaysOnTop;
  final bool autostart;
  final double? windowX;
  final double? windowY;

  LapsePreferences copyWith({
    OverlayMode? overlayMode,
    bool? alwaysOnTop,
    bool? autostart,
    double? windowX,
    double? windowY,
  }) => LapsePreferences(
    overlayMode: overlayMode ?? this.overlayMode,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    autostart: autostart ?? this.autostart,
    windowX: windowX ?? this.windowX,
    windowY: windowY ?? this.windowY,
  );

  Map<String, Object?> toJson() => {
    'overlayMode': overlayMode.name,
    'alwaysOnTop': alwaysOnTop,
    'autostart': autostart,
    'windowX': windowX,
    'windowY': windowY,
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
    );
  }
}

class PersistedAppState {
  const PersistedAppState({
    required this.bootId,
    required this.session,
    required this.preferences,
  });

  static const schemaVersion = 1;
  final String bootId;
  final ComputerSession session;
  final LapsePreferences preferences;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': schemaVersion,
    'bootId': bootId,
    'session': session.toJson(),
    'preferences': preferences.toJson(),
  });

  factory PersistedAppState.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    if (json['schemaVersion'] != schemaVersion) {
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
  });

  final ComputerSession session;
  final LapsePreferences preferences;
  final UserActivityState activityState;
  final Duration displayDuration;
  final bool isReady;
  final String? errorMessage;

  int get completedTaskCount =>
      session.tasks.where((task) => task.isCompleted).length;

  SessionViewState copyWith({
    ComputerSession? session,
    LapsePreferences? preferences,
    UserActivityState? activityState,
    Duration? displayDuration,
    bool? isReady,
    String? errorMessage,
  }) => SessionViewState(
    session: session ?? this.session,
    preferences: preferences ?? this.preferences,
    activityState: activityState ?? this.activityState,
    displayDuration: displayDuration ?? this.displayDuration,
    isReady: isReady ?? this.isReady,
    errorMessage: errorMessage,
  );
}

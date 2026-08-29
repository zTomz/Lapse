class ForegroundApplication {
  const ForegroundApplication({
    required this.processId,
    required this.executablePath,
    required this.executableName,
    required this.displayName,
    required this.observedAt,
    this.windowTitle = '',
  });

  final int processId;
  final String executablePath;
  final String executableName;
  final String displayName;
  final DateTime observedAt;
  final String windowTitle;

  String get id => executablePath.isNotEmpty
      ? executablePath.toLowerCase()
      : executableName.toLowerCase();

  String get resolvedDisplayName => applicationDisplayName(
    executableName: executableName,
    reportedDisplayName: displayName,
    windowTitle: windowTitle,
  );
}

class ApplicationUsage {
  const ApplicationUsage({
    required this.applicationId,
    required this.displayName,
    required this.executableName,
    required this.activeDuration,
  });

  final String applicationId;
  final String displayName;
  final String executableName;
  final Duration activeDuration;

  ApplicationUsage copyWith({
    String? displayName,
    String? executableName,
    Duration? activeDuration,
  }) => ApplicationUsage(
    applicationId: applicationId,
    displayName: displayName ?? this.displayName,
    executableName: executableName ?? this.executableName,
    activeDuration: activeDuration ?? this.activeDuration,
  );

  Map<String, Object?> toJson() => {
    'applicationId': applicationId,
    'displayName': displayName,
    'executableName': executableName,
    'activeMilliseconds': activeDuration.inMilliseconds,
  };

  factory ApplicationUsage.fromJson(Map<String, Object?> json) {
    final executableName = json['executableName'] as String? ?? '';
    final reportedName =
        json['displayName'] as String? ??
        (executableName.isEmpty ? 'Unknown application' : executableName);
    return ApplicationUsage(
      applicationId: json['applicationId'] as String,
      displayName: applicationDisplayName(
        executableName: executableName,
        reportedDisplayName: reportedName,
      ),
      executableName: executableName,
      activeDuration: Duration(
        milliseconds: (json['activeMilliseconds'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

String applicationDisplayName({
  required String executableName,
  required String reportedDisplayName,
  String windowTitle = '',
}) {
  final reported = reportedDisplayName.trim();
  final title = windowTitle.trim();
  final genericMetadata = _isGenericApplicationName(reported);
  if (genericMetadata &&
      title.isNotEmpty &&
      !_isGenericApplicationName(title)) {
    return title;
  }
  if (reported.isEmpty || genericMetadata || _isExecutableName(reported)) {
    return _friendlyExecutableName(executableName);
  }
  return reported;
}

bool _isGenericApplicationName(String value) {
  final normalized = value.toLowerCase();
  return normalized.isEmpty ||
      normalized == 'application' ||
      normalized == 'game' ||
      normalized.contains('unreal engine') ||
      normalized == 'unity' ||
      normalized.contains('unity player') ||
      normalized == 'electron' ||
      normalized == 'chromium' ||
      (normalized.contains('microsoft') &&
          (normalized.contains('windows') ||
              normalized.contains('betriebssystem'))) ||
      normalized.contains('java platform') ||
      normalized.contains('openjdk platform');
}

bool _isExecutableName(String value) =>
    value.toLowerCase().trim().endsWith('.exe');

String _friendlyExecutableName(String executableName) {
  var name = executableName.trim().replaceFirst(
    RegExp(r'\.exe$', caseSensitive: false),
    '',
  );
  name = name.replaceFirst(
    RegExp(
      r'(?:client)?[-_](?:win32|win64)(?:[-_](?:shipping|test|development))?.*$',
      caseSensitive: false,
    ),
    '',
  );
  name = name.replaceFirst(
    RegExp(r'[-_](?:shipping|development|release)$', caseSensitive: false),
    '',
  );
  name = name
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .trim();
  return name.isEmpty ? 'Unknown application' : name;
}

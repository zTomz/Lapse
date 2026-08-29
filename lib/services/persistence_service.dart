import 'dart:io';

import '../features/session/session_models.dart';

abstract interface class PersistenceService {
  Future<PersistedAppState?> load();
  Future<void> save(PersistedAppState state);
}

class JsonPersistenceService implements PersistenceService {
  JsonPersistenceService({Directory? directory})
    : _directory = directory ?? _defaultDirectory();

  final Directory _directory;
  File get _file =>
      File('${_directory.path}${Platform.pathSeparator}state.json');

  static Directory _defaultDirectory() {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    return Directory('$base${Platform.pathSeparator}Lapse');
  }

  @override
  Future<PersistedAppState?> load() async {
    try {
      if (!await _file.exists()) return null;
      return PersistedAppState.decode(await _file.readAsString());
    } on Object catch (error) {
      stderr.writeln('Lapse: unable to restore state: $error');
      return null;
    }
  }

  @override
  Future<void> save(PersistedAppState state) async {
    try {
      await _directory.create(recursive: true);
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(state.encode(), flush: true);
      if (await _file.exists()) await _file.delete();
      await temporary.rename(_file.path);
    } on Object catch (error) {
      stderr.writeln('Lapse: unable to persist state: $error');
    }
  }
}

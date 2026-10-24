import 'dart:io' show Process, ProcessException;

import 'package:file/file.dart';
import 'package:file/local.dart';

import 'play_defaults.dart';
import 'play_event.dart';
import 'play_session.dart';
import 'scene_watcher.dart';

/// Starts a process; [Process.start]'s shape, so tests can pass a fake.
typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// The arguments for `flutter run`: the macOS desktop target in debug mode,
/// with VM service auth codes on (Q81) and no IDE workarounds (research R9).
const _runArguments = ['run', '--machine', '-d', 'macos', '--debug'];

/// Starts the developer's game with `flutter run --machine` and Hot-swaps its
/// Scenes when they change on disk (project plan §9.3; spec 005).
final class PlayClient {
  /// Creates a client that runs [flutter] (on `PATH` by default) through
  /// [startProcess] and checks and watches files through [fileSystem] and
  /// [watchDirectory]. A burst of Scene changes becomes one hot reload after
  /// [quietPeriod]; [PlaySession.stop] escalates to SIGTERM after
  /// [stopTimeout].
  PlayClient({
    this.flutter = 'flutter',
    this._startProcess = Process.start,
    FileSystem fileSystem = const LocalFileSystem(),
    this._watchDirectory = watchRecursively,
    this.quietPeriod = PlayDefaults.sceneQuiet,
    this.stopTimeout = PlayDefaults.stopTimeout,
  }) : _fs = fileSystem;

  /// The `flutter` executable.
  final String flutter;

  /// How long Scene files must stay unchanged before a hot reload (R8).
  final Duration quietPeriod;

  /// How long [PlaySession.stop] waits after `app.stop` (R10).
  final Duration stopTimeout;

  final ProcessStarter _startProcess;
  final FileSystem _fs;
  final DirectoryWatcher _watchDirectory;

  /// Spawns `flutter run --machine -d macos --debug` in [projectPath].
  ///
  /// [onStdoutLine] receives every stdout line of the process, auth codes
  /// masked, before it is parsed (the CLI's `--record`).
  ///
  /// Throws [PlayStartException] when the project has no `pubspec.yaml` or
  /// `macos/` folder, or when the executable can't be started.
  Future<PlaySession> start(
    String projectPath, {
    void Function(String line)? onStdoutLine,
  }) async {
    final path = _fs.path.normalize(_fs.path.absolute(projectPath));
    if (!_fs.file(_fs.path.join(path, 'pubspec.yaml')).existsSync()) {
      throw PlayStartException(path, 'there is no pubspec.yaml in it.');
    }
    if (!_fs.directory(_fs.path.join(path, 'macos')).existsSync()) {
      throw PlayStartException(
        path,
        'it has no macos/ folder; add the macOS target with '
        '`flutter create --platforms=macos .`.',
      );
    }
    final Process process;
    try {
      process = await _startProcess(
        flutter,
        _runArguments,
        workingDirectory: path,
      );
    } on ProcessException catch (error) {
      throw PlayStartException(
        path,
        'could not start "${error.executable}": ${error.message}',
      );
    }
    return startPlaySession(
      process: process,
      command: [flutter, ..._runArguments].join(' '),
      projectPath: path,
      fileSystem: _fs,
      watchDirectory: _watchDirectory,
      quietPeriod: quietPeriod,
      stopTimeout: stopTimeout,
      onStdoutLine: onStdoutLine,
    );
  }
}

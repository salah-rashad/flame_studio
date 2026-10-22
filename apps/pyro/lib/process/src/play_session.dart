import 'dart:async';
import 'dart:convert';
import 'dart:io' show Process, ProcessSignal;

import 'package:clock/clock.dart';
import 'package:file/file.dart';

import 'daemon_message.dart';
import 'play_event.dart';
import 'redact.dart';
import 'scene_watcher.dart';

/// How long the process may take to exit after SIGTERM before SIGKILL
/// (research R10).
const _killDelay = Duration(seconds: 2);

/// How long to wait, after the process exits, for its last output lines: a
/// grandchild that inherited the pipe could keep it open for ever.
const _drainLimit = Duration(seconds: 1);

/// How many output lines a start failure quotes (research R11).
const _tailLength = 20;

/// Creates the session for an already spawned `flutter run --machine`.
/// `PlayClient.start` is the only caller; it isn't exported.
PlaySession startPlaySession({
  required Process process,
  required String command,
  required String projectPath,
  required FileSystem fileSystem,
  required DirectoryWatcher watchDirectory,
  required Duration quietPeriod,
  required Duration stopTimeout,
  void Function(String line)? onStdoutLine,
}) => PlaySession._(
  process: process,
  command: command,
  projectPath: projectPath,
  fileSystem: fileSystem,
  watchDirectory: watchDirectory,
  quietPeriod: quietPeriod,
  stopTimeout: stopTimeout,
  onStdoutLine: onStdoutLine,
);

/// One run of a game through `flutter run --machine`, from spawn to exit
/// (*Play session* in the glossary; spec 005, data model).
///
/// It reads the daemon's messages, reports them as [events], hot-reloads the
/// game when its Scene files change (one reload at a time, at most one more
/// queued), and stops it on request. It writes nothing to the project.
final class PlaySession {
  PlaySession._({
    required this._process,
    required String command,
    required this.projectPath,
    required FileSystem fileSystem,
    required DirectoryWatcher watchDirectory,
    required Duration quietPeriod,
    required this._stopTimeout,
    this._onStdoutLine,
  }) {
    _watcher = SceneWatcher(
      fileSystem: fileSystem,
      projectPath: projectPath,
      watch: watchDirectory,
      quietPeriod: quietPeriod,
      onChanges: _onSceneChanges,
      onNote: (note) => _output(note, PlayOutputSource.tool),
    );
    _emit(PlayStarting(command: command, projectPath: projectPath));
    // Watch from the spawn: the game can read its Scene before the daemon
    // reports app.started, and a save in between must not be lost.
    _watcher.start();
    final stdoutDone = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onStdout)
        .asFuture<void>();
    final stderrDone = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _output(line, PlayOutputSource.stderr))
        .asFuture<void>();
    // A write after the process exited fails the sink; the exit is
    // reported on its own, so that error carries nothing new.
    _process.stdin.done.ignore();
    unawaited(
      _process.exitCode.then(
        (code) => _onExit(code, Future.wait([stdoutDone, stderrDone])),
      ),
    );
  }

  /// The project the game runs from.
  final String projectPath;

  final Process _process;
  final Duration _stopTimeout;
  final void Function(String line)? _onStdoutLine;
  late final SceneWatcher _watcher;
  final _events = StreamController<PlayEvent>();
  final _stopwatch = clock.stopwatch()..start();
  final _pending = <int, Completer<DaemonResponse>>{};
  final _tail = <String>[];
  final _changedWhileStarting = <String>{};
  final _done = Completer<void>();
  var _nextId = 1;
  var _state = PlayState.starting;
  String? _appId;
  bool _debuggerReported = false;
  bool _started = false;
  bool _stopRequested = false;
  Object? _stopError;
  bool _reloadInFlight = false;
  Set<String>? _queuedPaths;
  Completer<ReloadResult>? _queuedReload;
  Timer? _terminate;
  Timer? _kill;

  /// Where the session is in its life.
  PlayState get state => _state;

  /// The daemon's id for the running app, once `flutter run` reports it.
  String? get appId => _appId;

  /// Every event of this session, in order; closes after [PlayStopped].
  /// Single subscription: events wait until it is listened to.
  Stream<PlayEvent> get events => _events.stream;

  /// Completes with the `flutter run` process's exit code.
  Future<int> get exitCode => _process.exitCode;

  /// Hot-reloads now, without waiting for a Scene change. Queued behind a
  /// reload already in flight.
  ///
  /// Throws [StateError] unless the game is running or reloading. The
  /// returned future fails with a [StateError] if the session stops first.
  Future<ReloadResult> reload() {
    if (_state != PlayState.running && _state != PlayState.reloading) {
      throw StateError(
        "Can't hot-reload $projectPath while the Play session is "
        '${_state.name}.',
      );
    }
    return _requestReload(const {});
  }

  /// Sends `app.stop`, then SIGTERM after the stop timeout and SIGKILL two
  /// seconds later if the process still hasn't exited (research R10).
  /// Completes once it has exited. Safe to call more than once.
  Future<void> stop() {
    if (_stopRequested || _state == PlayState.stopped) return _done.future;
    _stopRequested = true;
    _state = PlayState.stopping;
    final appId = _appId;
    if (appId == null) {
      // Still building: there is no app to stop, only the tool.
      _process.kill(ProcessSignal.sigterm);
    } else {
      _send('app.stop', {'appId': appId}).ignore();
    }
    _terminate = Timer(_stopTimeout, () {
      _process.kill(ProcessSignal.sigterm);
      _kill = Timer(_killDelay, () => _process.kill(ProcessSignal.sigkill));
    });
    return _done.future;
  }

  void _onStdout(String line) {
    _onStdoutLine?.call(redactAuthCodes(line));
    for (final message in parseDaemonLine(line)) {
      switch (message) {
        case RawLine(:final text):
          _output(text, PlayOutputSource.game);
        case DaemonResponse(:final id):
          _pending.remove(id)?.complete(message);
        case DaemonEvent(:final name, :final params):
          _onEvent(name, params);
      }
    }
  }

  void _onEvent(String name, Map<String, Object?> params) {
    switch (name) {
      case 'daemon.connected':
        break;
      case 'app.start':
        _appId = params['appId'] as String?;
      case 'app.debugPort':
        // The address is dropped here on purpose (research R5).
        if (!_debuggerReported) {
          _debuggerReported = true;
          _emit(const PlayDebuggerAvailable());
        }
      case 'app.devTools' || 'app.dtd':
        // DevTools and the tooling daemon: addresses, dropped like the VM
        // service's (research R5).
        break;
      case 'app.started':
        if (_state == PlayState.starting) {
          _state = PlayState.running;
          _started = true;
          _appId ??= params['appId'] as String?;
          _emit(PlayStarted(appId: _appId ?? '', elapsed: _stopwatch.elapsed));
          final missed = _changedWhileStarting;
          if (missed.isNotEmpty) _requestReload(Set.of(missed)).ignore();
          missed.clear();
        }
      case 'app.log':
        final log = params['log'];
        if (log is String) _output(log.trimRight(), PlayOutputSource.game);
      case 'app.progress':
        final message = params['message'];
        if (params['finished'] != true && message is String) {
          _output(message, PlayOutputSource.tool);
        }
      case 'daemon.logMessage':
        final message = params['message'];
        if (message is String) _output(message, PlayOutputSource.tool);
      case 'app.stop':
        _stopError = params['error'];
      default:
        _output('$name ${jsonEncode(params)}', PlayOutputSource.tool);
    }
  }

  void _onSceneChanges(Set<String> paths) {
    if (_state == PlayState.starting) {
      // Reloaded once the game has started (it may already have read
      // the old file); the Runtime ignores it if the game read the new one.
      _changedWhileStarting.addAll(paths);
      return;
    }
    if (_state != PlayState.running && _state != PlayState.reloading) return;
    // Watcher-driven reloads report through events; a failure has already
    // been reported as PlayReloadFailed, and a stop as PlayStopped.
    _requestReload(paths).ignore();
  }

  Future<ReloadResult> _requestReload(Set<String> paths) {
    if (!_reloadInFlight) return _runReload(paths);
    (_queuedPaths ??= {}).addAll(paths);
    return (_queuedReload ??= Completer<ReloadResult>()).future;
  }

  Future<ReloadResult> _runReload(Set<String> paths) async {
    _reloadInFlight = true;
    _state = PlayState.reloading;
    _emit(PlayReloading(paths.toList()..sort()));
    final started = clock.now();
    final DaemonResponse response;
    try {
      response = await _send('app.restart', {
        'appId': _appId,
        'fullRestart': false,
        'pause': false,
        'reason': 'pyro',
      });
    } finally {
      _reloadInFlight = false;
    }
    final result = _reloadResult(response, clock.now().difference(started));
    final failure = result.ok ? null : result.message ?? 'unknown error';
    _emit(
      failure == null
          ? PlayReloaded(result.elapsed)
          : PlayReloadFailed(failure, code: _code(response)),
    );
    if (_state == PlayState.reloading) _state = PlayState.running;
    final queued = _queuedPaths;
    final waiting = _queuedReload;
    _queuedPaths = null;
    _queuedReload = null;
    if (queued != null && waiting != null) {
      waiting.complete(_runReload(queued));
    }
    return result;
  }

  ReloadResult _reloadResult(DaemonResponse response, Duration elapsed) {
    final error = response.error;
    if (error != null) {
      return ReloadResult(
        ok: false,
        message: redactAuthCodes('$error'),
        elapsed: elapsed,
      );
    }
    final result = response.result;
    final message = result is Map<String, Object?> ? result['message'] : null;
    return ReloadResult(
      ok: _code(response) == 0,
      message: message is String && message.isNotEmpty
          ? redactAuthCodes(message)
          : null,
      elapsed: elapsed,
    );
  }

  int? _code(DaemonResponse response) {
    final result = response.result;
    final code = result is Map<String, Object?> ? result['code'] : null;
    return code is int ? code : null;
  }

  Future<DaemonResponse> _send(String method, Map<String, Object?> params) {
    if (_state == PlayState.stopped) {
      return Future.error(_stoppedError());
    }
    final id = _nextId++;
    final response = Completer<DaemonResponse>();
    _pending[id] = response;
    _process.stdin.writeln(
      jsonEncode([
        {'id': id, 'method': method, 'params': params},
      ]),
    );
    return response.future;
  }

  void _output(String line, PlayOutputSource source) {
    final redacted = redactAuthCodes(line);
    _tail.add(redacted);
    if (_tail.length > _tailLength) _tail.removeAt(0);
    _emit(PlayOutput(redacted, source));
  }

  void _emit(PlayEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  StateError _stoppedError() =>
      StateError('The Play session for $projectPath has stopped.');

  Future<void> _onExit(int code, Future<void> outputDone) async {
    // Report the last lines before the stop, but don't wait for ever.
    await Future.any([
      outputDone.catchError((Object _) {}),
      Future<void>.delayed(_drainLimit),
    ]);
    _terminate?.cancel();
    _kill?.cancel();
    _watcher.close();
    _state = PlayState.stopped;
    final error = _stoppedError();
    for (final pending in _pending.values) {
      pending.completeError(error);
    }
    _pending.clear();
    _queuedReload?.completeError(error);
    _queuedReload = null;
    if (!_started && !_stopRequested) {
      final reason = _stopError;
      _emit(
        PlayFailed(
          message: reason != null
              ? "The game couldn't start: ${redactAuthCodes('$reason')}"
              : 'flutter run exited with code $code before the game started.',
          exitCode: code,
          outputTail: List.unmodifiable(_tail),
        ),
      );
    }
    _emit(PlayStopped(exitCode: code, requested: _stopRequested));
    await _events.close();
    _done.complete();
  }
}

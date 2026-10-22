# Contract: Play client API

The public surface of `apps/pyro/lib/process/process.dart`. Its callers are `bin/play.dart` and
`benchmark/hot_swap_latency.dart` in this slice, and in Phase 4 the Play button's provider.
Everything else stays under `lib/process/src/`. The library imports no Flutter (research R2).

## Exports

```dart
/// Starts the developer's game with `flutter run --machine` and Hot-swaps its
/// Scenes when they change on disk (project plan §9.3).
class PlayClient {
  PlayClient({
    String flutter = 'flutter',
    ProcessStarter startProcess = Process.start,
    FileSystem fileSystem = const LocalFileSystem(),
    DirectoryWatcher watchDirectory = watchRecursively,
    Duration quietPeriod = const Duration(milliseconds: 150),
    Duration stopTimeout = const Duration(seconds: 5),
  });

  /// Spawns `flutter run --machine -d macos --debug` in [projectPath].
  ///
  /// Throws [PlayStartException] when the project has no `pubspec.yaml` or
  /// `macos/` folder (checked through [fileSystem]), or when the executable
  /// can't be started.
  Future<PlaySession> start(String projectPath);
}

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

typedef DirectoryWatcher = Stream<FileSystemEvent> Function(Directory directory);

/// `directory.watch(recursive: true)`.
Stream<FileSystemEvent> watchRecursively(Directory directory);

class PlaySession {
  String get projectPath;
  PlayState get state;
  String? get appId;

  /// Every event of this session, in order; closes after [PlayStopped].
  /// Single subscription: listen before awaiting anything else.
  Stream<PlayEvent> get events;

  /// Completes with the process's exit code.
  Future<int> get exitCode;

  /// Hot-reloads now, without waiting for a Scene change (the CLI's `r`).
  /// Queued behind a reload already in flight. Throws [StateError] unless
  /// [state] is running or reloading.
  Future<ReloadResult> reload();

  /// Sends `app.stop`, then terminates the process if it hasn't exited in
  /// time. Completes once it has exited. Safe to call more than once.
  Future<void> stop();
}

enum PlayState { starting, running, reloading, stopping, stopped }

final class ReloadResult {
  final bool ok;
  final String? message;
  final Duration elapsed;
}

sealed class PlayEvent {}
final class PlayStarting extends PlayEvent { final String command; final String projectPath; }
final class PlayDebuggerAvailable extends PlayEvent {}
final class PlayStarted extends PlayEvent { final String appId; final Duration elapsed; }
final class PlayOutput extends PlayEvent { final String line; final PlayOutputSource source; }
final class PlayReloading extends PlayEvent { final List<String> paths; }
final class PlayReloaded extends PlayEvent { final Duration elapsed; }
final class PlayReloadFailed extends PlayEvent { final String message; final int? code; }
final class PlayFailed extends PlayEvent {
  final String message;
  final int? exitCode;
  final List<String> outputTail;
}
final class PlayStopped extends PlayEvent { final int exitCode; final bool requested; }

enum PlayOutputSource { game, tool, stderr }

class PlayStartException implements Exception {
  final String projectPath;
  final String message;
}

/// Masks VM service auth codes in [line]: `ws://127.0.0.1:1234/AbC=/ws`
/// becomes `ws://127.0.0.1:1234/<auth-code>=/ws` (§9.3, Q81).
String redactAuthCodes(String line);
```

Shapes are shown without constructors. Every event and value class is immutable, with `final`
fields and `const` constructors where possible (constitution I).

## Guarantees

- No `PlayEvent` and no exception message contains a VM service auth code (spec FR-021,
  research R5).
- `PlayReloading` is followed by exactly one `PlayReloaded` or `PlayReloadFailed`, unless
  `PlayStopped` comes first. Then the pending `reload()` future fails with a `StateError`
  naming the stopped session.
- Two reloads are never in flight together. A burst of Scene changes produces one reload after it
  settles, plus at most one already in flight (R8).
- After `PlayStopped`, no process the session started is running, as far as `Process` can tell.
  The manual check (quickstart §5) covers the macOS app itself.
- The client writes nothing in the project (spec FR-020). Tests check this on the injected
  `MemoryFileSystem`. The CLI's `--record` and the benchmark,
  which rewrites and restores the Scene, are the only callers that touch files.

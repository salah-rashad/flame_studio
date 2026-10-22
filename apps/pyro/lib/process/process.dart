/// Play: runs the developer's game with `flutter run --machine` and
/// Hot-swaps its Scenes when they are saved (project plan §9.3; spec 005).
///
/// [PlayClient.start] returns a [PlaySession], whose events report the game's
/// lifecycle and output with VM service auth codes masked. Nothing here
/// imports Flutter, so `bin/play.dart` runs it with `dart run`.
library;

export 'src/play_client.dart' show PlayClient, ProcessStarter;
export 'src/play_event.dart'
    show
        PlayDebuggerAvailable,
        PlayEvent,
        PlayFailed,
        PlayOutput,
        PlayOutputSource,
        PlayReloadFailed,
        PlayReloaded,
        PlayReloading,
        PlayStartException,
        PlayStarted,
        PlayStarting,
        PlayState,
        PlayStopped,
        ReloadResult;
export 'src/play_session.dart' show PlaySession;
export 'src/redact.dart' show redactAuthCodes;
export 'src/scene_watcher.dart' show DirectoryWatcher, watchRecursively;

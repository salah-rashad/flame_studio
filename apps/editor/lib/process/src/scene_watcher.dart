import 'dart:async';
import 'dart:io' show FileSystemEvent, FileSystemMoveEvent;

import 'package:file/file.dart';

/// Watches a directory and its subdirectories for changes.
typedef DirectoryWatcher =
    Stream<FileSystemEvent> Function(Directory directory);

/// `directory.watch(recursive: true)`: FSEvents on macOS.
Stream<FileSystemEvent> watchRecursively(Directory directory) =>
    directory.watch(recursive: true);

/// Turns changes to a project's `assets/scenes/**/*.scene.json` files into
/// batches of project-relative paths, one batch after each [quietPeriod]
/// without a change (spec 005, research R7, R8).
///
/// An atomic save (temp file, then rename) arrives as a move to the target,
/// so a move counts its destination. Editors' temp and swap files don't end
/// in `.scene.json` and are ignored.
final class SceneWatcher {
  /// Watches [projectPath]'s `assets/scenes/` with [watch] and calls
  /// [onChanges] with each batch. [onNote] explains, once, why nothing is
  /// watched (no folder) or watching stopped (an error from [watch]).
  SceneWatcher({
    required FileSystem fileSystem,
    required this._projectPath,
    required this._watch,
    required this._quietPeriod,
    required this._onChanges,
    required this._onNote,
  }) : _fs = fileSystem;

  final FileSystem _fs;
  final String _projectPath;
  final DirectoryWatcher _watch;
  final Duration _quietPeriod;
  final void Function(Set<String> paths) _onChanges;
  final void Function(String note) _onNote;
  final _pending = <String>{};
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _quiet;

  /// Starts watching, or notes that the project has no `assets/scenes/`.
  void start() {
    final scenes = _fs.directory(
      _fs.path.join(_projectPath, 'assets', 'scenes'),
    );
    if (!scenes.existsSync()) {
      _onNote(
        'No assets/scenes/ folder in $_projectPath, so saving a Scene '
        "won't Hot-swap it.",
      );
      return;
    }
    _subscription = _watch(scenes).listen(
      _onEvent,
      onError: (Object error) =>
          _onNote('Stopped watching ${scenes.path} for Scene changes: $error'),
    );
  }

  /// Stops watching; a batch still waiting for quiet is dropped. Nothing
  /// waits for the watch to wind down: no event is handled after this.
  void close() {
    _quiet?.cancel();
    _pending.clear();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _onEvent(FileSystemEvent event) {
    if (event.isDirectory) return;
    final path = event is FileSystemMoveEvent
        ? event.destination ?? event.path
        : event.path;
    final relative = _relativeScenePath(path);
    if (relative == null) return;
    _pending.add(relative);
    _quiet?.cancel();
    _quiet = Timer(_quietPeriod, _flush);
  }

  /// [path] relative to the project with `/` separators, or null unless it
  /// is a Scene file under `assets/scenes/`.
  String? _relativeScenePath(String path) {
    final context = _fs.path;
    final relative = context
        .split(context.relative(path, from: _projectPath))
        .join('/');
    if (!relative.startsWith('assets/scenes/')) return null;
    if (!relative.endsWith('.scene.json')) return null;
    return relative;
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final batch = Set.of(_pending);
    _pending.clear();
    _onChanges(batch);
  }
}

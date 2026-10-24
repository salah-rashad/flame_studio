/// The viewport's files (spec 006, FR-021, *Q31*, *Q79*): pyro_runtime's
/// `AssetSource` over the open project's folder, with a refcounted image
/// cache and a watcher that reports which read files changed.
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show FileSystemEvent, FileSystemMoveEvent;
import 'dart:ui' as ui;

import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:pyro/process/process.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// Decodes an encoded image.
typedef ImageDecoder = Future<ui.Image> Function(Uint8List bytes);

/// The engine's decoder. `instantiateImageCodec` decodes on the engine's IO
/// thread, so the UI isolate only awaits it; `dart:ui` can't run inside an
/// `Offload` worker isolate, and the file read is async I/O already
/// (constitution III).
Future<ui.Image> decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// How long file events wait for quiet before they are reported: short,
/// so a changed image reaches the screen within the ~200 ms budget
/// (SC-005).
const Duration assetQuietPeriod = Duration(milliseconds: 50);

/// One holder's claim on an image: the image stays alive until every
/// lease on it is released, even after its file changed (*Q79*).
final class ImageLease {
  ImageLease._(this._generation) : image = _generation.image!;

  final _Generation _generation;
  bool _released = false;

  /// The decoded image.
  final ui.Image image;

  /// Gives up the claim; the image is freed once it is stale and unleased.
  void release() {
    if (_released) return;
    _released = true;
    _generation.leases--;
    _generation.disposeIfDone();
  }
}

final class _Generation {
  _Generation(this.future);

  final Future<ui.Image> future;
  ui.Image? image;
  int leases = 0;
  bool stale = false;

  void disposeIfDone() {
    if (stale && leases == 0) {
      image?.dispose();
      image = null;
    }
  }
}

/// The `AssetSource` over a project folder on disk: paths are
/// project-relative (`assets/images/hero.png`), like the bundle a game
/// reads them from, so one Scene loads from the same paths in both.
final class DiskAssetSource implements AssetSource {
  /// Reads files under [root] through [fileSystem]; [watch] (FSEvents by
  /// default) reports changes, debounced by [quietPeriod].
  DiskAssetSource({
    required FileSystem fileSystem,
    required String root,
    DirectoryWatcher watch = watchRecursively,
    this._quietPeriod = assetQuietPeriod,
    this._decode = decodeImage,
  }) : _fs = fileSystem,
       _root = fileSystem.path.normalize(root) {
    final directory = fileSystem.directory(_root);
    if (directory.existsSync()) {
      // A watch that fails only stops live reloads.
      _watch = watch(directory).listen(
        _onEvent,
        onError: (Object error) => developer.log(
          'Watching "$_root" for image changes failed: $error',
          name: 'pyro.viewport',
        ),
        cancelOnError: false,
      );
    }
  }

  final FileSystem _fs;
  final String _root;
  final ImageDecoder _decode;
  final Duration _quietPeriod;
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _quiet;
  final Set<AssetPath> _pending = {};

  final Set<AssetPath> _read = {};
  final Map<AssetPath, _Generation> _images = {};
  final StreamController<Set<AssetPath>> _changes = StreamController.broadcast(
    sync: true,
  );

  /// Batches of read files that changed on disk. A listener rebuilds the
  /// components that recorded them ([AssetDependents]).
  Stream<Set<AssetPath>> get changes => _changes.stream;

  File _file(AssetPath path) =>
      _fs.file(_fs.path.joinAll([_root, ...path.split('/')]));

  @override
  Future<String> loadText(AssetPath path) {
    _read.add(path);
    return _file(path).readAsString();
  }

  /// The image at [path], unleased: it is freed as soon as its file
  /// changes. Preview components draw through [leaseImage] instead, which
  /// keeps an image until its last holder lets go (*Q79*).
  @override
  Future<ui.Image> loadImage(AssetPath path) => _generation(path).future;

  /// The image at [path] with a claim that keeps it alive until released.
  Future<ImageLease> leaseImage(AssetPath path) async {
    final generation = _generation(path);
    // Counted before the await, so an invalidation mid-decode can't free
    // the image under this lease.
    generation.leases++;
    try {
      await generation.future;
    } catch (_) {
      generation.leases--;
      rethrow;
    }
    return ImageLease._(generation);
  }

  _Generation _generation(AssetPath path) {
    _read.add(path);
    final current = _images[path];
    if (current != null) return current;
    late final _Generation generation;
    generation = _Generation(
      _load(path).then(
        (image) => generation.image = image,
        onError: (Object error, StackTrace stack) {
          // Not kept: the next load reads the file again.
          if (identical(_images[path], generation)) _images.remove(path);
          Error.throwWithStackTrace(error, stack);
        },
      ),
    );
    return _images[path] = generation;
  }

  Future<ui.Image> _load(AssetPath path) async =>
      _decode(await _file(path).readAsBytes());

  /// Forgets the cached images of [paths]; each is freed once nothing
  /// leases it, and the next load reads the file again.
  void invalidate(Set<AssetPath> paths) {
    for (final path in paths) {
      final generation = _images.remove(path);
      if (generation == null) continue;
      generation.stale = true;
      if (generation.image != null) {
        generation.disposeIfDone();
      } else {
        // Still decoding: free it when it lands, unless leased by then.
        generation.future.then((_) => generation.disposeIfDone()).ignore();
      }
    }
  }

  void _onEvent(FileSystemEvent event) {
    if (event.isDirectory) return;
    _note(event.path);
    if (event is FileSystemMoveEvent) _note(event.destination);
    if (_pending.isEmpty) return;
    _quiet?.cancel();
    _quiet = Timer(_quietPeriod, _flush);
  }

  void _note(String? absolute) {
    if (absolute == null) return;
    final path = _fs.path;
    final normalized = path.normalize(absolute);
    if (!path.isWithin(_root, normalized)) return;
    final relative = AssetPath(
      path.split(path.relative(normalized, from: _root)).join('/'),
    );
    if (_read.contains(relative)) _pending.add(relative);
  }

  void _flush() {
    final batch = {..._pending};
    _pending.clear();
    if (batch.isEmpty) return;
    // Marks the start of SC-005's ≤ 200 ms budget in the timeline.
    developer.Timeline.instantSync(
      'Pyro asset changed',
      arguments: {'paths': batch.join(', ')},
    );
    invalidate(batch);
    _changes.add(batch);
  }

  /// How many decoded images are alive.
  @visibleForTesting
  int get liveImages => _images.values.where((g) => g.image != null).length;

  /// Stops watching and frees every image nothing leases.
  void dispose() {
    _quiet?.cancel();
    unawaited(_watch?.cancel());
    invalidate({..._images.keys});
    unawaited(_changes.close());
  }
}

/// Which components read which files (the per-Node file records of
/// FR-021): a file change rebuilds only its dependents.
final class AssetDependents<T> {
  final Map<T, Set<AssetPath>> _paths = {};
  final Map<AssetPath, Set<T>> _dependents = {};

  /// Records that [dependent] reads exactly [paths] now.
  void record(T dependent, Set<AssetPath> paths) {
    forget(dependent);
    if (paths.isEmpty) return;
    _paths[dependent] = {...paths};
    for (final path in paths) {
      (_dependents[path] ??= {}).add(dependent);
    }
  }

  /// Drops [dependent]'s records.
  void forget(T dependent) {
    final paths = _paths.remove(dependent);
    if (paths == null) return;
    for (final path in paths) {
      final set = _dependents[path]!..remove(dependent);
      if (set.isEmpty) _dependents.remove(path);
    }
  }

  /// Drops every record.
  void clear() {
    _paths.clear();
    _dependents.clear();
  }

  /// The dependents reading any of [paths].
  Set<T> of(Set<AssetPath> paths) => {
    for (final path in paths) ...?_dependents[path],
  };
}

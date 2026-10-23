/// The Type catalog (FR-012–FR-014, `contracts/type-catalog.md`): the open
/// project's Manifest joined with the built-in descriptors, re-read whenever
/// `lib/pyro.manifest.json` changes on disk (FR-013).
library;

import 'dart:async';
import 'dart:io' show FileSystemEvent, FileSystemMoveEvent;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/providers.dart';
import 'package:pyro/process/process.dart';

import 'built_in.dart';
import 'manifest_parse.dart';

/// Where the Manifest lives, project-relative, `/`-separated.
const String manifestRelativePath = 'lib/pyro.manifest.json';

/// How long a Manifest write waits for quiet before it is read — the same
/// debounce the Scene watcher uses (spec 005, research R7).
const Duration manifestQuietPeriod = Duration(milliseconds: 100);

/// The file system the catalog reads the Manifest through; tests inject a
/// memory one.
final catalogFileSystemProvider = Provider<FileSystem>(
  (ref) => const LocalFileSystem(),
);

/// The Manifest watcher, so tests inject a stream they control; the app
/// uses `watchRecursively` (FSEvents on macOS).
final manifestWatchProvider = Provider<DirectoryWatcher>(
  (ref) => watchRecursively,
);

/// The project's types (FR-012): every panel reads this and nothing else —
/// the Add lists, the parenting rules, the inspector's field editors, the
/// viewport's placeholders.
final typeCatalogProvider = NotifierProvider<TypeCatalogNotifier, TypeCatalog>(
  TypeCatalogNotifier.new,
);

/// [typeCatalogProvider]'s notifier.
class TypeCatalogNotifier extends Notifier<TypeCatalog> {
  /// The Manifest's types of the last good read, kept active while a newer
  /// read refuses (*Q105*).
  IList<TypeDescriptor> _lastGood = const IList.empty();

  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _quiet;

  @override
  TypeCatalog build() {
    // Only the root matters: an SDK or compatibility recheck must not
    // throw away a good catalog.
    final root = ref.watch(projectProvider.select((project) => project?.root));
    _lastGood = const IList.empty();
    _stopWatching();
    ref.onDispose(_stopWatching);
    if (root == null) return _join(const IList.empty(), const ManifestAbsent());
    _startWatching(root);
    return _read(root);
  }

  void _startWatching(String root) {
    final fs = ref.read(catalogFileSystemProvider);
    final lib = fs.directory(fs.path.join(root, 'lib'));
    if (!lib.existsSync()) return;
    // A watch that fails (the folder went away) just stops the live
    // reload; opening a project again restarts it.
    _watch = ref
        .read(manifestWatchProvider)(lib)
        .listen((event) => _onEvent(root, event), onError: (Object _) {});
  }

  void _onEvent(String root, FileSystemEvent event) {
    if (event.isDirectory) return;
    final fs = ref.read(catalogFileSystemProvider);
    final path = event is FileSystemMoveEvent
        ? event.destination ?? event.path
        : event.path;
    final relative = fs.path
        .split(fs.path.relative(path, from: root))
        .join('/');
    if (relative != manifestRelativePath) return;
    _quiet?.cancel();
    _quiet = Timer(manifestQuietPeriod, () => _reload(root));
  }

  void _reload(String root) {
    // A batch from a previous project never overwrites the open one.
    if (ref.read(projectProvider)?.root != root) return;
    state = _read(root);
  }

  /// Reads the open project's Manifest. Every refusal keeps the last good
  /// types — the catalog is stale, never empty (*Q105*) — and Pyro never
  /// runs the generator to "fix" it (FR-013).
  TypeCatalog _read(String root) {
    final fs = ref.read(catalogFileSystemProvider);
    final file = fs.file(
      fs.path.joinAll([root, ...manifestRelativePath.split('/')]),
    );
    if (!file.existsSync()) {
      _lastGood = const IList.empty();
      return _join(const IList.empty(), const ManifestAbsent());
    }
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException catch (error) {
      return _stale('the Manifest file could not be read: ${error.message}');
    } on FormatException {
      return _stale('the Manifest file is not valid UTF-8');
    }
    switch (readManifest(text)) {
      case ManifestParsed(:final types, :final problems):
        _lastGood = types;
        return _join(types, const ManifestUpToDate(), problems);
      case ManifestFailed(:final problems):
        return _stale('the Manifest build failed with errors', problems);
      case ManifestUnreadable(:final message):
        return _stale('the Manifest is unreadable: $message');
      case ManifestNewer(:final manifestVersion):
        return _stale(
          'the Manifest needs a newer Pyro (manifestVersion $manifestVersion)',
        );
    }
  }

  TypeCatalog _stale(String reason, [IList<ManifestProblem>? problems]) =>
      _join(_lastGood, ManifestStale(reason), problems);

  /// The [manifestTypes] (or the last good ones) joined with the
  /// built-ins, which win over a Manifest type of the same Type ID: the
  /// engine kinds are never the user's to redefine.
  TypeCatalog _join(
    IList<TypeDescriptor> manifestTypes,
    ManifestOrigin origin, [
    IList<ManifestProblem>? problems,
  ]) => TypeCatalog(
    types: IMap({
      for (final type in manifestTypes) type.id: type,
      for (final type in builtInTypes) type.id: type,
    }),
    problems: problems ?? const IList.empty(),
    origin: origin,
  );

  void _stopWatching() {
    _quiet?.cancel();
    _quiet = null;
    unawaited(_watch?.cancel());
    _watch = null;
  }
}

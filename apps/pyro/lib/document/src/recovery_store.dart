import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:pyro_runtime/pyro_runtime.dart';

import 'atomic_write.dart';
import 'errors.dart';
import 'history.dart';
import 'offload.dart';
import 'open_document.dart';
import 'scene_document.dart';

part 'recovery_store.freezed.dart';

/// A readable recovery copy (spec 002, FR-028).
@freezed
abstract class RecoveryInfo with _$RecoveryInfo {
  /// Creates the description of a copy.
  const factory RecoveryInfo({
    /// The project the Scene belongs to.
    required String projectRoot,

    /// The Scene file the copy is of.
    required String scenePath,

    /// When the copy was written (UTC).
    required DateTime writtenAt,

    /// When the Scene file itself was last written, or null if it's gone.
    required DateTime? sceneFileModifiedAt,

    /// The copy's file-name key.
    required String key,
  }) = _RecoveryInfo;
}

/// What [RecoveryStore.find] found for a Scene.
sealed class RecoveryCheck {
  const RecoveryCheck();
}

/// No recovery copy.
final class NoRecovery extends RecoveryCheck {
  const NoRecovery();
}

/// A complete, readable copy; the editor offers *Restore*.
final class RecoveryAvailable extends RecoveryCheck {
  const RecoveryAvailable(this.info);

  /// The copy.
  final RecoveryInfo info;
}

/// A copy that can't be used. It is kept until pruned and reported with
/// where it is (FR-029).
final class RecoveryUnreadable extends RecoveryCheck {
  const RecoveryUnreadable(this.location, this.problem);

  /// The copy's files, without the extensions.
  final String location;

  /// Why it can't be used.
  final Object problem;
}

/// Recovery copies of documents with unsaved changes, in a folder outside
/// every project (spec 002, FR-024 to FR-029; contracts/recovery-copies.md).
final class RecoveryStore {
  /// Creates the store in the folder at [folder] on [fileSystem]; the folder
  /// is created on the first write.
  RecoveryStore({
    required String folder,
    this.fileSystem = const LocalFileSystem(),
    this.offload = Isolate.run,
  }) : folder = fileSystem.directory(folder);

  /// Where the copies live.
  final Directory folder;

  /// The file system [folder] is on.
  final FileSystem fileSystem;

  /// Runs encoding, decoding and hashing off the UI isolate.
  final Offload offload;

  /// How old a copy may get before [find] deletes it (FR-025a).
  static const Duration maxAge = Duration(days: 30);

  static const int _formatVersion = 1;

  FileSystem get _fs => fileSystem;

  /// The file-name key of the copy for [scenePath] in [projectRoot]: the hex
  /// SHA-256 of both paths, normalized, joined by a line break.
  static String keyFor(String projectRoot, String scenePath) => sha256
      .convert(
        utf8.encode('${p.normalize(projectRoot)}\n${p.normalize(scenePath)}'),
      )
      .toString();

  /// Deletes copies older than [maxAge], then reports the copy for
  /// [scenePath], if any.
  Future<RecoveryCheck> find({
    required String projectRoot,
    required String scenePath,
  }) async {
    await _prune();
    final key = keyFor(projectRoot, scenePath);
    final scene = _sceneFile(key);
    final meta = _metadataFile(key);
    final hasScene = scene.existsSync();
    final hasMeta = meta.existsSync();
    if (!hasScene && !hasMeta) return const NoRecovery();
    final location = _fs.path.join(folder.path, key);
    if (!hasScene || !hasMeta) {
      return RecoveryUnreadable(
        location,
        'only the ${hasScene ? 'Scene copy' : 'metadata'} exists',
      );
    }
    try {
      final (:projectRoot, :scenePath, :writtenAt) = _readMetadata(
        await meta.readAsString(),
      );
      if (keyFor(projectRoot, scenePath) != key) {
        return RecoveryUnreadable(
          location,
          'the metadata names another Scene: "$scenePath"',
        );
      }
      final bytes = await scene.readAsBytes();
      await _checkOff(offload, bytes);
      final sceneFile = _fs.file(scenePath);
      return RecoveryAvailable(
        RecoveryInfo(
          projectRoot: projectRoot,
          scenePath: scenePath,
          writtenAt: writtenAt,
          sceneFileModifiedAt: sceneFile.existsSync()
              ? sceneFile.lastModifiedSync()
              : null,
          key: key,
        ),
      );
    } on Exception catch (error) {
      return RecoveryUnreadable(location, error);
    }
  }

  /// Deletes the copy for [scenePath]; a missing copy is fine.
  Future<void> discard({
    required String projectRoot,
    required String scenePath,
  }) => _discardKey(keyFor(projectRoot, scenePath));

  Future<void> _discardKey(String key) async {
    for (final file in [_sceneFile(key), _metadataFile(key)]) {
      if (file.existsSync()) await file.delete();
    }
  }

  Future<void> _prune() async {
    if (!folder.existsSync()) return;
    final now = clock.now();
    final keys = <String>{
      for (final entity in folder.listSync())
        if (entity is File) ?_keyOf(_fs.path.basename(entity.path)),
    };
    for (final key in keys) {
      if (now.difference(_age(key)) > maxAge) await _discardKey(key);
    }
  }

  // When the copy [key] was written: its metadata's time, or the newer of
  // its files' modification times when the metadata can't be read.
  DateTime _age(String key) {
    final meta = _metadataFile(key);
    try {
      return _readMetadata(meta.readAsStringSync()).writtenAt;
    } on Exception {
      final times = [
        for (final file in [_sceneFile(key), meta])
          if (file.existsSync()) file.lastModifiedSync(),
      ];
      return times.reduce((a, b) => a.isAfter(b) ? a : b);
    }
  }

  static String? _keyOf(String name) {
    for (final suffix in ['.scene.json', '.recovery.json']) {
      if (name.endsWith(suffix) && !name.startsWith('.')) {
        return name.substring(0, name.length - suffix.length);
      }
    }
    return null;
  }

  File _sceneFile(String key) =>
      _fs.file(_fs.path.join(folder.path, '$key.scene.json'));

  File _metadataFile(String key) =>
      _fs.file(_fs.path.join(folder.path, '$key.recovery.json'));

  static ({String projectRoot, String scenePath, DateTime writtenAt})
  _readMetadata(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) {
      throw const FormatException('the metadata isn\'t a JSON object');
    }
    final version = json['formatVersion'];
    if (version != _formatVersion) {
      throw FormatException(
        'metadata format $version; this Pyro reads $_formatVersion',
      );
    }
    final projectRoot = json['projectRoot'];
    final scenePath = json['scenePath'];
    final writtenAt = json['writtenAt'];
    if (projectRoot is! String ||
        scenePath is! String ||
        writtenAt is! String) {
      throw const FormatException('the metadata misses a path or a time');
    }
    return (
      projectRoot: projectRoot,
      scenePath: scenePath,
      writtenAt: DateTime.parse(writtenAt),
    );
  }

  // Static, so the closures sent to another isolate capture only their
  // arguments.
  static Future<void> _checkOff(Offload offload, Uint8List bytes) =>
      offload(() => SceneCodec.decode(utf8.decode(bytes)));

  static Future<Uint8List> _encodeOff(Offload offload, SceneDocument state) =>
      offload(() => utf8.encode(SceneCodec.encode(state.toScene())));

  static Future<(SceneDocument, Digest?)> _restoreOff(
    Offload offload,
    Uint8List copy,
    Uint8List? sceneFile,
  ) => offload(
    () => (
      SceneDocument.fromScene(SceneCodec.decode(utf8.decode(copy)).scene),
      sceneFile == null ? null : sha256.convert(sceneFile),
    ),
  );
}

/// The store's operations for `DocumentSession` and its recovery timer; not
/// exported from the Document library.
extension RecoveryWriting on RecoveryStore {
  /// Writes a copy of [state] for [scenePath]: the Scene first, then its
  /// metadata, each atomically. Throws [RecoveryWriteFailed].
  Future<void> write({
    required String projectRoot,
    required String scenePath,
    required SceneDocument state,
  }) async {
    final key = RecoveryStore.keyFor(projectRoot, scenePath);
    try {
      if (!folder.existsSync()) await folder.create(recursive: true);
      final bytes = await RecoveryStore._encodeOff(offload, state);
      await writeAtomically(_fs, _sceneFile(key).path, bytes);
      final meta = const JsonEncoder.withIndent('  ').convert({
        'formatVersion': RecoveryStore._formatVersion,
        'projectRoot': p.normalize(projectRoot),
        'scenePath': p.normalize(scenePath),
        'writtenAt': clock.now().toUtc().toIso8601String(),
      });
      await writeAtomically(
        _fs,
        _metadataFile(key).path,
        utf8.encode('$meta\n'),
      );
    } on FileSystemException catch (error) {
      throw RecoveryWriteFailed(_fs.path.join(folder.path, key), error);
    }
  }

  /// The document restored from the copy [info]: dirty, with an empty
  /// history, saving to the Scene's own path, checked on save against the
  /// Scene file as it is now (FR-028).
  Future<OpenDocument> readCopy(RecoveryInfo info) async {
    final copy = await _sceneFile(info.key).readAsBytes();
    final sceneFile = _fs.file(info.scenePath);
    final current = sceneFile.existsSync()
        ? await sceneFile.readAsBytes()
        : null;
    final (state, baseline) = await RecoveryStore._restoreOff(
      offload,
      copy,
      current,
    );
    return OpenDocument(
      history: DocumentHistory.opened(state, clean: false),
      path: info.scenePath,
      baseline: baseline,
      origin: OpenedFrom.restored,
    );
  }
}

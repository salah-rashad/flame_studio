import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'atomic_write.dart';
import 'errors.dart';
import 'history.dart';
import 'offload.dart';
import 'open_document.dart';
import 'scene_document.dart';

/// Reads and writes Scene files for documents (spec 002, FR-017 to FR-023;
/// research R7 to R9, R14).
final class SceneFiles {
  /// Creates the reader and writer over [fileSystem]; [offload] runs the
  /// codec off the UI isolate.
  SceneFiles({
    this.fileSystem = const LocalFileSystem(),
    this.offload = Isolate.run,
  });

  /// Where Scene files are read and written.
  final FileSystem fileSystem;

  /// Runs decoding, encoding and hashing off the UI isolate.
  final Offload offload;

  /// Reads the Scene file at [path] into a document.
  ///
  /// The document is clean, or dirty with its repair report when the tree had
  /// to be repaired (FR-016). Throws [SceneOpenFailed] naming [path] and the
  /// cause. Never writes.
  Future<OpenDocument> open(String path) async {
    final Uint8List bytes;
    try {
      bytes = await fileSystem.file(path).readAsBytes();
    } on FileSystemException catch (error) {
      throw SceneOpenFailed(path, error);
    }
    final _Decoded decoded;
    try {
      decoded = await _decodeOff(offload, bytes);
    } on SceneFormatException catch (error) {
      throw SceneOpenFailed(path, error);
    } on FormatException catch (error) {
      throw SceneOpenFailed(path, error);
    }
    final repaired = !decoded.repairs.isEmpty;
    return OpenDocument(
      history: DocumentHistory.opened(decoded.state, clean: !repaired),
      path: path,
      baseline: decoded.digest,
      origin: repaired ? OpenedFrom.repaired : OpenedFrom.file,
      repairs: decoded.repairs,
    );
  }

  /// Writes [document]'s current state to its path, or to [saveAs].
  ///
  /// [runtimeReadsUpTo] is the newest `schemaVersion` the project's Runtime
  /// reads, from the compatibility check (*Q49*). Refuses with a
  /// [SaveRefused] case, before anything is read or written, when it is
  /// unknown ([RuntimeVersionUnknown]) or older than the version Pyro writes
  /// ([RuntimeTooOld]) (FR-022); when there is no path ([SavePathRequired]), when the document's own file
  /// changed on disk since it was opened or saved ([SceneChangedOnDisk]), or
  /// when [saveAs] names another existing file ([SaveTargetExists]); the last
  /// two are skipped when [overwrite] is true (FR-019a). Then writes
  /// atomically (FR-019); a failed write throws [SaveFailed]. Returns what was
  /// written, to apply with [OpenDocument.markSaved].
  Future<SaveResult> save(
    OpenDocument document, {
    required int? runtimeReadsUpTo,
    String? saveAs,
    bool overwrite = false,
  }) async {
    final named = saveAs ?? document.path;
    if (runtimeReadsUpTo == null) throw RuntimeVersionUnknown(named);
    if (runtimeReadsUpTo < Scene.currentSchemaVersion) {
      throw RuntimeTooOld(
        named,
        reads: runtimeReadsUpTo,
        writes: Scene.currentSchemaVersion,
      );
    }
    final target = named ?? (throw const SavePathRequired());
    final ownFile =
        document.path != null && fileSystem.path.equals(target, document.path!);
    Uint8List? onDisk;
    if (ownFile && !overwrite) {
      onDisk = await _readIfPresent(target);
    } else if (!ownFile && !overwrite && fileSystem.file(target).existsSync()) {
      throw SaveTargetExists(target);
    }
    final state = document.state;
    final encoded = await _encodeOff(offload, state, onDisk);
    if (ownFile && !overwrite && encoded.onDiskDigest != document.baseline) {
      throw SceneChangedOnDisk(target);
    }
    try {
      await writeAtomically(fileSystem, target, encoded.bytes);
    } on FileSystemException catch (error) {
      throw SaveFailed(target, error);
    }
    return SaveResult(state: state, path: target, digest: encoded.digest);
  }

  Future<Uint8List?> _readIfPresent(String path) async {
    final file = fileSystem.file(path);
    if (!file.existsSync()) return null;
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (error) {
      throw SaveFailed(path, error);
    }
  }

  // Static, so the closures sent to another isolate capture only their
  // arguments.
  static Future<_Decoded> _decodeOff(Offload offload, Uint8List bytes) =>
      offload(() => _decode(bytes));

  static Future<_Encoded> _encodeOff(
    Offload offload,
    SceneDocument state,
    Uint8List? onDisk,
  ) => offload(() => _encode(state, onDisk));
}

/// What [SceneFiles.open] needs back from the codec.
typedef _Decoded = ({SceneDocument state, RepairReport repairs, Digest digest});

/// What [SceneFiles.save] needs back from the codec.
typedef _Encoded = ({Uint8List bytes, Digest digest, Digest? onDiskDigest});

_Decoded _decode(Uint8List bytes) {
  final result = SceneCodec.decode(utf8.decode(bytes));
  return (
    state: SceneDocument.fromScene(result.scene),
    repairs: result.repairs,
    digest: sha256.convert(bytes),
  );
}

_Encoded _encode(SceneDocument state, Uint8List? onDisk) {
  final bytes = utf8.encode(SceneCodec.encode(state.toScene()));
  return (
    bytes: bytes,
    digest: sha256.convert(bytes),
    onDiskDigest: onDisk == null ? null : sha256.convert(onDisk),
  );
}

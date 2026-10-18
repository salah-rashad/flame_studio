import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'errors.dart';
import 'history.dart';
import 'node_ids.dart';
import 'scene_document.dart';

part 'open_document.freezed.dart';

/// How an open document came to be, for the editor's messages.
enum OpenedFrom {
  /// Read from its Scene file unchanged.
  file,

  /// Read from a Scene file whose tree had to be repaired (FR-016).
  repaired,

  /// Restored from a recovery copy (FR-028).
  restored,

  /// Created as a new, unsaved Scene (FR-021).
  created,
}

/// What a save wrote, applied to the session with [OpenDocument.markSaved]
/// (FR-020).
@freezed
abstract class SaveResult with _$SaveResult {
  /// Creates a result.
  const factory SaveResult({
    /// The state that was written.
    required SceneDocument state,

    /// Where it was written.
    required String path,

    /// The SHA-256 of the bytes written.
    required Digest digest,
  }) = _SaveResult;
}

/// One open Scene as a value: its history, file and repair report
/// (spec 002, data model).
///
/// Identity equality, like [DocumentHistory]. Callers change a session's
/// document only through `DocumentSession.transact`.
final class OpenDocument {
  /// Creates an open document; `SceneFiles`, `RecoveryStore` and
  /// [createDocument] call this.
  OpenDocument({
    required this.history,
    required this.path,
    required this.baseline,
    required this.origin,
    RepairReport? repairs,
  }) : repairs = repairs ?? RepairReport.empty;

  /// The undo history; its current entry is [state].
  final DocumentHistory history;

  /// The Scene file's absolute path, or null for a new Scene.
  final String? path;

  /// The SHA-256 of the Scene file's bytes as last read, written or (when
  /// restored) found; null for a new Scene (FR-019a).
  final Digest? baseline;

  /// The repairs made while reading the file; empty otherwise.
  final RepairReport repairs;

  /// How the document came to be.
  final OpenedFrom origin;

  /// The current state.
  SceneDocument get state => history.current;

  /// Whether there are unsaved changes.
  bool get isDirty => history.isDirty;

  /// The document after [edit], named [label] (FR-006, FR-008).
  ///
  /// Throws [TransactionFailed] when [edit] throws a [DocumentEditError];
  /// other errors propagate. Either way this document is unchanged.
  OpenDocument transact(
    String label,
    SceneDocument Function(SceneDocument doc) edit, {
    Object? coalesceKey,
  }) {
    final SceneDocument next;
    try {
      next = edit(state);
    } on DocumentEditError catch (error) {
      throw TransactionFailed(label, error);
    }
    return _withHistory(history.apply(label, next, coalesceKey: coalesceKey));
  }

  /// The document one step back.
  OpenDocument undo() => _withHistory(history.undo());

  /// The document one step forward.
  OpenDocument redo() => _withHistory(history.redo());

  /// The document after [result] was written; edits made since the save
  /// started stay unsaved.
  OpenDocument markSaved(SaveResult result) => OpenDocument(
    history: history.markSaved(result.state),
    path: result.path,
    baseline: result.digest,
    origin: origin,
  );

  OpenDocument _withHistory(DocumentHistory next) => identical(next, history)
      ? this
      : OpenDocument(
          history: next,
          path: path,
          baseline: baseline,
          origin: origin,
          repairs: repairs,
        );
}

/// A new, unsaved Scene holding only a root Node; clean (FR-021).
OpenDocument createDocument({NodeIdSource newId = uuidNodeIds}) {
  final rootId = newId();
  final scene = Scene(
    rootId: rootId,
    nodes: {rootId: RootNode(id: rootId)},
  );
  return OpenDocument(
    history: DocumentHistory.opened(
      SceneDocument.fromScene(scene),
      clean: true,
    ),
    path: null,
    baseline: null,
    origin: OpenedFrom.created,
  );
}

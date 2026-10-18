# Contract: Document API

What `package:pyro/document/document.dart` exports. The callers are #1 (the editor window, scene
tabs, the *Restore* prompt and `documentProvider(sceneId)`) and the Phase 4 panels. Types are
described in [data-model.md](../data-model.md). Signatures are the shape, not final code.

## Opening, creating and restoring

```dart
/// Reads and writes Scene files for documents (research R7–R9, R14).
final class SceneFiles {
  SceneFiles({FileSystem fileSystem = const LocalFileSystem()});

  /// Reads [path] and decodes it off the UI isolate.
  ///
  /// Throws [SceneOpenFailed] naming [path] and the cause. Never writes.
  Future<OpenDocument> open(String path);

  /// Writes [document]'s current state to its path, or to [saveAs].
  ///
  /// Checks, in order and before touching the disk: [runtimeReadsUpTo] (FR-022),
  /// a path, the changed-on-disk baseline or an existing target unless [overwrite]
  /// (FR-019a). Then writes atomically (FR-019). Throws a [SaveRefused] case or
  /// [SaveFailed]; on success returns what was written.
  Future<SaveResult> save(
    OpenDocument document, {
    required int? runtimeReadsUpTo,
    String? saveAs,
    bool overwrite = false,
  });
}

/// A new, unsaved Scene holding only a root Node (FR-021). Clean.
OpenDocument createDocument({NodeIdSource newId = uuidNodeIds});
```

## One open Scene

```dart
/// One open Scene: its state, history, saves and recovery copy (research R13).
final class DocumentSession {
  /// Opens [path]. The caller checks [RecoveryStore.find] first and calls
  /// [restore] instead when the developer accepts *Restore*.
  static Future<DocumentSession> open(String path, {required SessionServices services});
  static DocumentSession create({required SessionServices services});
  static Future<DocumentSession> restore(RecoveryInfo copy, {required SessionServices services});

  OpenDocument get state;

  /// Every new state, synchronously, in order (a broadcast stream). #1's
  /// documentProvider mirrors it; the reconciler (§8.3) listens to every step.
  Stream<OpenDocument> get changes;

  /// Problems that don't stop editing, such as a failed recovery write.
  Stream<Object> get errors;

  /// The only way to change the Scene (FR-006). Throws [TransactionFailed]
  /// and leaves the state unchanged when [edit] throws a [DocumentEditError].
  void transact(
    String label,
    SceneDocument Function(SceneDocument doc) edit, {
    Object? coalesceKey,
  });

  void undo();
  void redo();

  /// Saves (or saves as); queued behind any running save. Removes the
  /// recovery copy on success (FR-027). Throws what [SceneFiles.save] throws.
  Future<void> save({required int? runtimeReadsUpTo, String? saveAs, bool overwrite = false});

  /// Removes the recovery copy and closes, dropping unsaved changes.
  Future<void> discardAndClose();

  /// Closes a clean session. Throws [StateError] if it has unsaved changes.
  Future<void> close();
}

/// What a session needs from the outside world, so tests can fake each one.
final class SessionServices {
  SessionServices({
    required SceneFiles files,
    required RecoveryStore recovery,
    required String projectRoot,
    Duration recoveryInterval = const Duration(seconds: 30),
    NodeIdSource newId = uuidNodeIds,
  });
}
```

Time comes from `package:clock`'s zone clock, and the recovery timer from `Timer.periodic`, so
`fake_async` drives both in tests.

## State and edits

```dart
@Freezed(equal: false)
abstract class SceneDocument with _$SceneDocument {
  NodeId get rootId;
  IMap<NodeId, Node> get nodes;
  IMap<NodeId, NodeId> get parents;
  Map<String, Object?> get sceneExtra;

  factory SceneDocument.fromScene(Scene scene);
  Scene toScene();

  Node? node(NodeId id);
  NodeId? parentOf(NodeId id);
  List<NodeId> childrenOf(NodeId id);
  bool isAncestor(NodeId ancestor, NodeId id);

  SceneDocument addNode(Node node, {required NodeId parentId, int? index});
  SceneDocument removeNode(NodeId id);
  SceneDocument moveNode(NodeId id, {required NodeId parentId, int? index});
  SceneDocument replaceNode(Node node);
}

final class OpenDocument {
  DocumentHistory get history;
  SceneDocument get state;
  String? get path;
  RepairReport get repairs;
  OpenedFrom get origin;
  bool get isDirty;
}

final class DocumentHistory {
  SceneDocument get current;
  bool get isDirty;
  bool get canUndo;
  bool get canRedo;
  String? get undoLabel;
  String? get redoLabel;
}

/// Makes a new, unique Node ID (UUID v4 by default, *Q14*).
typedef NodeIdSource = NodeId Function();
NodeId uuidNodeIds();
```

A typical panel call (Phase 4):

```dart
session.transact(
  'Move 3 Nodes',
  (doc) => ids.fold(doc, (d, id) => d.replaceNode(moved(d.node(id)!, delta))),
  coalesceKey: ('move', gestureId),
);
```

## Recovery

```dart
/// Recovery copies in a folder outside the project (contracts/recovery-copies.md).
final class RecoveryStore {
  RecoveryStore({required Directory folder, FileSystem fileSystem = const LocalFileSystem()});

  /// Prunes copies older than 30 days (FR-025a), then reports the copy for
  /// [scenePath], if any.
  Future<RecoveryCheck> find({required String projectRoot, required String scenePath});

  /// Deletes the copy for [scenePath] (declined *Restore*, a save, a discard).
  Future<void> discard({required String projectRoot, required String scenePath});
}
```

`write` and `readCopy` are internal; `DocumentSession` and its `RecoveryTimer` use them.

## Errors

Exported: `DocumentEditError` and its cases, `TransactionFailed`, `SceneOpenFailed`,
`SaveRefused` and its cases, `SaveFailed`, `RecoveryWriteFailed`. See
[data-model.md](../data-model.md#errors).

## Not exported

`DocumentHistory`'s constructor and `apply`, `OpenDocument`'s constructor, the atomic writer,
`RecoveryTimer`, and the `childIds` helper stay in `lib/document/src/`: callers change a
document only through `DocumentSession.transact`.

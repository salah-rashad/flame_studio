import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/document.dart';
import '../project/project.dart';

/// The snapshot view of one open document (spec 006, research §2).
///
/// The mutable `DocumentSession` is never provider state; this immutable
/// view is, so Riverpod's `==` filtering hides nothing and notifies only
/// real steps.
class DocumentView {
  /// Creates the view of [document].
  const DocumentView({
    required this.document,
    required this.isDirty,
    required this.path,
    required this.origin,
    required this.repairs,
    required this.canUndo,
    required this.canRedo,
  });

  /// The current document state.
  final SceneDocument document;

  /// Whether there are unsaved changes (FR-006: by identity, exactly as
  /// the Document model defines it).
  final bool isDirty;

  /// The Scene file's path, or null for an untitled Scene.
  final String? path;

  /// How the document came to be.
  final OpenedFrom origin;

  /// The repairs made while reading the file, for the repair report.
  final RepairReport repairs;

  /// Whether there is an undo step.
  final bool canUndo;

  /// Whether there is a redo step.
  final bool canRedo;

  /// The view of [state].
  factory DocumentView.of(OpenDocument state) => DocumentView(
    document: state.state,
    isDirty: state.isDirty,
    path: state.path,
    origin: state.origin,
    repairs: state.repairs,
    canUndo: state.history.canUndo,
    canRedo: state.history.canRedo,
  );

  @override
  bool operator ==(Object other) =>
      other is DocumentView &&
      identical(other.document, document) &&
      other.isDirty == isDirty &&
      other.path == path &&
      other.origin == origin &&
      other.repairs == repairs &&
      other.canUndo == canUndo &&
      other.canRedo == canRedo;

  @override
  int get hashCode =>
      Object.hash(document, isDirty, path, origin, repairs, canUndo, canRedo);
}

/// One open Scene in the tab strip (spec 006, data model).
class OpenScene {
  /// Creates the tab's data. [sceneId] is the provider family key: the
  /// canonical path once saved, a stable id until then.
  const OpenScene({
    required this.sceneId,
    required this.path,
    required this.displayName,
  });

  /// The provider family key.
  final String sceneId;

  /// The Scene file's path, or null for an untitled Scene.
  final String? path;

  /// The tab's title.
  final String displayName;

  /// This scene with a new [path] and [displayName] after a save.
  OpenScene savedAs(String newPath, String newName) => OpenScene(
    sceneId: newPath,
    path: newPath,
    displayName: newName,
  );
}

/// The tab strip's model (spec 006, data model).
class OpenScenesState {
  /// Creates the state; [active] names the focused tab, when there is one.
  const OpenScenesState({required this.scenes, this.active});

  /// The open Scenes, in tab order.
  final IList<OpenScene> scenes;

  /// The active tab's sceneId, or null (empty state).
  final String? active;

  /// The state with [scene] opened: appended, or focused when its
  /// sceneId is already open (one document per Scene file).
  OpenScenesState open(OpenScene scene) {
    if (scenes.any((s) => s.sceneId == scene.sceneId)) {
      return OpenScenesState(scenes: scenes, active: scene.sceneId);
    }
    return OpenScenesState(
      scenes: scenes.add(scene),
      active: scene.sceneId,
    );
  }

  /// The state with [sceneId] closed; the neighbour to its left becomes
  /// active (Flame's tab convention).
  OpenScenesState close(String sceneId) {
    final index = scenes.indexWhere((s) => s.sceneId == sceneId);
    if (index < 0) return this;
    final next = scenes.removeAt(index);
    final neighbours = scenes;
    final nextActive =
        neighbours.isEmpty
        ? null
        : (index < neighbours.length
              ? neighbours[index].sceneId
              : neighbours.last.sceneId);
    return OpenScenesState(scenes: next, active: active == sceneId
        ? nextActive
        : active);
  }

  /// The state with [sceneId] focused.
  OpenScenesState focus(String sceneId) =>
      scenes.any((s) => s.sceneId == sceneId)
      ? OpenScenesState(scenes: scenes, active: sceneId)
      : this;

  /// The state with [old] replaced by [updated] after a first save.
  OpenScenesState renamed(OpenScene old, OpenScene updated) =>
      OpenScenesState(
        scenes: IList([
          for (final s in scenes)
            if (s.sceneId == old.sceneId) updated else s,
        ]),
        active: active == old.sceneId ? updated.sceneId : active,
      );
}

/// The open project (FR-001): its root, the detected SDK and the Runtime
/// compatibility result. One project is open at a time.
class ProjectState {
  /// Creates the state of an open project.
  const ProjectState({
    required this.root,
    required this.sdk,
    required this.compatibility,
  });

  /// The project's root folder, absolute.
  final String root;

  /// The detected Flutter SDK (§9.1); `none` never blocks editing.
  final SdkInfo sdk;

  /// The Runtime compatibility check's result (FR-004).
  final RuntimeCompatibility compatibility;
}

/// The open project (keepAlive); null when only the project list is up.
final projectProvider = NotifierProvider<ProjectNotifier, ProjectState?>(
  ProjectNotifier.new,
);

/// [projectProvider]'s notifier.
class ProjectNotifier extends Notifier<ProjectState?> {
  @override
  ProjectState? build() => null;

  /// Opens the project at [root] with its [sdk] and Runtime
  /// [compatibility] results.
  void open(ProjectState project) => state = project;

  /// Closes the project (the project list is up again).
  void close() => state = null;
}

/// The tab strip: one entry per open Scene (FR-006).
final openScenesProvider =
    NotifierProvider<OpenScenesNotifier, OpenScenesState>(
      OpenScenesNotifier.new,
    );

/// [openScenesProvider]'s notifier.
class OpenScenesNotifier extends Notifier<OpenScenesState> {
  @override
  OpenScenesState build() =>
      const OpenScenesState(scenes: IList<OpenScene>.empty());

  /// Opens (or focuses) [scene].
  void open(OpenScene scene) => state = state.open(scene);

  /// Focuses [sceneId]'s tab.
  void focus(String sceneId) => state = state.focus(sceneId);

  /// Removes [sceneId]'s tab.
  void close(String sceneId) => state = state.close(sceneId);

  /// Replaces [old] with [updated] after a first save renamed the Scene.
  void renamed(OpenScene old, OpenScene updated) =>
      state = state.renamed(old, updated);
}

/// The sessions behind open documents, keyed by sceneId. Written by the
/// open-scene command before `documentProvider(sceneId)` is first read;
/// not part of the app's public surface.
final sessionRegistryProvider =
    NotifierProvider<SessionRegistry, Map<String, DocumentSession>>(
      SessionRegistry.new,
    );

/// [sessionRegistryProvider]'s notifier.
class SessionRegistry extends Notifier<Map<String, DocumentSession>> {
  @override
  Map<String, DocumentSession> build() => const {};

  /// Registers [session] under [sceneId].
  void register(String sceneId, DocumentSession session) =>
      state = {...state, sceneId: session};

  /// Drops the entry for [sceneId] (the session is already closed).
  void forget(String sceneId) {
    final next = Map.of(state)..remove(sceneId);
    state = next;
  }
}

/// One open document per scene (FR-002): the family Notifier owning its
/// `DocumentSession` privately. Every change from any panel goes through
/// its [DocumentNotifier.transact]; mutations never touch the session
/// directly. AutoDispose closes the session when the last listener and
/// every `KeepAliveLink` are gone (research §2).
final documentProvider =
    NotifierProvider.autoDispose
        .family<DocumentNotifier, DocumentView, String>(DocumentNotifier.new);

/// [documentProvider]'s notifier; created per sceneId by the family.
class DocumentNotifier extends Notifier<DocumentView> {
  /// Creates the notifier for [sceneId].
  DocumentNotifier(this.sceneId);

  /// The family argument, the scene's provider key.
  final String sceneId;

  StreamSubscription<OpenDocument>? _subscription;
  DocumentSession? _session;

  @override
  DocumentView build() {
    final sceneId = this.sceneId;
    final session = ref.read(sessionRegistryProvider)[sceneId];
    if (session == null) {
      throw StateError('No session registered for scene "$sceneId"');
    }
    _session = session;
    // A listener in a provider keeps this provider alive exactly while the
    // viewport's reconciler provider does (research §2).
    _subscription = session.changes.listen((state) {
      this.state = DocumentView.of(state);
    });
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      final s = _session;
      if (s != null && !s.isClosed) {
        // Last resort: the close flows in scene_tabs close the session
        // through the unsaved-changes dialog before the last link goes;
        // reaching here still open means the container itself is going
        // down.
        unawaited(
          s.state.isDirty ? s.discardAndClose() : s.close(),
        );
      }
    });
    return DocumentView.of(session.state);
  }

  /// The session, for the open-scene command's restore and the save flow.
  DocumentSession get session {
    if (_session == null || _session!.isClosed) {
      throw StateError('Scene "$sceneId" is closed');
    }
    return _session!;
  }

  /// Changes the Scene by [edit], named [label] (FR-002).
  void transact(
    String label,
    SceneDocument Function(SceneDocument doc) edit, {
    Object? coalesceKey,
  }) => session.transact(label, edit, coalesceKey: coalesceKey);

  /// Undoes one step.
  void undo() => session.undo();

  /// Redoes one step.
  void redo() => session.redo();
}

/// The selected Node of one scene (FR-011): editor state outside the
/// document (*Q25*), single-selection this phase.
final selectionProvider =
    NotifierProvider.autoDispose.family<SelectionNotifier, NodeId?, String>(
      SelectionNotifier.new,
    );

/// [selectionProvider]'s notifier.
class SelectionNotifier extends Notifier<NodeId?> {
  /// Creates the notifier for [sceneId].
  SelectionNotifier(this.sceneId);

  /// The family argument.
  final String sceneId;

  @override
  NodeId? build() => null;

  /// Selects [id], or selects nothing when null.
  void select(NodeId? id) => state = id;
}

/// The narrow rebuild for per-Node widgets (FR-001, constitution III):
/// watches only the document and returns the Node object itself, so
/// structural sharing plus Riverpod's `==` filtering skips notifying every
/// row whose Node is untouched.
final nodeProvider =
    Provider.autoDispose.family<Node?, (String, NodeId)>((ref, key) {
  final (sceneId, nodeId) = key;
  final document = ref.watch(
    documentProvider(sceneId).select((view) => view.document),
  );
  return document.node(nodeId);
});

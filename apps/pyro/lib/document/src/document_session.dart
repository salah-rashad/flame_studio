import 'dart:async';

import 'node_ids.dart';
import 'open_document.dart';
import 'recovery_store.dart';
import 'recovery_timer.dart';
import 'scene_document.dart';
import 'scene_files.dart';

/// What a session needs from outside, so tests can fake each one.
final class SessionServices {
  /// Creates the services for sessions in the project at [projectRoot].
  SessionServices({
    required this.files,
    required this.recovery,
    required this.projectRoot,
    this.recoveryInterval = const Duration(seconds: 30),
    this.newId = uuidNodeIds,
  });

  /// Reads and writes the Scene files.
  final SceneFiles files;

  /// Keeps the recovery copies.
  final RecoveryStore recovery;

  /// How often a recovery copy is written while there are unsaved changes;
  /// a fixed default until Settings arrive (FR-024, *Q85*).
  final Duration recoveryInterval;

  /// The open project's root folder, absolute.
  final String projectRoot;

  /// Makes Node IDs for new Scenes.
  final NodeIdSource newId;
}

/// One open Scene: its state, history, saves and recovery copy
/// (spec 002, research R13).
///
/// The only way to change the Scene is [transact]. Each new state is
/// published on [changes], synchronously and in order, so the editor's
/// providers and the viewport's reconciler see every step.
final class DocumentSession {
  DocumentSession._(this._services, this._state) {
    _recovery = RecoveryTimer(
      interval: _services.recoveryInterval,
      readDocument: () => _state,
      writeCopy: (document) => _services.recovery.write(
        projectRoot: _services.projectRoot,
        scenePath: document.path!,
        state: document.state,
      ),
      reportError: _errors.add,
    );
  }

  /// A session for a new, unsaved Scene (FR-021).
  static DocumentSession create({required SessionServices services}) =>
      DocumentSession._(services, createDocument(newId: services.newId));

  /// A session for the Scene file at [path]. The caller checks for a
  /// recovery copy first and restores it instead when the developer accepts.
  ///
  /// Throws `SceneOpenFailed`.
  static Future<DocumentSession> open(
    String path, {
    required SessionServices services,
  }) async => DocumentSession._(services, await services.files.open(path));

  /// A session for the recovery copy [copy]: dirty, with an empty history,
  /// saving to the Scene's own path (FR-028). The copy stays until the Scene
  /// is saved or its changes are discarded.
  static Future<DocumentSession> restore(
    RecoveryInfo copy, {
    required SessionServices services,
  }) async =>
      DocumentSession._(services, await services.recovery.readCopy(copy));

  final SessionServices _services;
  OpenDocument _state;
  bool _closed = false;
  Future<void> _lastSave = Future.value();
  late final RecoveryTimer _recovery;
  final _changes = StreamController<OpenDocument>.broadcast(sync: true);
  final _errors = StreamController<Object>.broadcast(sync: true);

  /// The current document.
  OpenDocument get state => _state;

  /// Whether [close] or [discardAndClose] has run.
  bool get isClosed => _closed;

  /// Every new document, synchronously and in order.
  Stream<OpenDocument> get changes => _changes.stream;

  /// Problems that don't stop editing, such as a failed recovery write.
  Stream<Object> get errors => _errors.stream;

  /// Changes the Scene by [edit], named [label] (FR-006).
  ///
  /// Throws `TransactionFailed` and leaves [state] unchanged when [edit]
  /// throws a `DocumentEditError`. Transactions with the same non-null
  /// [coalesceKey] in a row form one undo step (FR-011).
  void transact(
    String label,
    SceneDocument Function(SceneDocument doc) edit, {
    Object? coalesceKey,
  }) {
    _checkOpen();
    _publish(_state.transact(label, edit, coalesceKey: coalesceKey));
  }

  /// Undoes one step, if there is one.
  void undo() {
    _checkOpen();
    _publish(_state.undo());
  }

  /// Redoes one step, if there is one.
  void redo() {
    _checkOpen();
    _publish(_state.redo());
  }

  /// Saves the Scene to its file, or to [saveAs] ("Save as").
  ///
  /// Waits for any save already running. Saves the state current when it
  /// starts; edits made meanwhile stay unsaved (FR-020). Throws what
  /// `SceneFiles.save` throws, and leaves the session's edits as they were.
  Future<void> save({
    required int? runtimeReadsUpTo,
    String? saveAs,
    bool overwrite = false,
  }) {
    _checkOpen();
    final run = _lastSave.then(
      (_) => _saveNow(runtimeReadsUpTo, saveAs: saveAs, overwrite: overwrite),
    );
    // The next save waits for this one whether it succeeds or not; this
    // one's error reaches the caller through `run`.
    _lastSave = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _saveNow(
    int? runtimeReadsUpTo, {
    String? saveAs,
    required bool overwrite,
  }) async {
    final oldPath = _state.path;
    // A save ends the coalescing run now, not when the write finishes, so a
    // gesture that goes on during the write starts a new entry and the saved
    // state stays in history (FR-011).
    _publish(_state.endRun());
    final result = await _services.files.save(
      _state,
      runtimeReadsUpTo: runtimeReadsUpTo,
      saveAs: saveAs,
      overwrite: overwrite,
    );
    _publish(_state.markSaved(result));
    // A copy being written now would outlive the discard below.
    await _recovery.idle;
    await _discardCopies({?oldPath, result.path});
  }

  // Removes the recovery copies of [paths] (FR-027). A failure doesn't undo
  // the save or the close; it is reported on [errors].
  Future<void> _discardCopies(Set<String> paths) async {
    _recovery.forgetWritten();
    for (final path in paths) {
      try {
        await _services.recovery.discard(
          projectRoot: _services.projectRoot,
          scenePath: path,
        );
      } on Exception catch (error) {
        _errors.add(error);
      }
    }
  }

  /// Closes the session, dropping any unsaved changes.
  Future<void> discardAndClose() async {
    _checkOpen();
    // A save already asked for finishes first; it never fails here.
    await _lastSave;
    _recovery.cancel();
    await _recovery.idle;
    await _discardCopies({?_state.path});
    await _shutDown();
  }

  /// Closes a session without unsaved changes; throws [StateError] if it has
  /// some, so unsaved work is never dropped by accident.
  Future<void> close() async {
    _checkOpen();
    await _lastSave;
    if (_state.isDirty) {
      throw StateError(
        'Scene "${_state.path ?? 'untitled'}" has unsaved changes; save or '
        'discard them before closing',
      );
    }
    _recovery.cancel();
    await _recovery.idle;
    await _shutDown();
  }

  void _publish(OpenDocument next) {
    if (identical(next, _state)) return;
    _state = next;
    _changes.add(next);
  }

  void _checkOpen() {
    if (_closed) {
      throw StateError('Scene "${_state.path ?? 'untitled'}" is closed');
    }
  }

  Future<void> _shutDown() async {
    _closed = true;
    _recovery.cancel();
    await _changes.close();
    await _errors.close();
  }
}

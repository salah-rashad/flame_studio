import 'dart:async';

import 'open_document.dart';
import 'scene_document.dart';

/// Writes a recovery copy of a session's document at a fixed interval while
/// it has unsaved changes and a file path (spec 002, FR-024; research R12).
final class RecoveryTimer {
  /// Creates a timer that, every [interval], reads the document with
  /// [readDocument] and hands it to [writeCopy] when a copy is due; failures
  /// go to [reportError].
  RecoveryTimer({
    required Duration interval,
    required OpenDocument Function() readDocument,
    required Future<void> Function(OpenDocument document) writeCopy,
    required void Function(Object error) reportError,
  }) : _read = readDocument,
       _write = writeCopy,
       _onError = reportError {
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  final OpenDocument Function() _read;
  final Future<void> Function(OpenDocument document) _write;
  final void Function(Object error) _onError;
  late final Timer _timer;
  SceneDocument? _lastWritten;
  Future<void> _pending = Future.value();
  bool _writing = false;

  /// Completes when no copy is being written.
  Future<void> get idle => _pending;

  /// Forgets the last copy, after it was removed (a save or a discard), so
  /// the next due tick writes again.
  void forgetWritten() => _lastWritten = null;

  /// Stops the timer; a write in progress still finishes ([idle]).
  void cancel() => _timer.cancel();

  void _tick() {
    if (_writing) return;
    final document = _read();
    if (document.path == null || !document.isDirty) return;
    if (identical(document.state, _lastWritten)) return;
    _writing = true;
    _pending = _write(document)
        .then<void>((_) => _lastWritten = document.state, onError: _onError)
        .whenComplete(() => _writing = false);
  }
}

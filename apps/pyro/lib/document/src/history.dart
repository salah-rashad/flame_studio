import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'scene_document.dart';

/// One undo step: the state after it and the name it is undone by.
final class HistoryEntry {
  /// Creates an entry.
  const HistoryEntry(this.label, this.state);

  /// Shown as "Undo [label]"; for a coalesced run, the first step's label.
  final String label;

  /// The document state after the step.
  final SceneDocument state;
}

/// Snapshot undo history over immutable document states (spec 002, FR-010 to
/// FR-016; research R5).
///
/// A pure value with identity equality: Riverpod compares with `==`, and a
/// deep comparison of the whole history would run on every edit (research
/// R4).
final class DocumentHistory {
  /// A history holding only [state], labelled `Open`. When [clean], [state]
  /// is also the saved state; repaired and restored documents pass false, so
  /// they stay dirty until saved.
  DocumentHistory.opened(SceneDocument state, {required bool clean})
    : entries = IList([HistoryEntry('Open', state)]),
      index = 0,
      saved = clean ? state : null,
      openCoalesceKey = null;

  const DocumentHistory._(
    this.entries,
    this.index,
    this.saved,
    this.openCoalesceKey,
  );

  /// How many steps are kept after the oldest entry (FR-014).
  static const int maxSteps = 200;

  /// The entries, oldest first; at most [maxSteps] + 1.
  final IList<HistoryEntry> entries;

  /// The position of the current entry in [entries].
  final int index;

  /// The state on disk, or null when the document has none yet.
  final SceneDocument? saved;

  /// The coalescing key of the run in progress, or null.
  final Object? openCoalesceKey;

  /// The current state.
  SceneDocument get current => entries[index].state;

  /// Whether the current state isn't the one on disk (FR-015).
  bool get isDirty => !identical(current, saved);

  /// Whether there is a step to undo.
  bool get canUndo => index > 0;

  /// Whether there is a step to redo.
  bool get canRedo => index < entries.length - 1;

  /// The label undo would undo, or null.
  String? get undoLabel => canUndo ? entries[index].label : null;

  /// The label redo would redo, or null.
  String? get redoLabel => canRedo ? entries[index + 1].label : null;

  /// Records [next], made by the transaction [label].
  ///
  /// An identical [next] changes nothing (FR-009). With the same non-null
  /// [coalesceKey] as the run in progress, [next] replaces the run's entry
  /// and keeps its first label (FR-011). Otherwise the redo steps are dropped
  /// (FR-012), [next] is appended, and the oldest entries beyond [maxSteps]
  /// are dropped.
  DocumentHistory apply(
    String label,
    SceneDocument next, {
    Object? coalesceKey,
  }) {
    if (identical(next, current)) return this;
    if (coalesceKey != null && coalesceKey == openCoalesceKey) {
      final top = entries[index];
      return DocumentHistory._(
        entries.put(index, HistoryEntry(top.label, next)),
        index,
        saved,
        coalesceKey,
      );
    }
    var kept = entries.take(index + 1).toIList().add(HistoryEntry(label, next));
    if (kept.length > maxSteps + 1) {
      kept = kept.removeRange(0, kept.length - maxSteps - 1);
    }
    return DocumentHistory._(kept, kept.length - 1, saved, coalesceKey);
  }

  /// The history one step back, or this one when there is none.
  DocumentHistory undo() =>
      canUndo ? DocumentHistory._(entries, index - 1, saved, null) : this;

  /// The history one step forward, or this one when there is none.
  DocumentHistory redo() =>
      canRedo ? DocumentHistory._(entries, index + 1, saved, null) : this;

  /// The history with the coalescing run in progress ended, so the next
  /// keyed transaction starts a new entry. A save calls it when it captures
  /// the state it writes, so that state stays in history (FR-011).
  DocumentHistory endRun() => openCoalesceKey == null
      ? this
      : DocumentHistory._(entries, index, saved, null);

  /// The history after [state] was written to disk. [state] is the state the
  /// save started from, which may no longer be current (FR-020).
  DocumentHistory markSaved(SceneDocument state) =>
      DocumentHistory._(entries, index, state, null);
}

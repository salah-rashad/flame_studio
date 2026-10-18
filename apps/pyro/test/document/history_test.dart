import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/src/history.dart';
import 'package:pyro/document/src/scene_document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/scenes.dart';

void main() {
  const a = NodeId('a');
  late SceneDocument opened;
  var renames = 0;

  // A new state with Node "a" renamed, so every call is a real change.
  SceneDocument rename(SceneDocument doc) => doc.replaceNode(
    (doc.node(a)! as EntityNode).copyWith(name: 'a${renames++}'),
  );

  setUp(() => opened = SceneDocument.fromScene(smallScene()));

  test('the opening state is labelled Open and not undoable', () {
    final history = DocumentHistory.opened(opened, clean: true);
    expect(history.entries.single.label, 'Open');
    expect(identical(history.current, opened), isTrue);
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.undoLabel, isNull);
    expect(history.isDirty, isFalse);
  });

  test('apply adds one labelled entry; undo and redo restore exact states', () {
    final first = rename(opened);
    final second = rename(first);
    var history = DocumentHistory.opened(
      opened,
      clean: true,
    ).apply('Rename', first).apply('Rename again', second);
    expect(history.entries.length, 3);
    expect(history.undoLabel, 'Rename again');

    history = history.undo();
    expect(identical(history.current, first), isTrue);
    expect(history.undoLabel, 'Rename');
    expect(history.redoLabel, 'Rename again');
    history = history.undo();
    expect(identical(history.current, opened), isTrue);
    expect(history.canUndo, isFalse);
    expect(identical(history.undo(), history), isTrue);

    history = history.redo().redo();
    expect(identical(history.current, second), isTrue);
    expect(history.canRedo, isFalse);
    expect(identical(history.redo(), history), isTrue);
  });

  test('a coalescing run is one entry with the first label', () {
    var history = DocumentHistory.opened(opened, clean: true);
    var state = opened;
    for (var i = 0; i < 100; i++) {
      state = rename(state);
      history = history.apply(
        i == 0 ? 'Drag' : 'Drag step $i',
        state,
        coalesceKey: ('drag', 1),
      );
    }
    expect(history.entries.length, 2);
    expect(history.undoLabel, 'Drag');
    expect(identical(history.current, state), isTrue);
    expect(identical(history.undo().current, opened), isTrue);
  });

  group('what ends a coalescing run', () {
    DocumentHistory twoRuns(DocumentHistory Function(DocumentHistory) between) {
      var history = DocumentHistory.opened(
        opened,
        clean: true,
      ).apply('Drag', rename(opened), coalesceKey: 'k');
      history = between(history);
      return history.apply('Drag', rename(history.current), coalesceKey: 'k');
    }

    test('a different key', () {
      final history = DocumentHistory.opened(opened, clean: true)
          .apply('Drag', rename(opened), coalesceKey: 'k')
          .apply('Scrub', rename(opened), coalesceKey: 'other');
      expect(history.entries.length, 3);
    });

    test('an unkeyed transaction', () {
      expect(
        twoRuns((h) => h.apply('Rename', rename(h.current))).entries.length,
        4,
      );
    });

    test('an undo then a redo', () {
      expect(twoRuns((h) => h.undo().redo()).entries.length, 3);
    });

    test('a save', () {
      final history = twoRuns((h) => h.markSaved(h.current));
      expect(history.entries.length, 3);
      expect(identical(history.undo().current, history.saved), isTrue);
    });
  });

  test('applying after undo drops the redo tail', () {
    final first = rename(opened);
    final history = DocumentHistory.opened(opened, clean: true)
        .apply('One', first)
        .apply('Two', rename(first))
        .undo()
        .undo()
        .apply('Three', rename(opened));
    expect(history.entries.length, 2);
    expect(history.canRedo, isFalse);
    expect(history.undoLabel, 'Three');
  });

  test('an identical state adds nothing and changes nothing', () {
    final history = DocumentHistory.opened(opened, clean: true);
    expect(identical(history.apply('Nothing', opened), history), isTrue);
  });

  test('the history keeps 200 steps after the opening state', () {
    var history = DocumentHistory.opened(opened, clean: true);
    var state = opened;
    for (var i = 0; i < 250; i++) {
      state = rename(state);
      history = history.apply('Step $i', state);
    }
    expect(history.entries.length, DocumentHistory.maxSteps + 1);
    expect(history.entries.first.label, 'Step 49');
    expect(history.isDirty, isTrue);
    while (history.canUndo) {
      history = history.undo();
    }
    expect(history.isDirty, isTrue, reason: 'the saved entry was dropped');
  });

  test('dirty is identity with the saved state', () {
    final first = rename(opened);
    var history = DocumentHistory.opened(opened, clean: true);
    history = history.apply('Rename', first);
    expect(history.isDirty, isTrue);
    expect(history.undo().isDirty, isFalse);

    history = history.markSaved(first);
    expect(history.isDirty, isFalse);
    expect(history.undo().isDirty, isTrue);
    expect(history.undo().redo().isDirty, isFalse);
  });

  test(
    'marking a state that is no longer current keeps the document dirty',
    () {
      final first = rename(opened);
      final history = DocumentHistory.opened(
        opened,
        clean: true,
      ).apply('One', first).apply('Two', rename(first)).markSaved(first);
      expect(history.isDirty, isTrue);
      expect(history.undo().isDirty, isFalse);
    },
  );

  test('a document opened without a saved state stays dirty', () {
    var history = DocumentHistory.opened(opened, clean: false);
    expect(history.isDirty, isTrue);
    history = history.apply('Rename', rename(opened)).undo();
    expect(history.isDirty, isTrue);
    expect(history.markSaved(history.current).isDirty, isFalse);
  });
}

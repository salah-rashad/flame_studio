import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// The coalescing keys of the inspector's edit runs (FR-034): consecutive
/// edits of one property under one key merge into one undo step — a typed
/// value, a scrub, a text edit — and ending the run gives the next edit a
/// key of its own.
final class GestureKeys {
  final Map<String, Object> _keys = {};

  /// The key of the run on [property].
  Object keyFor(String property) => _keys[property] ??= Object();

  /// Ends the run on [property]: the gesture is done.
  void end(String property) => _keys.remove(property);
}

/// Writes the inspector's edits of one Node as named transactions on its
/// Scene's document — the only way a panel changes it.
final class NodeEdits {
  /// Creates the writer for [nodeId] of scene [sceneId].
  NodeEdits(this.ref, this.sceneId, this.nodeId, this.gestures);

  /// Reads the document's notifier.
  final WidgetRef ref;

  /// The Scene's provider key.
  final String sceneId;

  /// The edited Node.
  final NodeId nodeId;

  /// The panel's edit runs.
  final GestureKeys gestures;

  /// Applies [change] to the Node as a step of the run on [property]; with
  /// [end] the run is over and the next edit starts a new undo step.
  void edit(
    String property,
    Node Function(Node node) change, {
    bool end = false,
  }) {
    final key = '$nodeId/$property';
    _transact('Set $property', change, gestures.keyFor(key));
    if (end) gestures.end(key);
  }

  /// Applies [change] as a step of its own (*Reset to default*).
  void reset(String property, Node Function(Node node) change) {
    gestures.end('$nodeId/$property');
    _transact('Reset $property', change, null);
  }

  void _transact(String label, Node Function(Node) change, Object? key) {
    ref.read(documentProvider(sceneId).notifier).transact(label, (doc) {
      final node = doc.node(nodeId);
      return node == null ? doc : doc.replaceNode(change(node));
    }, coalesceKey: key);
  }
}

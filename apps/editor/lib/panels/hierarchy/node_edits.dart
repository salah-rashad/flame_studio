import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

/// [node] named [name]; a blank [name] clears the name. Only the name
/// changes: the Node keeps its ID, children and every other value
/// (FR-027). The root has no name, so it comes back unchanged.
Node withName(Node node, String name) {
  final trimmed = name.trim();
  final clear = trimmed.isEmpty;
  return switch (node) {
    RootNode() => node,
    EntityNode() => node.copyWith(name: trimmed, clearName: clear),
    SpriteNode() => node.copyWith(name: trimmed, clearName: clear),
    RectangleHitboxNode() => node.copyWith(name: trimmed, clearName: clear),
    CircleHitboxNode() => node.copyWith(name: trimmed, clearName: clear),
    CustomNode() => node.copyWith(name: trimmed, clearName: clear),
    UnknownNode() => UnknownNode(
      id: node.id,
      childIds: node.childIds,
      extra: node.extra,
      name: clear ? null : trimmed,
      tags: node.tags,
      kind: node.kind,
    ),
  };
}

/// What a transaction label calls [node].
String _called(Node node) => switch (node) {
  NamedNode(:final name?) when name.isNotEmpty => name,
  _ => 'Node',
};

/// Renames [id] of [current] in one named transaction. Nothing happens when the name is
/// unchanged, so cancelling by committing the same text leaves no undo step.
void renameNode(
  DocumentNotifier document,
  SceneDocument current,
  NodeId id,
  String name,
) {
  final node = current.node(id);
  if (node is! NamedNode || (node.name ?? '') == name.trim()) return;
  document.transact(
    'Rename ${_called(node)}',
    (doc) => doc.replaceNode(withName(doc.node(id)!, name)),
  );
}

/// Deletes [id] of [current] with its subtree in one named transaction (FR-026); one
/// undo restores all of it. The root can't be deleted.
void deleteNode(DocumentNotifier document, SceneDocument current, NodeId id) {
  final node = current.node(id);
  if (node == null || node is RootNode) return;
  document.transact('Delete ${_called(node)}', (doc) => doc.removeNode(id));
}

/// Where a drop on [targetId]'s [zone] would put the dragged Node.
typedef Placement = ({NodeId parentId, int? index});

/// The parent and index a drop of [draggedId] on [targetId]'s [zone] means:
/// into the target as its last child, or next to it among its siblings. The
/// index counts the siblings without the dragged Node, as
/// `SceneDocument.moveNode` does. Null when the drop has no place: the
/// Node on itself, or beside the root.
Placement? placementOf(
  SceneDocument doc,
  NodeId draggedId,
  NodeId targetId,
  PrDropZone zone,
) {
  if (draggedId == targetId) return null;
  if (zone == PrDropZone.inside) return (parentId: targetId, index: null);
  final parentId = doc.parentOf(targetId);
  if (parentId == null) return null;
  final siblings = [...doc.node(parentId)!.childIds]..remove(draggedId);
  final at = siblings.indexOf(targetId);
  return (parentId: parentId, index: zone == PrDropZone.above ? at : at + 1);
}

/// Whether a drop of [draggedId] on [targetId]'s [zone] may happen, with
/// the reason when it may not (FR-028). An empty reason means a refusal
/// with nothing to tell: the Node dropped on itself.
ReparentCheck checkDrop(
  SceneDocument doc,
  TypeCatalog catalog,
  NodeId draggedId,
  NodeId targetId,
  PrDropZone zone,
) {
  final placement = placementOf(doc, draggedId, targetId, zone);
  if (placement == null) {
    return ReparentRefused(
      draggedId == targetId ? '' : 'The scene root has no siblings.',
    );
  }
  return canReparent(doc, catalog, draggedId, placement.parentId);
}

/// Moves [draggedId] of [current] to [placement] in one named transaction (FR-028):
/// "Reorder" within a parent, "Move" across parents.
void moveNodeTo(
  DocumentNotifier document,
  SceneDocument current,
  NodeId draggedId,
  Placement placement,
) {
  final node = current.node(draggedId);
  if (node == null) return;
  final verb = current.parentOf(draggedId) == placement.parentId
      ? 'Reorder'
      : 'Move';
  document.transact(
    '$verb ${_called(node)}',
    (doc) => doc.moveNode(
      draggedId,
      parentId: placement.parentId,
      index: placement.index,
    ),
  );
}

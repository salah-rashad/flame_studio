import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

/// One row of the flattened tree: a Node and how deep it sits.
typedef VisibleRow = ({NodeId id, int depth});

/// The rows the hierarchy shows, top to bottom. Compared by content, so a
/// document change that doesn't move a row (a position drag, an inspector
/// edit) doesn't rebuild the list.
@immutable
final class VisibleRows {
  /// Wraps [rows].
  const VisibleRows(this.rows);

  /// The rows in order.
  final List<VisibleRow> rows;

  /// The index of [id], or -1 when it isn't visible.
  int indexOf(NodeId id) => rows.indexWhere((row) => row.id == id);

  @override
  bool operator ==(Object other) =>
      other is VisibleRows && listEquals(rows, other.rows);

  @override
  int get hashCode => Object.hashAll(rows);
}

/// The visible tree of [doc] in `childIds` order, skipping the children of
/// every Node in [collapsed] (FR-024).
VisibleRows flattenTree(SceneDocument doc, ISet<NodeId> collapsed) {
  final rows = <VisibleRow>[];
  final stack = <VisibleRow>[(id: doc.rootId, depth: 0)];
  while (stack.isNotEmpty) {
    final row = stack.removeLast();
    final node = doc.node(row.id);
    if (node == null) continue;
    rows.add(row);
    if (collapsed.contains(row.id)) continue;
    for (final child in node.childIds.reversed) {
      stack.add((id: child, depth: row.depth + 1));
    }
  }
  return VisibleRows(rows);
}

/// The Nodes whose children are hidden in one scene's tree. Collapsed
/// rather than expanded, so a scene opens fully expanded and a new Node
/// always shows. Editor state outside the document (*Q25*); it outlives the
/// panel so a tab keeps its tree as it was.
final collapsedNodesProvider =
    NotifierProvider.family<CollapsedNodes, ISet<NodeId>, String>(
      CollapsedNodes.new,
    );

/// [collapsedNodesProvider]'s notifier.
class CollapsedNodes extends Notifier<ISet<NodeId>> {
  /// Creates the notifier for [sceneId].
  CollapsedNodes(this.sceneId);

  /// The family argument.
  final String sceneId;

  @override
  ISet<NodeId> build() => const ISet.empty();

  /// Shows or hides the children of [id].
  void setCollapsed(NodeId id, {required bool collapsed}) =>
      state = collapsed ? state.add(id) : state.remove(id);

  /// Shows the children of every Node in [ids].
  void expandAll(Iterable<NodeId> ids) => state = state.removeAll(ids);
}

/// The rows of scene [sceneId]'s tree.
final visibleRowsProvider = Provider.autoDispose.family<VisibleRows, String>((
  ref,
  sceneId,
) {
  final document = ref.watch(
    documentProvider(sceneId).select((view) => view.document),
  );
  return flattenTree(document, ref.watch(collapsedNodesProvider(sceneId)));
});

/// The tree icon of [node]'s kind.
IconData iconOf(Node node) => switch (node) {
  RootNode() => PrIcons.layers,
  EntityNode() => PrIcons.box,
  SpriteNode() => PrIcons.image,
  RectangleHitboxNode() || CircleHitboxNode() => PrIcons.hitbox,
  CustomNode() || UnknownNode() => PrIcons.circleDot,
};

/// The icon of the type [id], as the Add menu shows it.
IconData iconOfType(TypeId id) => switch (id.value) {
  'entity' => PrIcons.box,
  'sprite' => PrIcons.image,
  'rectangleHitbox' || 'circleHitbox' => PrIcons.hitbox,
  _ => PrIcons.circleDot,
};

/// What a row says: the Node's name, or its kind when it has none.
String labelOf(Node node, TypeCatalog catalog, {required String rootName}) {
  if (node is NamedNode && node.name != null && node.name!.isNotEmpty) {
    return node.name!;
  }
  return switch (node) {
    RootNode() => rootName,
    EntityNode() => 'Entity',
    SpriteNode() => 'Sprite',
    RectangleHitboxNode() => 'Rectangle hitbox',
    CircleHitboxNode() => 'Circle hitbox',
    CustomNode(:final type) => catalog[type]?.label ?? type.value,
    UnknownNode(:final kind) => kind,
  };
}

/// Whether [node] is a Missing component: a type the catalog doesn't know,
/// or a kind this version doesn't. A stale catalog (*Q105*) holds the last
/// good types, so it never calls anything Missing.
bool isMissing(Node node, TypeCatalog catalog) => switch (node) {
  UnknownNode() => true,
  CustomNode(:final type) =>
    catalog[type] == null && catalog.origin is! ManifestStale,
  _ => false,
};

/// Whether [node] carries a Behavior whose type the catalog doesn't know
/// (FR-037): the Behavior is kept, and the row says so. Like [isMissing],
/// never true from a stale catalog.
bool hasMissingBehavior(Node node, TypeCatalog catalog) =>
    catalog.origin is! ManifestStale &&
    (switch (node) {
      EntityNode(:final behaviors) => behaviors,
      CustomNode(:final behaviors) => behaviors,
      _ => const <BehaviorAttachment>[],
    }).any((behavior) => catalog[behavior.type] == null);

/// Whether [node] can have children at all; leaf kinds' rows only accept a
/// drop above or below them.
bool acceptsChildren(Node node, TypeCatalog catalog) => switch (node) {
  RectangleHitboxNode() || CircleHitboxNode() => false,
  CustomNode(:final type) => catalog[type]?.acceptsBehaviors ?? true,
  _ => true,
};

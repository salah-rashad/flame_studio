import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'errors.dart';
import 'node_children.dart';

part 'scene_document.freezed.dart';

/// One immutable state of a Scene in Pyro (spec 002, FR-001 to FR-003).
///
/// A flat map of the Runtime's Nodes plus each Node's parent, shared with the
/// previous state wherever an edit didn't touch it (research R2, R3).
/// Compared by identity: an edit that changes nothing returns the same
/// object, so "not identical" means "changed" (research R4). There is no
/// public `copyWith`; the edits below are the only way to a new state, and
/// each keeps the tree valid.
@Freezed(
  equal: false,
  copyWith: false,
  makeCollectionsUnmodifiable: false,
  map: FreezedMapOptions.none,
  when: FreezedWhenOptions.none,
)
abstract class SceneDocument with _$SceneDocument {
  const factory SceneDocument._create({
    required NodeId rootId,
    required IMap<NodeId, Node> nodes,
    required IMap<NodeId, NodeId> parents,
    required Map<String, Object?> sceneExtra,
  }) = _SceneDocument;

  const SceneDocument._();

  /// The document state of [scene].
  factory SceneDocument.fromScene(Scene scene) {
    final parents = <NodeId, NodeId>{};
    for (final node in scene.nodes.values) {
      for (final child in node.childIds) {
        parents[child] = node.id;
      }
    }
    return SceneDocument._create(
      rootId: scene.rootId,
      nodes: IMap(scene.nodes),
      parents: IMap(parents),
      sceneExtra: scene.extra,
    );
  }

  /// This state as a Scene. `Scene`'s constructor checks the whole tree
  /// again, so a bug in an edit fails the save instead of writing a broken
  /// file.
  Scene toScene() =>
      Scene(rootId: rootId, nodes: nodes.unlockView, extra: sceneExtra);

  /// The Node [id], or null if there is none.
  Node? node(NodeId id) => nodes[id];

  /// Whether the Scene has a Node [id].
  bool contains(NodeId id) => nodes.containsKey(id);

  /// The parent of [id], or null for the root and unknown IDs.
  NodeId? parentOf(NodeId id) => parents[id];

  /// The children of [id] in order; empty for unknown IDs.
  List<NodeId> childrenOf(NodeId id) => nodes[id]?.childIds ?? const [];

  /// Whether [ancestor] is above [id] in the tree (a Node isn't its own
  /// ancestor).
  bool isAncestor(NodeId ancestor, NodeId id) {
    for (var p = parents[id]; p != null; p = parents[p]) {
      if (p == ancestor) return true;
    }
    return false;
  }

  /// Adds [node] under [parentId] at [index] among its children (default:
  /// last). The Node comes without children; add those one at a time.
  SceneDocument addNode(Node node, {required NodeId parentId, int? index}) {
    final name = _nameOf(node);
    if (node is RootNode) {
      throw RootNotAllowed(node.id, 'add', nodeName: name);
    }
    if (nodes.containsKey(node.id)) {
      throw DuplicateNodeId(node.id, nodeName: name);
    }
    final parent = _require(parentId);
    if (node.childIds.isNotEmpty) {
      throw NodeHasChildren(node.id, nodeName: name);
    }
    final children = parent.childIds;
    final at = _checkIndex(node.id, name, parentId, index, children.length);
    return SceneDocument._create(
      rootId: rootId,
      nodes: nodes
          .add(node.id, node)
          .add(
            parentId,
            withChildIds(parent, [...children]..insert(at, node.id)),
          ),
      parents: parents.add(node.id, parentId),
      sceneExtra: sceneExtra,
    );
  }

  /// Removes Node [id] and its whole subtree.
  SceneDocument removeNode(NodeId id) {
    final node = _require(id);
    if (id == rootId) throw RootNotAllowed(id, 'remove');
    final parentId = parents[id]!;
    final parent = nodes[parentId]!;
    var nextNodes = nodes.add(
      parentId,
      withChildIds(parent, [...parent.childIds]..remove(id)),
    );
    var nextParents = parents;
    final stack = [node];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      nextNodes = nextNodes.remove(current.id);
      nextParents = nextParents.remove(current.id);
      stack.addAll(current.childIds.map((c) => nodes[c]!));
    }
    return SceneDocument._create(
      rootId: rootId,
      nodes: nextNodes,
      parents: nextParents,
      sceneExtra: sceneExtra,
    );
  }

  /// Moves Node [id] under [parentId] at [index] among its children (default:
  /// last). [index] counts the children without the moved Node, so moving
  /// within one parent reorders.
  SceneDocument moveNode(NodeId id, {required NodeId parentId, int? index}) {
    final node = _require(id);
    final name = _nameOf(node);
    if (id == rootId) throw RootNotAllowed(id, 'move', nodeName: name);
    final target = _require(parentId);
    if (parentId == id || isAncestor(id, parentId)) {
      throw MoveIntoOwnSubtree(id, targetParentId: parentId, nodeName: name);
    }
    final oldParentId = parents[id]!;
    final oldParent = nodes[oldParentId]!;
    final targetChildren = [...target.childIds];
    if (oldParentId == parentId) targetChildren.remove(id);
    final at = _checkIndex(id, name, parentId, index, targetChildren.length);
    targetChildren.insert(at, id);
    if (oldParentId == parentId) {
      if (_sameIds(targetChildren, target.childIds)) return this;
      return SceneDocument._create(
        rootId: rootId,
        nodes: nodes.add(parentId, withChildIds(target, targetChildren)),
        parents: parents,
        sceneExtra: sceneExtra,
      );
    }
    return SceneDocument._create(
      rootId: rootId,
      nodes: nodes
          .add(
            oldParentId,
            withChildIds(oldParent, [...oldParent.childIds]..remove(id)),
          )
          .add(parentId, withChildIds(target, targetChildren)),
      parents: parents.add(id, parentId),
      sceneExtra: sceneExtra,
    );
  }

  /// Replaces the Node with [node]'s ID by [node]. Children don't change
  /// here: use [addNode], [removeNode] and [moveNode] for structure.
  SceneDocument replaceNode(Node node) {
    final current = _require(node.id);
    if (identical(current, node)) return this;
    final name = _nameOf(current);
    if ((current is RootNode) != (node is RootNode)) {
      throw RootNotAllowed(node.id, 'replace', nodeName: name);
    }
    if (!_sameIds(current.childIds, node.childIds)) {
      throw ChildrenChanged(node.id, nodeName: name);
    }
    return SceneDocument._create(
      rootId: rootId,
      nodes: nodes.add(node.id, node),
      parents: parents,
      sceneExtra: sceneExtra,
    );
  }

  Node _require(NodeId id) => nodes[id] ?? (throw NodeNotFound(id));

  static String? _nameOf(Node node) => node is NamedNode ? node.name : null;

  static int _checkIndex(
    NodeId id,
    String? name,
    NodeId parentId,
    int? index,
    int length,
  ) {
    if (index == null) return length;
    if (index < 0 || index > length) {
      throw IndexOutOfRange(
        id,
        parentId: parentId,
        index: index,
        length: length,
        nodeName: name,
      );
    }
    return index;
  }

  static bool _sameIds(List<NodeId> a, List<NodeId> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

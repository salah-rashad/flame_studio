import 'node.dart';
import 'values.dart';

/// A Scene: a tree of Nodes under one root, as stored in a `*.scene.json`
/// file.
///
/// A Scene in memory is always a valid tree: the constructor checks it.
/// Reading a damaged file repairs the tree first (`SceneCodec.decode`).
final class Scene {
  /// Creates a Scene whose root is `nodes[rootId]`.
  ///
  /// Throws an [ArgumentError] naming the Nodes involved unless the Nodes
  /// form one tree: exactly one [RootNode], which is `nodes[rootId]`; every
  /// child ID names a Node; no Node is listed twice, under two parents or
  /// under itself; the root is nobody's child; and every Node is reachable
  /// from the root. [extra] holds unknown top-level keys.
  Scene({
    required this.rootId,
    required Map<NodeId, Node> nodes,
    Map<String, Object?> extra = const {},
  }) : nodes = Map.unmodifiable(nodes),
       extra = Map.unmodifiable(extra),
       _parents = _checkTree(rootId, nodes);

  /// The newest `schemaVersion` this version reads and the one it writes.
  ///
  /// Any change that adds a Node kind, a Field type or a required key, or
  /// changes the meaning of existing data, increases it (FR-020a), so older
  /// readers refuse files they can't understand.
  static const int currentSchemaVersion = 1;

  /// The root Node's ID.
  final NodeId rootId;

  /// Every Node by ID.
  final Map<NodeId, Node> nodes;

  /// Unknown top-level keys, written back unchanged (FR-017).
  final Map<String, Object?> extra;

  final Map<NodeId, NodeId> _parents;

  /// The root Node.
  RootNode get root => nodes[rootId]! as RootNode;

  /// The parent of Node [id], or null for the root (or an unknown ID).
  NodeId? parentOf(NodeId id) => _parents[id];

  /// A copy with the given fields replaced, checked like a new Scene.
  Scene copyWith({
    NodeId? rootId,
    Map<NodeId, Node>? nodes,
    Map<String, Object?>? extra,
  }) => Scene(
    rootId: rootId ?? this.rootId,
    nodes: nodes ?? this.nodes,
    extra: extra ?? this.extra,
  );

  /// Checks the tree and returns each Node's parent.
  static Map<NodeId, NodeId> _checkTree(
    NodeId rootId,
    Map<NodeId, Node> nodes,
  ) {
    for (final MapEntry(:key, :value) in nodes.entries) {
      if (key != value.id) {
        throw ArgumentError(
          'Node "${value.id}" is stored under the key "$key"',
        );
      }
    }
    final roots = [
      for (final node in nodes.values)
        if (node is RootNode) node.id,
    ];
    if (roots.length != 1 || roots.single != rootId) {
      throw ArgumentError(
        'A Scene needs exactly one root Node, "$rootId"; found root Nodes '
        '${roots.map((id) => '"$id"').join(', ')}',
      );
    }
    final parents = <NodeId, NodeId>{};
    for (final node in nodes.values) {
      for (final child in node.childIds) {
        if (!nodes.containsKey(child)) {
          throw ArgumentError(
            'Node "${node.id}" lists child "$child", which doesn\'t exist',
          );
        }
        if (child == rootId) {
          throw ArgumentError(
            'Node "${node.id}" lists the root "$rootId" as a child',
          );
        }
        final existing = parents[child];
        if (existing != null) {
          throw ArgumentError(
            existing == node.id
                ? 'Node "${node.id}" lists child "$child" twice'
                : 'Node "$child" is listed under both "$existing" and "${node.id}"',
          );
        }
        parents[child] = node.id;
      }
    }
    // With one parent per Node, every Node is reachable unless a group of
    // Nodes is detached (an orphan, or a cycle).
    final reached = <NodeId>{rootId};
    final stack = [rootId];
    while (stack.isNotEmpty) {
      for (final child in nodes[stack.removeLast()]!.childIds) {
        if (reached.add(child)) stack.add(child);
      }
    }
    if (reached.length != nodes.length) {
      final detached = nodes.keys.where((id) => !reached.contains(id));
      throw ArgumentError(
        'Nodes not reachable from the root: '
        '${detached.map((id) => '"$id"').join(', ')}',
      );
    }
    return parents;
  }
}

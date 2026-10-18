import 'errors.dart';
import 'json/canonical_writer.dart';
import 'json/strict_reader.dart';
import 'node.dart';
import 'node_mapping.dart';
import 'scene.dart';
import 'tree_repair.dart';
import 'values.dart';

/// Reads and writes Scene files (`*.scene.json`) in the canonical form of
/// the Scene file contract.
///
/// Both directions are synchronous and work on plain data, so they can run
/// in `Isolate.run` for large files.
abstract final class SceneCodec {
  static const List<String> _topLevelOrder = [
    'schemaVersion',
    'rootId',
    'nodes',
  ];

  /// Reads the Scene in [text].
  ///
  /// Throws a [SceneFormatException] when the file can't be read. Reading
  /// never writes a file.
  static SceneReadResult decode(String text) {
    final json = readStrictJson(text);
    if (json is! Map<String, Object?>) {
      throw const InvalidRoot('A Scene file must hold a JSON object');
    }
    // The version gate runs before anything else is read: a newer file may
    // hold data this version would misread (FR-019, FR-020a).
    _checkSchemaVersion(json);

    final rootId = json['rootId'];
    if (rootId is! String || rootId.isEmpty) {
      throw const InvalidRoot('rootId is missing or not a non-empty string');
    }
    final nodesJson = json['nodes'];
    if (nodesJson is! Map<String, Object?>) {
      throw const InvalidRoot('nodes is missing or not a JSON object');
    }
    final nodes = <NodeId, Node>{
      for (final MapEntry(:key, :value) in nodesJson.entries)
        NodeId(key): nodeFromJson(NodeId(key), value),
    };
    _checkRoot(NodeId(rootId), nodes);

    // Repair merge damage in the childIds lists (FR-021); nothing else in a
    // Node changes (FR-023).
    final repaired = repairTree(NodeId(rootId), {
      for (final node in nodes.values) node.id: node.childIds,
    });
    for (final MapEntry(key: id, value: childIds)
        in repaired.childIds.entries) {
      final node = nodes[id]!;
      if (!_sameIds(node.childIds, childIds)) {
        nodes[id] = _withChildIds(node, childIds);
      }
    }

    return SceneReadResult(
      Scene(
        rootId: NodeId(rootId),
        nodes: nodes,
        extra: {
          for (final MapEntry(:key, :value) in json.entries)
            if (!_topLevelOrder.contains(key)) key: value,
        },
      ),
      repaired.report,
    );
  }

  static bool _sameIds(List<NodeId> a, List<NodeId> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Node _withChildIds(Node node, List<NodeId> childIds) => switch (node) {
    RootNode() => node.copyWith(childIds: childIds),
    EntityNode() => node.copyWith(childIds: childIds),
    SpriteNode() => node.copyWith(childIds: childIds),
    RectangleHitboxNode() => node.copyWith(childIds: childIds),
    CircleHitboxNode() => node.copyWith(childIds: childIds),
    CustomNode() => node.copyWith(childIds: childIds),
    UnknownNode() => node.copyWith(childIds: childIds),
  };

  /// Writes [scene] in canonical form, with the current `schemaVersion`.
  ///
  /// Throws [UnwritableValue] for a NaN or infinite number, naming the Node
  /// and key.
  static String encode(Scene scene) {
    final json = <String, Object?>{
      ...scene.extra,
      'schemaVersion': Scene.currentSchemaVersion,
      'rootId': scene.rootId,
      'nodes': {
        for (final MapEntry(:key, :value) in scene.nodes.entries)
          key: nodeToJson(value),
      },
    };
    try {
      return writeCanonicalJson(json, topLevelOrder: _topLevelOrder);
    } on UnwritableJsonValue catch (e) {
      final path = e.path;
      final inNode = path.length > 2 && path.first == 'nodes';
      throw UnwritableValue(
        e.value,
        nodeId: inNode ? NodeId(path[1] as String) : null,
        key: _keyPath(inNode ? path.sublist(2) : path),
      );
    }
  }

  /// Accepts a positive whole number (`1` or `1.0`) up to
  /// [Scene.currentSchemaVersion].
  static void _checkSchemaVersion(Map<String, Object?> json) {
    if (!json.containsKey('schemaVersion')) {
      throw const InvalidSchemaVersion.missing();
    }
    final version = json['schemaVersion'];
    if (version is! num || version != version.truncate() || version < 1) {
      throw InvalidSchemaVersion(version);
    }
    if (version > Scene.currentSchemaVersion) {
      throw UnsupportedSchemaVersion(
        found: version.toInt(),
        supported: Scene.currentSchemaVersion,
      );
    }
  }

  static void _checkRoot(NodeId rootId, Map<NodeId, Node> nodes) {
    final root = nodes[rootId];
    if (root == null) {
      throw InvalidRoot('rootId "$rootId" names no Node');
    }
    if (root is! RootNode) {
      final kind = nodeToJson(root)['kind'];
      throw InvalidRoot(
        'rootId "$rootId" names a Node of kind "$kind", not "root"',
      );
    }
    final roots = [
      for (final node in nodes.values)
        if (node is RootNode) '"${node.id}"',
    ];
    if (roots.length > 1) {
      throw InvalidRoot(
        'Only one Node may have kind "root"; found ${roots.join(', ')}',
      );
    }
  }

  /// `transform.position`, `behaviors[0].fields.speed`.
  static String _keyPath(List<Object> path) {
    final buffer = StringBuffer();
    for (final segment in path) {
      if (segment is int) {
        buffer.write('[$segment]');
      } else {
        if (buffer.isNotEmpty) buffer.write('.');
        buffer.write(segment);
      }
    }
    return buffer.toString();
  }
}

/// The result of [SceneCodec.decode]: the Scene, with its tree repaired,
/// and what was repaired.
final class SceneReadResult {
  /// Creates the result.
  const SceneReadResult(this.scene, this.repairs);

  /// The Scene.
  final Scene scene;

  /// What reading repaired; empty for a healthy file.
  final RepairReport repairs;
}

# Contract: Public Dart API

What `package:pyro_runtime/pyro_runtime.dart` exports for the scene format. Pyro's Document
model (#2) and the Runtime loader (#8) are the callers. Names follow `GLOSSARY.md`; types are
described in [data-model.md](../data-model.md). Signatures are the shape, not final code.

## Reading and writing

```dart
/// Reads and writes Scene files in canonical form (contracts/scene-file-v1.md).
abstract final class SceneCodec {
  /// Parses [text], refuses unsupported versions, builds the Nodes and repairs the tree.
  ///
  /// Throws a [SceneFormatException] subtype when the file can't be read; never writes a file.
  static SceneReadResult decode(String text);

  /// Writes [scene] in canonical form. Throws [UnwritableValue] for NaN or infinite numbers.
  static String encode(Scene scene);
}

final class SceneReadResult {
  final Scene scene;
  final RepairReport repairs;
}
```

`decode` and `encode` are synchronous and take and return plain data, so either can run in
`Isolate.run` (research R9).

## Model

```dart
final class Scene {
  static const int currentSchemaVersion = 1;

  Scene({required NodeId rootId, required Map<NodeId, Node> nodes, Map<String, Object?> extra});

  final NodeId rootId;
  final Map<NodeId, Node> nodes;     // unmodifiable
  final Map<String, Object?> extra;  // unmodifiable JSON values

  RootNode get root;
  NodeId? parentOf(NodeId id);       // derived, computed once
  Scene copyWith({NodeId? rootId, Map<NodeId, Node>? nodes, Map<String, Object?>? extra});
}

sealed class Node {
  NodeId get id;
  List<NodeId> get childIds;
  Map<String, Object?> get extra;
}

final class RootNode extends Node { ... }
final class EntityNode extends Node { NodeTransform transform; List<BehaviorAttachment> behaviors; ... }
final class SpriteNode extends Node { NodeTransform transform; AssetPath image; SpriteRegion? region; Map<String, Object?> propsExtra; ... }
final class RectangleHitboxNode extends Node { ...; Map<String, Object?> propsExtra; }
final class CircleHitboxNode extends Node { ...; Map<String, Object?> propsExtra; }
final class CustomNode extends Node { TypeId type; NodeTransform transform; Overrides fields; List<BehaviorAttachment> behaviors; ... }
final class UnknownNode extends Node { String kind; ... }
```

Every non-root Node also exposes `String? name` and `List<String> tags`; every Node class has
`copyWith`. `Scene`'s constructor checks the invariants in data-model.md and throws
`ArgumentError` when they don't hold, so a Scene in memory is always a valid tree.

`NodeTransform` carries an `extra` map for unknown keys inside `transform`, and the sprite and hitbox
classes carry `propsExtra` for unknown keys inside `props` (FR-017).

Value types: `Vec2`, `NodeTransform`, `NodeAnchor`, `SpriteRegion`, `NodeCollisionType`,
`BehaviorAttachment`, `Overrides`, `EntityRef`, `AssetRef`, and the extension types `NodeId`,
`TypeId` and `AssetPath`.

## Results and errors

```dart
final class RepairReport {
  List<TreeIssue> get issues;       // unmodifiable, in discovery order
  bool get isEmpty;
  String describe();                // one line per issue
}

sealed class TreeIssue { ... }      // MissingChild, SelfChild, RootAsChild, DuplicateChild,
                                    // MultipleParents, OrphanAttached, CycleBroken

sealed class SceneFormatException implements Exception { ... }
                                    // MalformedJson, DuplicateKey, UnsupportedSchemaVersion,
                                    // InvalidSchemaVersion, InvalidRoot, InvalidNode,
                                    // UnwritableValue
```

Every exception's `toString()` names what failed and where (FR-026).

## Debug warning in games (FR-024a)

```dart
/// In debug builds, prints one warning for [sceneKey] listing every repair and advising the
/// developer to open the Scene in Pyro and save it. Does nothing when [repairs] is empty or in
/// release builds, where the call is tree-shaken.
void warnAboutRepairs(String sceneKey, RepairReport repairs);
```

This is in `lib/src/loader/` (it uses `kDebugMode` and `debugPrint`). `PyroScene.load` (#8)
calls it; until then, tests call it directly.

## Not exported

The strict JSON reader and the canonical writer (`lib/src/scene/json/`) stay private;
`SceneCodec` is the only way in or out.

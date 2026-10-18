# Data Model: Scene Format

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-18

The in-memory model in `packages/pyro_runtime/lib/src/scene/`. Every type is immutable
(research R4): `final` fields, unmodifiable collections, `copyWith` on Nodes and the Scene.
How each type is written is in [contracts/scene-file-v1.md](contracts/scene-file-v1.md).

**JSON value**: below, `JsonValue` means `null`, `bool`, `num`, `String`, an unmodifiable
`List<JsonValue>` or an unmodifiable `Map<String, JsonValue>`, as the strict reader produces
them (R1). Unrecognised data is held in `extra` maps of this type and written back unchanged
(FR-017).

---

## Scene

| Field | Type | Rules |
|---|---|---|
| `schemaVersion` | `int` | Always `Scene.currentSchemaVersion` (1) in memory; older versions would be migrated on read (none exist yet), newer ones are refused (FR-019) |
| `rootId` | `NodeId` | Names a Node in `nodes` whose kind is root |
| `nodes` | `Map<NodeId, Node>` | Unmodifiable; keys equal each Node's `id` |
| `extra` | `Map<String, JsonValue>` | Unknown top-level keys |

**Invariants** (checked on read, and by `Scene`'s constructor):

- Exactly one `RootNode`, and it is `nodes[rootId]`.
- Every ID in every `childIds` names a Node in `nodes`; no Node appears in two lists or twice in
  one; the root appears in none; following `childIds` from the root reaches every Node exactly
  once. A Scene read from a damaged file satisfies these after repair.

**Derived:** `parentOf(NodeId)` is computed once per Scene from the `childIds` lists and is never
stored (FR-008).

## NodeId

An extension type over `String`; any non-empty string (UUIDs in practice, *Q14*). Ordering for
repair (R8) is `String.compareTo`.

## Node (sealed)

Common to every kind:

| Field | Type | Rules |
|---|---|---|
| `id` | `NodeId` | Unique in the Scene |
| `childIds` | `List<NodeId>` | Ordered; empty is omitted when writing |
| `extra` | `Map<String, JsonValue>` | Unknown keys of this Node |

Every kind except the root also has:

| Field | Type | Rules |
|---|---|---|
| `name` | `String?` | Node name; not unique; omitted when `null` |
| `tags` | `List<String>` | Ordered as written; empty is omitted |

### Node kinds

| Class | `kind` in the file | Own fields |
|---|---|---|
| `RootNode` | `root` | none |
| `EntityNode` | `entity` | `transform: Transform`, `behaviors: List<BehaviorAttachment>` |
| `SpriteNode` | `sprite` | `transform: Transform`, `image: AssetPath`, `region: SpriteRegion?`, `propsExtra` |
| `RectangleHitboxNode` | `rectangleHitbox` | `position: Vec2`, `size: Vec2`, `angle: double`, `anchor: NodeAnchor`, `collisionType: CollisionType`, `isSolid: bool`, `propsExtra` |
| `CircleHitboxNode` | `circleHitbox` | `position: Vec2`, `radius: double`, `anchor: NodeAnchor`, `collisionType: CollisionType`, `isSolid: bool`, `propsExtra` |
| `CustomNode` | `custom` | `type: TypeId`, `transform: Transform`, `fields: Overrides`, `behaviors: List<BehaviorAttachment>` |
| `UnknownNode` | anything else | `kind: String`, `name`/`tags` if they parse, everything else kept in `extra` |

`propsExtra: Map<String, JsonValue>` holds unknown keys inside a Node's `props` object, written
back unchanged (FR-017). Unknown keys therefore have a home at every level the format defines:
the top level (`Scene.extra`), a Node (`extra`), `transform` (`Transform.extra`), `props`
(`propsExtra`) and a Behavior (`BehaviorAttachment.extra`).

**Validation on read** (each failure is a `SceneFormatException` naming the Node ID and, when
known, its name, Type ID and the key; FR-026):

- Node IDs (the keys of `nodes`) are non-empty; `childIds` is a list of strings; `name` is a
  string; `tags` is a list of strings.
- `kind` is a string; `custom` requires a non-empty `type`.
- Every known key has the right JSON type: vectors are two finite numbers, `radius` and
  `size` components are ≥ 0, `collisionType` is one of its three names, `anchor` is a known
  name or a vector.
- `srcPosition` and `srcSize` are both present or both absent.
- `behaviors` is a list of objects, each with a non-empty `type`.

Which kinds may parent which is **not** checked here: Flame allows any component under any
other, and parent-kind rules belong to the editor.

## Value types

| Type | Fields | Notes |
|---|---|---|
| `Vec2` | `x`, `y`: `double` | Value equality. Not Flame's `Vector2` (R5) |
| `Transform` | `position`, `size`, `scale`: `Vec2`; `angle`: `double` (radians); `anchor`: `NodeAnchor`; `extra`: `Map<String, JsonValue>` | All five properties always written (FR-013); `extra` holds unknown keys inside `transform`, written back unchanged (FR-017) |
| `NodeAnchor` | a named anchor (`topLeft`, `topCenter`, `topRight`, `centerLeft`, `center`, `centerRight`, `bottomLeft`, `bottomCenter`, `bottomRight`) or a custom `Vec2` | Named ones are written by name |
| `SpriteRegion` | `position`, `size`: `Vec2` | Source rectangle in the image, in pixels |
| `CollisionType` | enum `active`, `passive`, `inactive` | Flame's names |
| `AssetPath` | extension type over `String` | Project-root-relative, as declared in the game's `pubspec.yaml` |
| `TypeId` | extension type over `String` | A Behavior or Custom component's Type ID (*Q45*) |

## Overrides and Behaviors

| Type | Fields | Rules |
|---|---|---|
| `Overrides` | `Map<String, JsonValue>` by field name | Only Overrides are present (FR-009); a value equal to the code default is still an Override; a value for a field the reader doesn't know is kept (FR-011); empty is omitted when writing |
| `BehaviorAttachment` | `type: TypeId`, `fields: Overrides`, `extra` | Order in the Node's list is preserved |

The format layer stores Override values as JSON values; it doesn't know Field types (those come
from the Manifest or Registry). Helpers convert the tagged forms:

| Helper | JSON | Meaning |
|---|---|---|
| `EntityRef` | `{"ref": "<NodeId>"}` | Another Node in the same Scene; a missing target is kept (resolving it is #8's job) |
| `AssetRef` | `{"asset": "<AssetPath>"}` | An asset reference field |

Other Field types are plain JSON values (contract, Field types table).

## Reading results

### SceneReadResult

| Field | Type |
|---|---|
| `scene` | `Scene` (after repair) |
| `repairs` | `RepairReport` |

### RepairReport

An unmodifiable, ordered list of `TreeIssue`s, in the order the passes of R8 found them; empty
for a healthy file. `isEmpty`, and `describe()` returning one line per issue for logs and the
Pyro banner.

### TreeIssue (sealed)

| Class | Data | Repair applied |
|---|---|---|
| `MissingChild` | `parentId`, `childId` | ID dropped from the parent's list |
| `SelfChild` | `nodeId` | Own ID dropped from its list |
| `RootAsChild` | `parentId` | Root's ID dropped from the parent's list |
| `DuplicateChild` | `parentId`, `childId` | Later occurrences dropped |
| `MultipleParents` | `nodeId`, `keptParentId`, `removedFromParentId` | Removed from the later parent |
| `OrphanAttached` | `nodeId` | Appended under the root |
| `CycleBroken` | `nodeIds` (sorted), `attachedNodeId`, `removedFromParentId` | Smallest ID appended under the root; its back-reference removed |

### SceneFormatException (sealed; implements `Exception`)

| Class | Data |
|---|---|
| `MalformedJson` | `message`, `offset`, `line`, `column` |
| `DuplicateKey` | `key`, `path` (for example `nodes.3f1c….transform`), `line`, `column` |
| `UnsupportedSchemaVersion` | `found`, `supported` |
| `InvalidSchemaVersion` | `found` (raw value or absent) |
| `InvalidRoot` | `reason` (missing `rootId`, no such Node, not kind root, several roots) |
| `InvalidNode` | `nodeId`, `nodeName?`, `typeId?`, `key?`, `message` |
| `UnwritableValue` | `nodeId`, `key`, `value` (NaN or infinity on write) |

## Lifecycle

There are no state transitions inside the format. The flow is:

```text
text ──read──▶ JSON values ──check version──▶ typed Nodes ──repair──▶ SceneReadResult
Scene ──to JSON values──▶ canonical writer ──▶ text
```

Reading never writes a file (FR-025). The Document model (#2) decides when a repaired Scene is
saved.

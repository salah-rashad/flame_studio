# Contract: Reconciler

The reconciler is the pure seam between the Document model and the preview world
(constitution V: Heavy). It is a **function, not a service**:

```dart
IList<PreviewOp> reconcile(SceneDocument? old, SceneDocument next);
```

- `old == null` seeds a world from scratch (open, tab shown again after being paused, forced
  full reconcile).
- The **only** caller is the viewport's wiring (`viewport/providers.dart`): it listens to the
  scene's document provider and applies the returned ops to the preview components. Panels
  never call it.

## Operations

| Op | Meaning | Applied to the world as |
|---|---|---|
| `AddNode(node, parentId, index)` | Node exists in `next`, not in `old` | create the preview component for the kind, insert under the parent's component at `index` |
| `RemoveNode(nodeId)` | Node (with its subtree — the document's `removeNode` is subtree-atomic) exists in `old`, not in `next` | remove the component subtree |
| `PatchNode(nodeId)` | Same `NodeId`, not `identical` | read the new Node and update the component in place (position/size/sprite/overrides) — no re-create |
| `ReparentNode(nodeId, parentId, index)` | Same Node object or changed, different `childIds` slot | move the existing component (keeps runtime state) |

## Invariants (each one is a named test)

1. **Identity skip**: a Node that is `identical` in `old` and `next` produces no op, and a
   Node whose *parent* changed but which is itself `identical` produces only
   `ReparentNode` — never `PatchNode`.
2. **Minimality**: a one-Node edit in a 1,000-Node document yields exactly one op
   (`PatchNode`), or two when it is a move (`ReparentNode`). This is SC-006 and the
   constitution III rebuild-scope rule made testable.
3. **Order**: `childIds` order is authoritative; a reorder within a parent is a
   `ReparentNode` with the new index.
4. **Subtree atomicity**: the document's `removeNode`/`moveNode` are subtree operations; the
   op list contains no ops for Nodes inside an added/removed subtree (they travel with it).
5. **Purity**: no clock, no I/O, no Flame imports — old/new documents in, ops out. That is
   what makes the Heavy test layer cheap.

## Live dragging

The move gizmo does not bypass the reconciler: each drag update is a `transact` with a gesture
`coalesceKey` (one history entry per gesture, §8.2), the document change flows back through
the provider, and the resulting `PatchNode` moves the component. Live feedback therefore uses
the exact production path — the reconciler's minimality is what keeps 60 fps reachable.

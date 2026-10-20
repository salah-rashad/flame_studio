# Data Model: Runtime

Phase 1 of [plan.md](plan.md). The Runtime's inputs are the Scene model from spec 001 and the
Registry from spec 003. This file covers what it builds from them and the state it keeps. Public
shapes are in [contracts/runtime-api.md](contracts/runtime-api.md), the animation file in
[contracts/anim-file-v1.md](contracts/anim-file-v1.md).

## Inputs

| Input | From | Used for |
|---|---|---|
| `Scene` (+ `RepairReport`) | `SceneCodec.decode` (spec 001) | the tree to build; repairs go to `warnAboutRepairs` |
| `PyroRegistry` | the game's `lib/pyro.g.dart` (spec 003), or hand-written in tests | creating Custom components and Behaviors, field metadata, setters, parent checks |
| `AssetSource` | the caller, or `AssetSource.bundle()` | every file read: the Scene, animation files, images |
| `UnknownType` | the caller (default `error`) | what to do with unknown Type IDs and Node kinds |
| `SceneReloaded?` | the caller | called after each successful Hot-swap |

## PyroScene (public, a Flame `Component`)

| State | Type | Notes |
|---|---|---|
| `path` | `AssetPath` | the Scene's asset path; in every message |
| `registry`, `onUnknownType`, `onReloaded`, source | as passed | kept for Hot-swap rebuilds |
| current build | `BuiltScene` | replaced whole on a successful Hot-swap |
| pending check | `Future<void>` | debug only; chains reloads so they never overlap (FR-027) |
| stale watch | `StaleWatch?` | debug only; the last removed generation (research R12) |

Lifecycle:

```text
load() ──decode──► Scene ──SceneBuilder──► BuiltScene ──► PyroScene (children queued, not mounted)
                      │ fails                     │ fails
                      └──────── SceneLoadException ┘ (nothing returned)

mounted ──onHotReload──► re-read texts ──equal──► (nothing)
                              │ differ
                              ▼
                        decode + build ──fails──► debug error, old Nodes kept
                              │ ok
                              ▼
                        swap children, replace index and texts, watch removed, onReloaded(this)
```

## BuiltScene (internal)

The result of one complete build. Nothing in it is attached to a live tree until the
`PyroScene` takes it.

| Field | Type | Notes |
|---|---|---|
| `children` | `List<Component>` | the root's child components, in `childIds` order, with their subtrees already added (queued) |
| `entries` | `List<NodeEntry>` | every built Node except the root, in tree order (depth first, `childIds` order); the lookup index |
| `componentsById` | `Map<NodeId, Component>` | pass 3's reference targets; the root maps to the `PyroScene` |
| `texts` | `Map<AssetPath, String>` | the Scene file and each animation file read, by path; the Hot-swap comparison (R11) |
| `skipped` | `List<SkippedItem>` | Nodes, Behaviors and references dropped under `UnknownType.skip`; empty under `error` |
| `unusedOverrides` | `List<UnusedOverride>` | Overrides for fields the Registry doesn't list (FR-012) |

### NodeEntry

| Field | Type | Notes |
|---|---|---|
| `id` | `NodeId` | |
| `name` | `String?` | null for unnamed Nodes, which never match a name or path |
| `tags` | `List<String>` | |
| `component` | `Component` | what lookups return |
| `parent` | `NodeEntry?` | null for children of the root; walked for path matching and for error paths |

`path` (for messages) is the names from the root down, joined by `/`, with an unnamed Node shown
as `#<id>`.

## SceneBuilder passes (internal)

| Pass | Reads | Produces | Fails with (FR) |
|---|---|---|---|
| 1. Construct | `Scene`, Registry, policy | a component per Node and Behavior; asset requests; `skipped` | unknown Type ID or kind (FR-015), role mismatch (FR-007), user constructor error (FR-018) |
| 2. Configure | asset source, Overrides | assets loaded; transforms, built-in props, non-reference Overrides set; `unusedOverrides`; `texts` | missing or bad asset (US2 #9), bad animation file or name (FR-010), value mismatch (FR-011), user setter error (FR-018) |
| 3. Resolve | `componentsById` | reference Overrides set | missing target or wrong type (FR-014) |
| 4. Attach | `acceptsParent` | Behaviors and children added (queued) | Behavior on a non-entity or wrong parent type (FR-008) |

### AssetRequest

A distinct asset the Scene needs: `(path, kind)`, where kind is `image` (sprite Nodes, `Sprite`
fields) or `animation` (an animation file plus the image it names). Requests are deduplicated by
path before loading (FR-031). Each request also remembers the first Node and field that asked
for it, for error messages.

## AnimationFile (internal model, `lib/src/animation/`)

Parsed from `.anim.json` ([contracts/anim-file-v1.md](contracts/anim-file-v1.md)).

| Field | Type |
|---|---|
| `schemaVersion` | `int` (≤ 1) |
| `image` | `AssetPath` |
| `grid` | `AnimationGrid(cellSize: Vec2, offset: Vec2, spacing: Vec2)` |
| `animations` | `Map<String, AnimationClip>` |

`AnimationClip`: `frames` (`List<int>`, non-empty, each ≥ 0), `stepTime` (`double?`) or `stepTimes`
(`List<double>?`, exactly one set), `loop` (`bool`). `toSpriteAnimation(Image image)` checks each
frame against the image's columns and rows and builds the Flame animation (research R7).

## Values converted from Overrides

See research R5 for the full table. Conversion is a pure function `(RegistryField, Object? written)
→ value | mismatch`, with the reference and asset kinds deferred to passes 2 and 3.

## Errors and warnings

| Shape | When | Where |
|---|---|---|
| `SceneLoadException` | any failed load (US2) | thrown by `PyroScene.load`; printed (debug) on a failed Hot-swap |
| skip warning | `skipped` non-empty | one `debugPrint` per load or rebuild |
| unused-Override warning | `unusedOverrides` non-empty | one `debugPrint` per load or rebuild |
| repair warning | the tree was repaired | `warnAboutRepairs` (spec 001 FR-024a) |
| stale-reference warning | first observed use of a removed Node (R12) | one `debugPrint` per Node per rebuild |
| lookup errors | `find` fails (US3) | `StateError` thrown by `find` |

Every message starts with the Scene's asset path. Warnings and the Hot-swap error print only in
debug builds.

## StaleWatch (internal, debug only)

The removed components of the last swap, by Node, each with a transform listener and a
`mounted` callback. `fire(node)` prints the warning and detaches that Node's watchers. `close()`
detaches every watcher left; it runs at the start of the next swap and when the `PyroScene` is
removed.

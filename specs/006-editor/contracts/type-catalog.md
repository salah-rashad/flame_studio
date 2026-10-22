# Contract: Type catalog

The Type catalog is the app's single source of truth for types, fields and parenting rules;
every panel (`hierarchy`, `inspector`, `viewport` placeholders) and the Add/Behavior lists read
it through `typeCatalogProvider` and nothing else. This file pins its shape and rules so the
panels, the descriptors and the tests agree. The Manifest's own file format is
[`specs/003-generator/contracts/manifest-v1.md`](../../003-generator/contracts/manifest-v1.md)
and is not repeated here.

## TypeDescriptor

| Field | Type | Notes |
|---|---|---|
| `id` | `TypeId` | Built-ins: `entity`, `sprite`, `rectangleHitbox`, `circleHitbox` |
| `role` | `behavior \| component` | Built-ins are `component` |
| `label` | `String` | Display name; falls back to the Type ID |
| `category` | `String?` | Groups the Add Behavior list |
| `doc` / `source` | `String?` | From the Manifest; tooltips and "Open in editor" (source link stored, opening is v0.1) |
| `parentType` | `TypeId?` | Behaviors: the required parent type |
| `supertypes` | `ISet<String>` | Reference/parenting filtering (*Q57*) |
| `acceptsBehaviors` | `bool` | Components only; built-ins: entity `true`, sprite/hitboxes `false` |
| `preview` | `AssetPath?` | `@PyroComponent(preview:)` |
| `builtIn` | `bool` | Hand-written descriptor, never from the Manifest |
| `fields` | `IList<FieldDescriptor>` | Manifest order |

**FieldDescriptor**: `name`, `type` (`FieldType`: int, double, bool, string, enumeration,
vector2, color, imagePath, sprite, spriteAnimation, entityRef), `nullable`, `defaultValue`
(evaluated) XOR `defaultSource` (non-constant), `min`/`max` (numbers only), `enumValues`,
`tooltip`. A field the Manifest no longer lists but whose Override exists in a scene is *not*
an error: the value round-trips untouched (constitution IV); the Runtime's unused-Override
warning covers the game side.

## Built-in descriptors (hand-written)

Exactly the fields the Node model carries, named as the Scene format writes them (spec 001):

| TypeId | Fields | Written in full (*Q89*) |
|---|---|---|
| `entity` | — (transform section covers position/angle/scale/size/anchor) | always |
| `sprite` | `image` (imagePath), `region` (vector2 pair, optional) | always |
| `rectangleHitbox` | `collisionType` (enum), `isSolid` (bool) | always |
| `circleHitbox` | `collisionType`, `isSolid` | always |

The transform section is not a FieldDescriptor — it is rendered for every positioned kind from
`NodeTransform` and never shows Override markers, "default from code" or Reset (*Q89*).

## Parenting rules (the one table)

Two pure functions over this one table — `childOffers(catalog, parent)` for the Add menu
and Add Child lists, `canReparent(doc, catalog, nodeId, newParentId)` for drag-reparent — so
panels and tests share one definition:

| Parent | Children offered |
|---|---|
| scene root | `entity`, custom components (`role: component` that accept the root — the Manifest's `supertypes` including a positioned/entity supertype; conservative default: offered unless the Manifest restricts it) |
| `entity` | `sprite`, `rectangleHitbox`, `circleHitbox`, custom components, `entity` |
| `sprite` | `rectangleHitbox`, `circleHitbox`, custom components |
| hitboxes | nothing (leaf kinds) |
| custom component | what its `supertypes` allow: components mixing in an entity supertype behave like `entity`; others are leaves. Behaviors follow `parentType`, not this table |

Hard rules that override any table row: **no hitbox under the scene root** (*Q115* — the
Runtime refuses it at load); **no Node into its own subtree** (cycle); behaviors are never
Nodes — they attach through the inspector only.

## Catalog states

- `manifest` — parsed cleanly; problems may still carry warnings (build succeeded).
- `builtinOnly` — no Manifest file at all (a project without annotated types).
- `lastGood(reason)` — the file was unreadable JSON, had `errors`, or a `manifestVersion`
  Pyro can't read (*Q105*): the previous `types` stay active, the reason is surfaced (status
  bar + inspector banner), and Missing states do **not** fire from a `lastGood` catalog (types
  are "stale", not gone).

Reload: on any write to `lib/pyro.manifest.json` (watcher, debounced). Pyro never runs the
generator (Phase 5's watcher).

## Editability (Phase 4)

Editable Field types: int, double (min/max honored), bool, string, enumeration, vector2,
imagePath (dropdown of declared-folder files). Read-only, round-trip-untouched: color,
entityRef, sprite, spriteAnimation (*Q100* — the Generator already emits them). Overrides:
user-type fields only (ADR 0003, *Q89*).

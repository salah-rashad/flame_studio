# Data Model: Editor (Phase 4)

Phase 1 output. The scene data itself (Node model, Overrides, canonical JSON) is unchanged —
it lives in pyro_runtime and spec 002. This file covers the new editor-side entities. All new
models are freezed-immutable; nothing here writes scene data except through
`DocumentSession.transact`.

## Type catalog (`lib/project/catalog/`)

Parses `lib/pyro.manifest.json` (format: [`specs/003-generator/contracts/manifest-v1.md`](../../003-generator/contracts/manifest-v1.md))
and joins it with the built-in descriptors. Shape in
[`contracts/type-catalog.md`](contracts/type-catalog.md).

- **TypeDescriptor** `{ TypeId id, TypeRole role, String label, String? category, String? doc,
  String? source, TypeId? parentType, ISet<String> supertypes, bool acceptsBehaviors,
  AssetPath? preview, bool builtIn, IList<FieldDescriptor> fields }`
  — one per type; `builtIn` distinguishes the hand-written descriptors (which never appear in
  the Manifest).
- **FieldDescriptor** `{ String name, FieldType type, bool nullable, Object? defaultValue,
  String? defaultSource, double? min, double? max, IList<String>? enumValues, String? tooltip }`
  — `defaultValue` is the evaluated constant; `defaultSource` carries non-constant defaults'
  source text (§7.3). Exactly one of them is present for non-nullable fields.
- **TypeCatalog** `{ IMap<TypeId, TypeDescriptor> types, IList<ManifestProblem> problems,
  ManifestOrigin origin }` — `origin`: `manifest` | `builtinOnly` (no/blank manifest — a
  project without annotated types still edits built-in kinds) | `lastGood(reason)` (unreadable,
  newer `manifestVersion` *Q105*, or errors present — the previous `types` are kept, with the
  reason surfaced). **ManifestProblem** `{ String code, String? file, int? line, String? className,
  String? field, String message, bool isWarning }` from `errors`/`warnings`.
- **Parenting rules** (`parenting.dart`): two pure functions over the contract's table —
  `childOffers(TypeCatalog, parent) → OfferedChild[]` (Add lists) and
  `canReparent(doc, TypeCatalog, nodeId, newParentId) → ReparentCheck` (allowed | refused(reason)).
  Rules: the scene root accepts entities and custom components only; an entity accepts sprites,
  both hitbox kinds, custom components and entities; sprites accept hitboxes and custom
  components; **no hitbox is offered under the root** (*Q115*) and no Node may move into its
  own subtree; custom types follow the Manifest's `parentType`/`supertypes` (*Q57*). The exact
  table lives in the contract file so panels and tests share one definition.

## Missing states (derived, never stored)

- A `CustomNode` whose `type` is not in the catalog → **Missing component** (hierarchy badge,
  error-toned placeholder, inspector notice); its `fields`, children and name are untouched.
- A `BehaviorAttachment` whose `type` is not in the catalog → **Missing behavior** (card shows
  "no longer exists in your code. Its values are kept"); values preserved verbatim on save.
- A `BehaviorAttachment` whose `parentType` no longer accepts its entity → **incompatible**,
  shown with the reason, kept the same way (*Q57*).
- `UnknownNode` → Missing component with `kind` shown.
- An enum Override whose value is not among the Manifest's `values` → displayed, marked kept.
- Recovery: when a type returns to the catalog, all states above resolve automatically because
  they were derived, never serialized (round trip loses nothing — SC-002).

## Project feature (`lib/project/`)

- **SdkInfo** `{ String? version, SdkSource source }`, `SdkSource = fvm | flutterRoot | path |
  none` — detection order §9.1. `none` never blocks editing.
- **RuntimeCompatibility** `{ RuntimeCompatStatus status, String? foundVersion, int? readsUpTo }`
  from `pubspec.lock` + the built-in table; statuses `ok | tooOld | tooNew | unknown`.
  `readsUpTo` feeds every `save` (*Q49*, *Q98*); `unknown`/`tooOld`/`tooNew` gate saving, not
  editing.
- **RecentProjects** `{ IList<String> paths, String? lastOpened }` persisted atomically in
  app-support; **PrShellSizes** per project path alongside (persisted by the shell's
  `onSizesChangeEnd`).

## App/tab model (`lib/app/providers.dart`)

- **OpenScene** `{ String sceneId, String? path, String displayName }` — `sceneId` is the
  provider family key (the canonical path once saved; a stable id for new scenes until then).
- **OpenScenesState** `{ IList<OpenScene> scenes, String? active }` — tab strip model; opening
  an already-open scene focuses its tab (clarified); closing dirty tabs raises the
  unsaved-changes dialog (pin/unpin the provider for the dialog's duration).

## Viewport (`lib/viewport/`)

- **Reconciler** (pure, [`contracts/reconciler.md`](contracts/reconciler.md)):
  `reconcile(SceneDocument? old, SceneDocument new) → IList<PreviewOp>` where
  `PreviewOp = AddNode(node, parentId, index) | RemoveNode(nodeId) | PatchNode(nodeId) |
  ReparentNode(nodeId, parentId, index)`. Invariants: `identical` Nodes never produce ops;
  a one-Node change to a 1,000-Node document yields exactly one op (SC-006).
- **PreviewComponent** mapping (per Node kind): entity → invisible positioned group (children
  attach under it); sprite → `SpriteComponent` (image from the disk asset source, optional
  region, `filterQuality = none`); hitboxes → outline components (also used for picking);
  custom → placeholder box + Type ID label, or the `preview:` image; Missing/unknown →
  error-toned placeholder. Each component records the asset paths it read (dependency index
  for file-watch rebuilds, *Q79*).
- **DiskAssetSource** implements pyro_runtime's `AssetSource` over the project root:
  `loadText` always fresh; `loadImage` decodes off-isolate into a refcounted `ui.Image` cache
  that releases an image only after nothing draws it; watch → rebuild only dependents (≤ 200 ms).
- **EditorCamera** `{ Vec2 position, double zoom }` per scene — editor state, outside the
  document (*Q25*), per-session and never persisted (spec Assumptions).
- **Overlay**: selection outline + hover + move gizmo as camera-viewfinder children (see
  research §4); the gizmo writes positions through the same `transact` door with a gesture
  `coalesceKey`.

## Inspector/panel view states

- **SelectionState** `{ NodeId? selected }` per scene (`selectionProvider`).
- Field-editor wiring: value = `Override` if present else the descriptor's default
  (`PrValueSource` accordingly); commit → `transact` with `coalesceKey: 'field:<node>:<name>'`;
  Reset to default → `Overrides.reset` (ADR 0003). Read-only rows (`Color`, `entityRef`,
  `Sprite`, `SpriteAnimation`) render the value display only; round-trip untouched (FR-033).
- Behavior cards: add (filtered by `parentType` through `supertypes`; `acceptsBehaviors`
  gates the button), remove (one transaction with its Overrides), Missing/incompatible as
  above.

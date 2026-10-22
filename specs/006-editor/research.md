# Research: Editor (Phase 4)

Phase 0 output. Four investigations: the app/runtime API surface to reuse (in-repo), the
`pyro_ui` component contracts (in-repo + `ui-components-plan.md`), Riverpod 3.3.x provider
patterns (verified against the pinned package sources and riverpod.dev), and the Flame 1.38.2
viewport composition (verified against the locked package source and docs.flame-engine.org).
Each decision below carries its rationale and the rejected alternative.

## 1. What exists and what is new

**Decision**: treat these as *new* Phase 4 code, because the survey found no existing
implementation: the disk `AssetSource` (pyro_runtime ships only the interface and the bundle
implementation — its doc names the viewport as the disk-side user), the `pubspec.lock` →
Runtime-version reader (only the `runtimeReadsUpTo` *parameter* exists, spec 002), the
`RecoveryStore.find` orchestration (only tests call it today; `DocumentSession.open`'s doc
delegates it to the caller), the project list, SDK detection, scene discovery from declared
asset folders, and the whole `app/`, `project/`, `viewport/`, `panels/` features
(`apps/pyro/lib` today holds only `document/`, `process/` and a placeholder `main.dart`).

**Rationale**: avoids re-planning existing code and names the true scope.
**Alternatives**: none — this is a survey result. Reusable as-is: spike 3's
`spikes/03_disk_render/studio/lib/disk_asset_source.dart` (DiskAssetBundle + tracked image
cache) is the starting point for the disk asset source, and `process/`'s `watchRecursively`
for file watching.

Key reuse facts: `DocumentSession` already exposes everything #1 needs —
`open`/`restore`/`create`, `changes` (sync broadcast of every `OpenDocument` step), `errors`,
`transact(label, edit, {coalesceKey})`, `undo/redo`, `save({required int? runtimeReadsUpTo,
saveAs, overwrite})` with the full refusal ladder (`RuntimeVersionUnknown`, `RuntimeTooOld`,
`SavePathRequired`, `SaveTargetExists`, `SceneChangedOnDisk`), `discardAndClose`, `close`
(throws when dirty). `OpenDocument` is the immutable snapshot (document + history view +
`isDirty` + `repairs` + `origin`); `SceneDocument` offers the four tree-safe edits and
identity comparison. The Node model in pyro_runtime: `RootNode`, `EntityNode` (transform +
`behaviors`), `SpriteNode` (transform + image + region), `RectangleHitboxNode` /
`CircleHitboxNode` (position/size/angle/anchor + collisionType), `CustomNode` (TypeId +
transform + `Overrides fields` + behaviors), `UnknownNode`; `NodeTransform` = position, size,
scale, angle, anchor. `Overrides.put/reset` implement Override marking and *Reset to default*.
`RegistryType` does **not** carry label/parentType/supertypes — the catalog reads those from
`pyro.manifest.json` (spec 003), exactly as planned.

## 2. Riverpod layout (flutter_riverpod 3.3.2, codegen)

**Decision**: a family `Notifier` per open scene owns its `DocumentSession` privately; its
state is a small immutable view derived from `OpenDocument`; the session pushes through its
`changes` stream, captured in `build` with disposal wired to `ref.onDispose(session.close)`.
Codegen default `autoDispose` stays on for `documentProvider(sceneId)` (and `nodeProvider`);
`projectProvider`, `typeCatalogProvider` and the selection/camera state are `keepAlive`.
Mutations happen only via notifier methods (`transact`, `undo`, `redo`, `save`) called with
`ref.read(...notifier)`; the session object is never exposed. Tab close relies on autoDispose;
the save dialog pins the provider with a `KeepAliveLink` (pin/unpin) so the session survives
the tab widget unmounting mid-dialog.

**Rationale** (verified against riverpod 3.3.2 sources + riverpod.dev `/docs/concepts2/`):
all providers filter updates with `==`, so a no-op or coalesced transaction that returns an
equal snapshot notifies nobody; a `Notifier`'s instance survives `build` re-runs, so
long-lived owned resources (session, watchers) are legitimate fields; `ref.listen` inside a
provider counts as a listener, which keeps the document provider alive exactly while the
viewport's reconciler provider lives; `listenManual` is widget-side only.
**Alternatives rejected**: exposing the mutable session as provider state (mutations invisible
— `==` filtering hides them); `ChangeNotifierProvider`/`StateNotifierProvider` (moved to
`legacy.dart` in 3.0); `StreamProvider` of snapshots (drags `AsyncValue` ceremony into
synchronous local data); `keepAlive: true` on documents + manual invalidation (leaks sessions
and recovery timers whenever a close path is missed).

`nodeProvider(id)` — the narrow rebuild: a family provider that watches
`documentProvider(sceneId).select((s) => s.document)` and returns `document.node(id)` **itself**
(never a wrapper). Structural sharing makes untouched Nodes `identical`, and Riverpod's `==`
filter then skips notifying every row watching an unchanged Node. `select` is still the v3
idiom (verified: `Ref.select` was not replaced; `Mutation` is an unrelated experimental
button-status API). Keystroke discipline: text fields hold drafts in widget-local controllers
and commit through `transact` on commit/blur — never a provider write per character.

v3 gotchas the tasks must honor: guard async continuations with `ref.mounted` (Ref-after-dispose
throws `UnmountedRefException`); listeners of non-visible widgets are **paused** (a hidden
tab's reconciler stops receiving — mitigate below); `onDispose` must not touch other providers
(cancelling the session's timers/subscription is fine).

**Hidden-tab reconciliation** (the paused-listener consequence): the reconciler provider keys
its world to the visible document, and the viewport re-runs a **full reconcile from the
current document** whenever its tab becomes visible again (and on `resumeEngine`), so a paused
background tab can never show a stale world. The Flame game is `pauseEngine()`'d while its tab
is hidden (see §4 — `pauseWhenBackgrounded` is mobile-only).

## 3. Type catalog, compatibility check, project list

**Decision**: the catalog parses `lib/pyro.manifest.json` (format: spec 003's
`manifest-v1.md`) into freezed `TypeDescriptor`s, joins them with hand-written descriptors for
the built-in Node kinds (same shape, `TypeId`s like `entity`, `sprite`, `rectangleHitbox`,
`circleHitbox`), and evaluates the parenting rules as data (`parenting.dart`): hitbox entries
are not offered under the scene root (*Q115*); Manifest `parentType`/`supertypes` filter
custom children and Behaviors (*Q57*); `acceptsBehaviors: false` components get no Add
Behavior (*Q50*). The catalog provider watches the Manifest file (reusing `watchRecursively`)
and keeps the **last good** catalog when the file is unreadable, carries errors, or has a newer
`manifestVersion` (*Q105*), surfacing status for the status bar.

**Rationale**: one source of truth for Add lists, inspector rows, compatibility filtering and
Missing states (spec FR-012..014); the Runtime registry already proves the same data works.
**Alternatives rejected**: reading the Registry (code — the app must not import user code);
re-parsing annotations with the analyzer (embedding the generator violates the boundary).

**Runtime compatibility**: parse the project's `pubspec.lock` (new `yaml` dependency) for the
resolved `pyro_runtime` version; map it through a **built-in compatibility table**
(version → max readable `schemaVersion`; today every published runtime reads 1, and
`pyro_runtime.Scene.currentSchemaVersion` is the source for *this* workspace's value) →
`runtimeReadsUpTo` for `DocumentSession.save`. Missing/unreadable → `null` → save blocked
(*Q98*); too new → "Update Pyro" state (*Q105* parity). **Alternative rejected**: asking the
running game (none runs during editing; also *Q7*).

**Project list / editor settings**: one JSON in Pyro's application-support folder (recent
project paths, per-project `PrShellSizes`, recovery location already lives there), atomic
write, never in the project. **Alternative rejected**: per-project dot-files (pollutes the
user's repository).

## 4. Viewport composition (Flame 1.38.2 — version-verified)

**Decision**: one `EditorGame extends FlameGame` per open scene (created by a provider, one
`GameWidget`, own `FocusNode` — `autofocus` defaults to true and would fight the panels).
Editor camera = the game's `CameraComponent` with the default `MaxViewport`; pan/zoom by
writing `camera.viewfinder.position` / `.zoom` (clamped, zoom-to-cursor via before/after
`globalToLocal`), pixel-art via `component.paint.filterQuality = FilterQuality.none` (there is
no `filterQuality` constructor param in 1.38.2). Picking: `world.componentsAtPoint(point)`
(topmost-first). The overlay (selection outline, hover, move gizmo) lives as **viewfinder
children** — rendered in front of the world, transformed with it, and **hit-tested before
world children** (camera delivery order: viewport → viewfinder → world), so gizmo drags
intercept for free; gizmo parts use `DragCallbacks` and scale `1/zoom` for constant on-screen
size. Each gesture: `onDragStart` opens the coalesced transaction, updates write through the
reconciler live, `onDragEnd` commits.

**Rationale**: verified in the 1.38.2 source; the camera's hit-test order is the documented
1.3x behavior. **Alternatives rejected**: a second `World`/camera (more machinery, no gain);
Flame's `overlayBuilderMap` (Flutter widgets, right for menus, wrong for per-frame canvas);
a `CustomPaint` above `GameWidget` (duplicates camera math every frame);
`CameraComponent.withFixedResolution` (letterboxes — wrong for WYSIWYG editing).

**Version-corrected APIs** (old snippets will not compile — tasks must use these):
`ComponentSet` is gone (`children` is a `ReadOnlyOrderedSet`, `children.query<T>()`); the
legacy `Draggable`/`Tappable`/`Hoverable` mixins are gone — `TapCallbacks`,
`SecondaryTapCallbacks`, `DragCallbacks`, `ScrollCallbacks`, `ScaleCallbacks` are the API;
`HandleMouseButtons` does not exist; `Images.withCustomProvider` does not exist and
`game.images` aliases the global `Flame.images` — the viewport avoids all of them.

**Sprites from disk (Q79)**: implement pyro_runtime's `AssetSource` over the project folder —
`loadText` reads fresh; `loadImage` decodes bytes off the UI isolate
(`decodeImageFromList`/`instantiateImageCodec`) into a Pyro-owned `ui.Image` cache keyed by
path, releasing an old image only after every component drawing it has swapped (spike 3's
measured 75–200 ms behavior). A file watcher (debounced) rebuilds only the preview components
that recorded that path as a dependency. `SpriteComponent.sprite = Sprite(newImage)` swaps in
place — no add/remove churn.

**Frame budget**: never change `priority` during drags (re-sorts the sibling `OrderedSet`);
mutate `position`/`size`/`sprite` in place; placeholder boxes are hand-rolled
`PositionComponent`s (no per-Node `TextComponent` — TextPainter layout is the classic frame
killer; render the Type ID text only for selected/hovered/zoomed-in nodes);
`HasPerformanceTracker` + DevTools timeline in profile mode for the SC-004 numbers.
`pauseEngine()`/`resumeEngine()` around tab visibility (desktop has no lifecycle hook).

## 5. Panels on `pyro_ui` — contracts and gaps

**Decision**: the panels compose exactly the surveyed APIs: `PrEditorShell` (slots, sizes
reported-not-stored, `bottom: null` hides the dock), `PrTabs` (document style, dirty dot → ×,
built-in ⌘W), `PrPanel` + `PrSectionHeader`/`PrCollapsible`, `PrPropertyList`/`PrPropertyRow`
(`PrValueSource.codeDefault|overridden`, `onReset` = the ↺), `PrNumberProperty`,
`PrVector2Property` (aspect lock built in), `PrBoolProperty`, `PrDropdown` (composed into rows
by the app — there is no `PrDropdownProperty`), `PrAssetSlot`/`PrEntitySlot` (missing states,
drag acceptance, in-flight lighting built in), `PrTreeRow` (zone computation 25/50/25 done
inside; the app supplies `canAccept`/`onAccept` — the app decides "into its own subtree",
type rules, *Q84e*), `PrContextMenuRegion`/`PrMenuButton`/`showFsContextMenu` (there is no
widget named `PrContextMenu`), `showFsDialog` (`primary`/`secondary`/`destructive` maps the
Save/Cancel/Discard dialog), `PrBanner`, `PrEmptyState`, `PrSearchField`, `PrIconButton`
(`disabledReason`), `PrBadge` (`missing` kind), `PrStatusDot`. The node-kind → `PrIcons` map
is app code (by design): `layers` root, `box` entity, `image` sprite, `hitbox` hitboxes,
`circleDot` custom, `film` later.

**Number fields — FR-031 (resolved: clamp on commit)**: `PrNumberProperty` natively holds
typed out-of-range text invalid (error border, Esc reverts) and clamps scrubbing to
`min`/`max` — no out-of-range Override can ever be written through it. The Clarification of
2026-10-22 chose clamp-on-commit for typed values as well, so the app's field editor maps an
out-of-range typed commit to the clamped value (the widget's invalid-hold stays for text
that is not a number at all); FR-031 says exactly this.

**Gaps found** (candidates per *Q87*, each "works without it, propose before building"):
the tree *view* (flattening, keyboard nav, focus ownership) is app code by design; a
`PrMenuItem` disabled entry cannot show a reason tooltip (the one flagged delta in plan.md);
`PrPropertyRowScope` is unexported (app-composed dropdown/slot rows can't read row state —
fine unless implementation proves otherwise); `PrColorProperty` has no `readOnly` (Phase 4's
read-only Color rows are plain value displays in `PrPropertyRow`, per §14 item 5 anyway);
`PrRangeSlider` unexported (reachable via `PrNumberProperty(slider: true)` — enough); app
tests need the font-loading `flutter_test_config.dart` (task, not a gap).

**Alternatives**: none — this is the *Q87 rule (compose `Pr`; propose gaps; author decides).

## 6. Testing approach

**Decision**: reconciler tests are pure `flutter_test` unit tests (old/new `SceneDocument`
pairs → expected op lists, including identity-skip and the one-patch-for-1,000-Nodes case);
panel widget tests use the gallery's `pumpFs`-style harness plus the new font config, with
real mouse gestures for drag reparenting; catalog tests parse recorded manifests (including
`example/`'s) and every error shape; compatibility tests feed fixture `pubspec.lock` texts;
viewport preview components get `flame_test` where rendering matters. Determinism via the
existing helpers (memory FS, `fake_async`, `counterIds`, fixture scene builders — extended with
`generatedScene(1000)` for budget smoke checks, already present in benchmarks).

**Rationale**: constitution V (Heavy layers ship with tests in the same change) and the spec's
FR-039. **Alternatives rejected**: golden tests for panels this phase (the design views aren't
generated yet — the "New patterns" pass comes with them; goldens follow the design review).

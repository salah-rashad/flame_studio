# Research: Runtime

Phase 0 of [plan.md](plan.md). Each entry is a decision the plan relies on, why it was made, and
what else was considered. Spike #1 (`spikes/01_play_hotswap/`) proved the Hot-swap mechanism and
spike #3 (`spikes/03_disk_render/`) the asset seam; their findings are cited as "spike #1" and
"spike #3" (ARCHITECTURE.md). Facts marked *read* were checked on 2026-10-20 in the sources of
the versions the workspace lock resolves: flame 1.38.2, flame_behaviors 1.4.0, flame_test 2.3.1.
They were read, not run: this planning session had no Flutter SDK, so the first implementation
task re-checks them with a test (tasks.md).

## R1. Toolchain and dependencies

**Decision:** stay on the repository's Flutter 3.44.2 pin (Q94) and the lock's flame 1.38.2,
flame_behaviors 1.4.0 and flame_test 2.3.1. `pyro_runtime` gains **no** dependency (FR-033): no
hashing package, no image codec.

**Rationale:** the Runtime ships in every game (constitution II). Everything it needs is in Flame,
Flutter and the Dart SDK: `AssetBundle` for reads, Flame's `Images` for decoding, the Scene
format's strict JSON reader for animation files (R7).

**Alternatives considered:** `package:crypto` for a SHA-256 content hash (a new dependency in
every game, for a comparison R11 does exactly without it).

## R2. What `PyroScene` is

**Decision:** `PyroScene extends Component`. It stands for the root Node, so the root's children
are its children. An entity reference to the root resolves to the `PyroScene`. It's built with
`PyroScene.load` only; the constructor is private.

**Rationale:** the root has no transform in the Scene format (spec 001), so a `PositionComponent`
would invent a position nobody edits. A plain `Component` parent leaves the Nodes in world
coordinates, which is what Pyro's viewport shows. §6.2's example (`world.add(scene)`) works
unchanged.

**Alternatives considered:** `PositionComponent` (moving a whole Scene is game code's choice:
wrap it); a mixin on the game (§6.2's non-invasive rule, *Q30*).

## R3. Built-in Node kinds as Flame components

*Read.* `PositionedEntity` is `abstract` in flame_behaviors 1.4.0. `RectangleHitbox` and
`CircleHitbox` set `shouldFillParent` when both their size (radius) and position are null.
`Behavior<Parent extends EntityMixin>` mixes in `ParentIsA<Parent>`, which checks the parent only
with an `assert` in `onMount`.

**Decision:**

| Kind | Component |
|---|---|
| `root` | the `PyroScene` (R2) |
| `entity` | `PyroEntity`, a new public, concrete `PositionedEntity` subclass with no behavior of its own |
| `sprite` | Flame's `SpriteComponent` with `Sprite(image, srcPosition:, srcSize:)` |
| `rectangleHitbox` | `RectangleHitbox(position:, size:, angle:, anchor:, isSolid:, collisionType:)` |
| `circleHitbox` | `CircleHitbox(radius:, position:, anchor:, isSolid:, collisionType:)` |
| `custom` | `RegistryType.create()` |

Hitboxes always get an explicit position and size or radius, so they never fill their parent. A
named anchor maps to Flame's constant of the same name, and a custom one to `Anchor(x, y)`.
`NodeCollisionType` maps to `CollisionType` by name. Each component is created with its final
values, not mutated after construction.

**Rationale:** a public `PyroEntity` lets game code write `find<PyroEntity>('goblin_1')` and
`findAll<PositionedEntity>()`. It's the one new class the Scene's `entity` kind needs.

**Alternatives considered:** an anonymous private subclass (game code couldn't name its type);
`Entity` (no transform, but the Scene format gives entities one).

## R4. The four-pass build

**Decision:** an internal `SceneBuilder` turns a decoded `Scene` into a `BuiltScene`. The
`BuiltScene` holds the root's child components, the lookup index (R10) and the files read (R11).
Nothing is added to a live tree until all four passes succeed (FR-003, FR-004):

1. **Construct.** Walk the tree depth first in `childIds` order. For each Node, look up its kind,
   or its Type ID in the Registry, check the role (FR-007), apply the unknown-type policy (R9),
   and create its component and its Behaviors' components. Built-in kinds are created complete
   (R3). This pass also collects every asset path the Scene uses.
2. **Configure.** Load every distinct asset concurrently (`Future.wait`): sprite images, `Sprite`
   images and animation files with their images. Then set the transform of positioned Custom
   components and convert and assign every non-reference Override (R5). Reference Overrides are
   only checked for shape in this pass.
3. **Resolve.** Assign entity-reference Overrides from the Node ID → component map (FR-014).
4. **Attach.** Check each Behavior's parent (R6), then `add` Behaviors and child components in
   Scene order. Adding to a parent that isn't mounted queues the child in Flame, so no `onLoad`
   runs until the `PyroScene` is added to a game (*read*: `Component.add` on an unmounted parent
   only enqueues).

Errors from user code (a constructor, a setter) are caught per Node and rethrown as
`SceneLoadException` with the Scene, Node and Type ID, keeping the cause and stack (FR-017,
FR-018).

**Rationale:** separating the passes is what §6.2's "◇ proposed" order needs. Building into a
detached value makes failed loads and failed Hot-swaps leave nothing behind (FR-004, FR-026), and
loading assets in one concurrent batch keeps load time down to the slowest asset rather than
their sum.

**Alternatives considered:** building straight into the `PyroScene` (a failed Hot-swap would
leave a half-built Scene); loading each asset as its Node is configured (serial I/O).

## R5. Converting Override values

**Decision:** one conversion per `FieldType`, from the written form (spec 001 contract, amended
by R13). The result is checked with `RegistryField.accepts` before `set`:

| Field type | Accepts | Becomes |
|---|---|---|
| `int` | an `int`, or a finite `double` with no fraction | `int` |
| `double` | any finite number | `double` |
| `bool`, `string` | a boolean, a string | the same |
| `enumeration` | a string naming one of `RegistryField.values` | that value |
| `vector2` | a list of exactly two numbers | `Vector2` |
| `color` | `"#"` and exactly eight hex digits, either case | `Color(0xAARRGGBB)` |
| `imagePath` | `{"asset": path}` | `ImagePath(path)`, not loaded |
| `sprite` | `{"asset": path}` | `Sprite(image)`, the whole image |
| `spriteAnimation` | `{"asset": path, "animation": name}` | the animation (R7) |
| `entityRef` | `{"ref": id}` | the target's component (pass 3) |
| any, when nullable | `null` | `null` |

Anything else is a `SceneLoadException` naming the Scene, the Node, the Type ID, the field, the
written value (shortened to 80 characters) and the expected Field type (FR-011). An Override for
a field the `RegistryType` doesn't list is skipped and collected for one debug warning per load
(FR-012).

**Rationale:** the Registry deliberately leaves conversion to the Runtime (spec 003 FR-022).
Lowercase hex is accepted on read because hand edits happen and nothing is lost. Pyro always
writes upper case.

## R6. Behavior parent checks: a Registry extension

*Read:* `ParentIsA` checks the parent only by `assert` in `onMount`, which is too late and debug
only. Nothing in Dart can recover `T` from a `Behavior<T>` instance without code generation.

**Decision:** `RegistryType` gains `acceptsParent`, a `bool Function(Component parent)?`. It's
non-null for Behaviors and null for Custom components. The Generator emits
`acceptsParent: (parent) => parent is Enemy` from the Behavior's type argument, the same
information the Manifest's `parentType` already holds (spec 003 FR-013a). For `Behavior` or
`Behavior<EntityMixin>` it emits `parent is EntityMixin`. Pass 4 checks two things: the Node's
component is an `EntityMixin` ("can hold Behaviors"), and `acceptsParent` accepts it (FR-008).

**Rationale:** spec 003's Assumptions left the contract open for #8 to extend. The Generator
already knows the parent type, so this is one more line per Behavior in `pyro.g.dart`. The
Registry contract change and the Generator change are made in the same commit, so the committed
`fixture_game` Registry never stops compiling.

**Alternatives considered:** relying on the mount `assert` (release builds would silently attach
the wrong Behavior and crash later on `parent`); a parent Type ID string matched against
supertypes (the Registry doesn't carry supertypes, and built-in kinds have none).

## R7. Animation files

**Decision:** a reader for `.anim.json` (§7.2) in `pyro_runtime/lib/src/animation/`, next to the
Scene format and built on its strict JSON reader (duplicate keys refused, line and column in
errors). Its contract is [contracts/anim-file-v1.md](contracts/anim-file-v1.md). The reader:

- refuses a newer `schemaVersion` (`UnsupportedSchemaVersion`, as for Scenes);
- needs `image`, `grid.cellSize` and `animations`; `grid.offset` and `grid.spacing` default to
  `[0, 0]`;
- needs, per animation, non-empty `frames` and exactly one of `stepTime` (> 0) or `stepTimes` (all
  > 0, as many as `frames`); `loop` defaults to `true`, Flame's default;
- ignores keys it doesn't know (it never writes the file; preserving them is the writer's job,
  which comes with the grid slicer in v0.1.1).

Frame `i` is the cell at column `i % columns`, row `i ~/ columns`, where `columns =
floor((imageWidth − offset.x + spacing.x) / (cellSize.x + spacing.x))`. A frame outside the image
is an error naming the file, the animation and the frame. The result is
`SpriteAnimation.spriteList` (one `stepTime`) or `SpriteAnimation.variableSpriteList`
(`stepTimes`) (*read*: both factories exist in flame 1.38.2).

Each Scene build parses an animation file once, however many fields use it, and keeps its text
for the Hot-swap comparison (R11).

**Rationale:** the format was fixed in §7.2 so the Runtime could read it before Pyro writes it.
Reusing the Scene format's reader gives the same error quality for free.

## R8. Asset source

*Read:* `Images({String prefix = 'assets/images/', AssetBundle? bundle})` falls back to
`Flame.bundle`. `Images.load` caches by key, and a failed load stays cached (spike #3 finding 3).

**Decision:** an `abstract interface class AssetSource` with two methods, `loadText(AssetPath)` and
`loadImage(AssetPath)`, keyed by project-relative path (FR-030). `AssetSource.bundle([AssetBundle?
bundle])` is the default. It reads text with `bundle.loadString(path, cache: false)` and images
through its own `Images(prefix: '', bundle: bundle)`, so nothing goes through `Flame.images`,
`Flame.assets` or `Flame.bundle`. A failed image load is cleared from that cache before the error
is rethrown, so a later Hot-swap retries the file. `PyroScene.load` creates one bundle source per
Scene when the caller passes none, and keeps it for the Scene's lifetime, Hot-swap rebuilds
included (FR-031; images aren't reloaded, *Q72*). A caller-supplied source (Pyro's disk source in
#4, a test source) owns its own caching (*Q79*).

**Rationale:** spike #3 finding 1 showed the seam is just "which bundle, and who owns the image
cache". Two methods keep Pyro's disk source free to record every file a Node reads (*Q79*).
`cache: false` matters for Hot-swap: the Runtime keeps its own copy of the text for comparison,
and a fresh read is what flutter_tools' eviction already arranges (spike #1 finding 1).

**Alternatives considered:** passing an `AssetBundle` plus an `Images` (two parameters where Pyro
needs one seam, and `Images` disposes on `clear`, which Q79 rejects for the viewport); the game's
`images` cache (its `assets/images/` prefix doesn't fit project-relative paths, and clearing it
would hit the game's own images).

## R9. Unknown Type IDs and Node kinds

**Decision:** `enum UnknownType { error, skip }`, defaulting to `error` (*Q58*). Under `error`,
pass 1 throws on the first unknown Type ID, role mismatch or `UnknownNode`. Under `skip`:

- an unknown Behavior is dropped and its Node kept;
- an unknown Custom component or Node kind is dropped with its subtree;
- references to dropped Nodes resolve to `null`.

All of these go into one debug warning per load, listing Node names, IDs, Type IDs or kinds, and
referencing fields (FR-016). A role mismatch (a Behavior's Type ID on a Node) is always an error:
it means the Scene is wrong, not that the code is missing a class.

**Rationale:** dropping the subtree is the only choice that never attaches a child to a parent the
Scene didn't give it.

## R10. Lookups

**Decision:** the `BuiltScene` keeps a flat list of entries in tree order (depth first,
`childIds` order): Node ID, name, tags, component, parent entry. `find` and `findAll` scan it. A
path splits on `/`. An entry matches when its name equals the last segment and its nearest
ancestors' names equal the earlier ones, in order. A leading `/` additionally needs the first
segment's Node to be a child of the root. `find<T>` collects every match. With none, or more than
one, it throws a `StateError` naming the Scene and the query; the ambiguous case lists each
match's full path and suggests `findAll` or a longer path. With exactly one that isn't a `T`, it
throws naming the Node, its runtime type and `T`. `findAll<T>({String? name, String? tag})`
applies every filter given and returns a new list.

**Rationale:** lookups run a handful of times per load or Hot-swap, so a linear scan over 1,000
entries (microseconds) beats maintaining indexes. The list exists before mounting, so lookups
work straight after `load` (FR-022). Ambiguity is decided by name alone, never by `T`, so adding
a second Node of another type with the same name can't silently change which Node a lookup
returns.

## R11. Hot-swap

*Read:* `Component.onHotReload()` (`@mustCallSuper`) is called from `GameWidget.reassemble` →
`FlameGame.onHotReload` → `handleHotReload` on every child that is loading or loaded. It's only
called in debug mode.

**Decision:** `PyroScene.onHotReload` calls `super.onHotReload()`, then, inside
`if (kDebugMode)`, chains `_checkForChanges()` onto a private `Future` so checks never overlap
(FR-027). The check:

1. re-reads the Scene file and every animation file the current build read, through the same
   asset source;
2. compares each text with the text kept from the build (`String ==`). If all are equal, it stops
   (FR-024);
3. otherwise decodes and builds a new `BuiltScene` (R4) with the same Registry, policy and source.
   On any error it prints one debug error naming the Scene and the cause, and keeps the old Nodes
   (FR-026);
4. on success swaps synchronously: `removeAll` of the old root children, `addAll` of the new ones,
   index and kept texts replaced. Then it starts stale-reference tracking (R12) and calls
   `onReloaded(this)` (FR-025).

**Rationale:** keeping the text and comparing it exactly is simpler than hashing and can't
collide. The memory cost is one copy of the files (a 1,000-Node Scene is ~365 KB, ARCHITECTURE.md
"Scene format"). Comparing before decoding makes a no-op reload cost a read and a `memcmp`-like
compare (SC-004). Spike #1 showed `rootBundle` serves the new bytes after flutter_tools'
eviction.

**Alternatives considered:** `String.hashCode` (collisions, and still needs the read); hashing
with `package:crypto` (R1); rebuilding unconditionally (an IDE's Dart-only reload would reset
game state, which *Q67* rules out).

## R12. Stale-reference warning

*Read:* `PositionComponent.transform` is a `Transform2D`, which is a `ChangeNotifier`, and every
transform setter notifies. `Component.mounted` returns a future that completes on the next mount
when the component isn't mounted.

**Decision:** in debug builds only, after a swap, each removed Node component is watched until its
first use:

- **transform changed** (positioned components): a listener on `transform`;
- **added to a tree again**: `component.mounted.then(...)`;
- **passed to a `PyroScene` API**: `PyroScene` v0.1 has no API that takes a component, so there
  is nothing to check yet. Any later API that takes one consults the same watched set.

The first use prints one warning naming the Scene, the Node (name and ID) and `onReloaded`. Then
that Node's watchers are detached (FR-028). Only the latest removed generation is watched: the
next swap detaches all remaining watchers before it watches its own, so memory doesn't grow with
reloads. Components of the current version carry no listener.

**Rationale:** the clarified scope (spec Clarifications, Q2: A). These are the uses Flame lets us
observe without wrapping user classes, and they cover the common "game code moves a stale
player" case.

**Alternatives considered:** per-frame checks (constitution III forbids per-frame work); proxies
or wrappers around user components (not possible without changing their types).

## R13. Scene format amendment: `{"asset": path, "animation": name}`

**Decision:** `AssetRef` gains an optional `animation` (a non-empty string). `AssetRef.fromJson`
accepts exactly `{"asset"}` or `{"asset", "animation"}`, each a non-empty string. Any other shape
is not an `AssetRef` and stays a plain JSON value, as before. `toJson` writes `animation` only
when set; the canonical writer already sorts it after `asset`. `schemaVersion` stays 1 (spec
FR-034): no released file uses the form, and spec 001's FR-020a bumps only for data an older
reader would misread. The current reader keeps such a value verbatim as plain JSON, so nothing is
lost.

The Field type → written form table changes in three places in the same commit:
`specs/001-scene-format/contracts/scene-file-v1.md`, project-plan §7.1 and
`specs/003-generator/research.md` R5.

## R14. Release builds

**Decision:** every Hot-swap and stale-reference path is behind `kDebugMode` (a `const`), so
release and profile AOT builds drop it. SC-006 is checked by hand on the reference Mac. A
throwaway macOS app that loads `fixture_game`'s Scene is built with `flutter build macos
--release`, and the compiled app is searched for the text of the Hot-swap debug error ("couldn't
Hot-swap"), which only that path holds (quickstart §5). `fixture_game` has no platform runner,
and the committed macOS target arrives with Phase 3's `example/`. The per-frame cost is
zero by construction, because `PyroScene` overrides no `update` or `render`.

**Alternatives considered:** a CI job building a release app on every push (minutes of macOS
runner time for a property that only changes when Hot-swap code changes).

## R15. Tests

**Decision:**

- **Harness:** `flame_test`'s `testWithFlameGame` / `FlameGame` plus `game.ensureAdd(scene)`.
  `test/support/memory_asset_source.dart` serves text from a map and images made in the test with
  `PictureRecorder` → `toImage` (no image files, no decoding), and counts every read for the
  FR-031 and Hot-swap tests.
- **Registry:** `test/support/test_registry.dart`, written by hand. It has Behaviors and Custom
  components covering every Field type, a Behavior with a narrow parent type, a component without
  `EntityMixin`, and components whose constructor or setter throws.
- **Fixture Scenes:** `test/fixtures/loader/*.scene.json` (and `*.anim.json`), one per scenario and error case in User
  Stories 1–3. Loaded through the memory source.
- **Hot-swap:** change the memory source's text, then call `game.onHotReload()`, the path
  Flutter's reassemble takes (*read*). SC-003 alternates 100 changed and unchanged reloads.
- **End to end:** `packages/pyro_generator/fixture_game` gets one Scene and a `flutter test` that
  loads it with the real generated Registry and `AssetSource.bundle()`. This is the pattern #12
  reuses for `example/`.
- **Benchmark:** `benchmark/load_benchmark_test.dart`, run with `flutter test` on the 1,000-Node
  Scene that `scene_codec_benchmark.dart` generates, with a memory source. It reports load,
  no-op check and rebuild medians (SC-004). `flutter test` runs JIT with asserts, so the numbers
  are an upper bound on what a profile build would show.

**Rationale:** constitution V, deterministic tests with no real files, network or clock.

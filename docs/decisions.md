# Pyro — Design Decisions

Outcome of the design grilling session (2026-10-15/16). Seed for `ARCHITECTURE.md`.
Question numbers (Q1…Q42) refer to the session transcript. Q43–Q73 come from the plan review
(2026-10-16, §9 below); rows they changed carry an *Amended by* note. Q74–Q75 come from
spike #1, Q76–Q77 from spike #2, Q78–Q80 from spike #3, Q81 from the Attach design review
(2026-10-17), Q82 from the feedback-latency review (2026-10-17), Q83 from the UI package
split (2026-10-17), Q84 from the UI components plan (2026-10-17), Q85 from the design-prompts sync
(2026-10-18), Q86 from the maintainers' answer on the name (2026-10-18).

## 1. Product

| # | Decision |
|---|---|
| Q1 | **Open-source community tool** for Flame developers in general. |
| Q2 | v1 core: **scene editor + sprite/animation setup + hitboxes**. No tilemap editor (use Tiled), no visual scripting, no code editor/IDE. |
| Q5 | Built **solo, evenings and weekends**. No target game or deadline. |
| Q11 | **MIT license**, under the author's name. Talk to the Flame maintainers (Discord) early. |
| Q36 | App name **"Flame Studio"** with a "community project, not affiliated with the Flame team" note — *after* asking the maintainers. Fallback: a distinct brand for the app. Packages: `flame_studio_runtime`, `flame_studio_generator` (both unclaimed on pub.dev as of 2026-10-16). Decide before the first `pub publish`. *Amended by Q44: adds `flame_studio_annotations`. Superseded by Q86: the Flame team reserves the name; the app is **Pyro**.* |

## 2. Architecture

| # | Decision |
|---|---|
| Q3 | **Data-driven.** Pyro owns scene data; users write logic in Dart. A runtime package loads scenes into Flame. |
| Q7 | **Standalone studio app.** It never runs user code. It builds and launches the user's game as a child process. A **live bridge** (Pyro ↔ running game over the Dart VM service / websocket) arrives around v0.4. *Amended by Q43: the IDE attaches to Pyro-run game.* |
| Q38 | User types are discovered by **`pyro_generator`** (source_gen), which writes both the **runtime registry** (factories + setters, shipped in games) and a **types manifest (JSON)** that the studio reads (exact output path to be settled in the v0.0 spike — see `project-plan.md` §7.3; *amended by Q68: both in `lib/`, committed*). One introspection codebase, always in sync with the user's SDK. No analyzer embedded in the studio. |
| Q12 | `source_gen` generator, not `reflectable`. Built-in Flame components use **hand-written descriptors**. Everything sits behind a `PyroTypeRegistry` interface (*renamed by Q52: Pyro side is the **Type catalog**; **Registry** means only the generated runtime code*). v1 field types: `int`, `double`, `bool`, `String`, enums, `Vector2`, `Color`, asset references, entity references. |
| Q39 | Pyro uses the **user's installed Flutter/Dart SDK** (PATH / `FLUTTER_ROOT` / fvm), overridable in settings. No bundled SDK. |
| Q18 | `pyro_runtime` supports the **latest stable Flame minor** until Pyro 1.0, then current + previous. Flutter stable only. Pyro bundles its own Flame for rendering built-ins; the scene format must never depend on a Flame version. *Amended by Q80: Flame 2.0.* |

## 3. Scripting model

| # | Decision |
|---|---|
| Q6 | **Unity-style entity + behaviors first**, custom `Component` subclasses also supported. Custom components with their own rendering show as **placeholders** (optional `@PyroComponent(preview: ...)` image). |
| Q13 | Depend on **`flame_behaviors`**. |
| Q16 | **No user code runs in the editor.** The viewport renders from data only. (`@RunInEditor` dropped; the live bridge replaces it.) |
| Q32 | Code/data drift: **keep unknown data verbatim and flag it** ("Missing script: Patrol"), convert trivial type changes with a warning. `@RenamedFrom` later. Never silently destroy data. *Amended by Q45: `@RenamedFrom` dropped, explicit `id:` covers renames; Q52: "Missing behavior", not "Missing script".* |

## 4. Data & formats

| # | Decision |
|---|---|
| Q14 | Scenes are **JSON**, one file per scene, pretty-printed, **sorted keys**, stable **UUID per node**, `schemaVersion` at the top. Merge-friendly. |
| Q35 | **Forward migration guarantee** from day one: any scene from any earlier release loads in later ones (migration chain of pure functions, each with a fixture test). |
| Q15 | **Prefabs as instancing** in v0.2 (`{prefab: "...", overrides: {}}`); overrides later — format ready now. |
| Q27 | Assets referenced by **project-relative path**; renames done in Pyro rewrite all references; missing-asset warnings. Animations live in their own **`.anim.json`** files. |
| Q8 | Sprites: **grid slicer** + **Aseprite import** (+ TexturePacker). No drawing tools. |
| Q9 | Collision: **Flame's built-in hitboxes** first; Forge2D later as a plugin. |
| Q10 | **Tiled maps as scene nodes** (reference `.tmx`, rendered in viewport); object-layer → entity conversion later. *Amended by Q78: loaded through the Runtime's own Tiled loader.* |

## 5. Editor internals

| # | Decision |
|---|---|
| Q21 | The **document is the source of truth**; the Flame viewport is a projection of it. |
| Q22 | **Snapshot undo** over an immutable document with structural sharing. All edits go through named transactions (`doc.transact('Move', ...)`); continuous gestures are **coalesced**. |
| Q23 | **Flat normalized map** `id → node` (`parentId`, ordered `childIds`), built with **freezed**. |
| Q24 | Viewport sync through a **reconciler** that diffs documents by node ID (identity checks skip unchanged nodes) and patches components. |
| Q25 | **Selection is not undoable** and lives outside the document. |
| Q26 | **Riverpod** for UI state (the author is learning it on this project). |
| Q20 | Panel layout: **fixed resizable panels** (no docking in v1). Visual design produced with **Claude Design** from the prompts in `claude-design-prompts.md`, then implemented by hand in Flutter. *Amended by Q83: implemented in `pyro_ui`.* |

## 6. Workflow & integration

| # | Decision |
|---|---|
| Q29 | A button **"Add Pyro to this project"** adds the runtime + generator dependencies, `build.yaml` and `scenes/`. **No other changes to the user's project** (no entrypoint, no macOS target, no entitlements). *Amended by Q53 (assets/scenes/ + pubspec entry), Q48 (build_runner ≥ 2.14), Q60 (opt-in `launch.json` after a diff).* The studio runs `build_runner watch` and `flutter run --machine` as child processes and shows their output. |
| Q30 | Game code: **non-invasive** `PyroScene.load('scenes/x.scene.json')` → add to any `World`. Lookup by **name** and **tag**; typed accessors later. Debug-only reload hook for hot-swap. *Amended by Q51, Q58, Q66, Q71.* |
| Q17 | **Play = `flutter run --machine` on the chosen device.** On save, Pyro triggers a hot reload (which syncs the changed scene file) and the runtime reloads the scene in debug builds. *Amended by Q66: via Flame's `onHotReload`, no custom service extension.* |
| Q41 | **Device dropdown** in the toolbar (from `flutter devices`), remembered per project. |
| Q31 | Editor loads assets **from disk** via an `AssetSource` abstraction; games load from the **bundle**. Pyro keeps `pubspec.yaml` `assets:` in sync (append only, show diff first time). *Confirmed by spike #3; amended by Q79: what Pyro's `AssetSource` is.* |

## 7. Platforms, repo, releases

| # | Decision |
|---|---|
| Q4 | Pyro: **macOS first-class**; Windows/Linux built in CI, best effort until v0.3. The user's game can target anything. |
| Q28 | **One repo, Dart pub workspaces**: `pyro_runtime` (pub, incl. annotations), `pyro_generator` (pub), `pyro` (desktop app, released as binaries), `example/`. *Amended by Q44 (`pyro_annotations`) and Q83 (`pyro_ui`).* |
| Q40 | **Signed + notarized** builds on **GitHub Releases** for v0.1 (needs an Apple Developer account, $99/yr); **auto-update** (Sparkle/WinSparkle) in v0.2; Homebrew/winget later. |
| Q33 | Tests: heavy on **document/history/serialization/reconciler unit tests**, **generator golden tests** (registry + manifest), **runtime loader tests** (`flame_test`); light widget tests; CI on macOS/Windows/Linux plus a sign/notarize job. |
| Q37 | v0.1 launch: README, `example/` game, **2–3 min demo video/GIF**, Getting Started (incl. install & Gatekeeper), **`ARCHITECTURE.md`** (this document + the *why not reflectable* / *why standalone* rationale). |

## 8. Milestones

> *Superseded by the plan review: current milestones are in `project-plan.md` §14 (Q65, Q69).*

**v0.0 — de-risking spike (2–3 evenings, throwaway code, findings go into `ARCHITECTURE.md`)** (Q42)
1. Edit a scene JSON → hot reload through `flutter run --machine` → scene reloads on an iOS simulator / Android emulator.
2. `build_runner watch` refreshes `types.json` within a few seconds on a mid-size project.
3. Pyro renders a sprite and a Tiled map loaded from a project folder on disk.
If (1) fails, the live bridge moves into v0.1.

**v0.1 — first public release (macOS)** (Q34)
1. App shell: project list, open project, SDK detection (fvm-aware), "Add Pyro to this project"
2. Hierarchy: add / delete / rename / reparent (drag) / duplicate
3. Data-driven viewport: pan/zoom, grid, click-select, move/rotate/scale gizmos, snapping
4. Inspector: transform + all `@Editable` field types from `types.json`
5. Built-in nodes: entity, sprite, animated sprite, rectangle/circle/polygon hitboxes; placeholders for custom components
6. Behaviors: attach/remove, edit fields, Missing-script / Missing-asset warnings
7. Assets: browser, **grid slicer** → `.anim.json`, `pubspec.yaml` asset sync *(cut line)*
8. Document: save/load, undo/redo with coalescing, `schemaVersion` migrations
9. Play: device dropdown, build/log console, **scene hot-swap on save** *(cut line)*
10. Packages: `pyro_runtime`, `pyro_generator`, `example/` game
11. Signed + notarized `.dmg` on GitHub Releases

If v0.1 runs past ~4 months, ship without items 7 and 9 and release them as v0.1.1.

**Roadmap**
- **v0.2:** Aseprite import, prefab instancing, Tiled map nodes, auto-update
- **v0.3:** Windows + Linux first-class, Homebrew / winget
- **v0.4:** live bridge to the running game (select/tweak live, exact custom rendering), prefab overrides, `@RenamedFrom`, typed scene accessors
- **Later:** Forge2D, particle/effects editors, docking panels

## 9. Plan review (2026-10-16)

Grilling of `project-plan.md`. Vocabulary in [`../GLOSSARY.md`](../GLOSSARY.md); ADRs in [`adr/`](adr/).

| # | Decision |
|---|---|
| Q43 | **Pyro runs the game; the IDE attaches** to it for breakpoints and code hot reload, as in Unity. ([ADR 0001](adr/0001-studio-runs-the-game-ide-attaches.md)) *Confirmed by spike #1, with the workarounds in Q74.* |
| Q44 | Annotations move to a **pure-Dart `pyro_annotations`** package with no dependencies. The Runtime re-exports it; the generator depends only on it (`TypeChecker.fromUrl`), never on the Runtime. |
| Q45 | Scenes name user types by **Type ID = class name**, or an explicit `id:` in the annotation. The generator **fails the build on duplicate Type IDs**. `@RenamedFrom` is dropped. ([ADR 0002](adr/0002-type-ids-are-class-names.md)) |
| Q46 | **Only Overrides are stored**; code defaults apply to every Node without one. Any value the user explicitly sets is an Override, even if it equals the default. Inspector marks Overrides and offers *Reset to default*. ([ADR 0003](adr/0003-scenes-store-only-overrides.md)) |
| Q47 | Scene files persist **only ordered `childIds`**; the root is an ordinary Node; `parentId` is derived on load; the loader repairs or flags inconsistencies. |
| Q48 | Setup requires **build_runner ≥ 2.14**. Pyro probes build_runner's lock before starting a watcher; if one is running (or takes over later) it uses it and shows "External build_runner". *Amended by Q77: re-probe after a takeover exit.* |
| Q49 | Pyro checks the project's resolved `pyro_runtime` version (`pubspec.lock`) against a built-in compatibility range: *Upgrade runtime* or *Update Pyro*. It never writes a `schemaVersion` the project's Runtime can't read. |
| Q50 | Custom components are `"kind": "custom"` + `"type"`; they must extend `PositionComponent` in v1; they accept Behaviors only if they mix in `EntityMixin` (`acceptsBehaviors` in the Manifest). |
| Q51 | Node names are not unique. `find` throws on ambiguity and points to `findAll` or a path lookup; the hierarchy warns about duplicate sibling names. |
| Q52 | Vocabulary: **Registry** (generated runtime code) vs **Type catalog** (Pyro); **Missing behavior / Missing component** (not "script"); **Node kind / Type role / Field type** instead of bare "kind". |
| Q53 | Scenes default to **`assets/scenes/`**. Saving or importing into an undeclared folder (incl. subfolders, which Flutter doesn't include) appends it to `pubspec.yaml`. No config file. |
| Q54 | **One `.anim.json` per spritesheet.** |
| Q55 | **Recovery file only**, no real autosave; undo history not persisted. |
| Q56 | Entity references only to Nodes in the same scene and not inside a Prefab instance (v1). |
| Q57 | The Manifest records every annotated type's **supertypes**; built-in Node kinds declare theirs by hand; reference fields accept subtypes and may target built-in types. |
| Q58 | Runtime **throws on an unknown Type ID** (naming scene, Node, Type ID); `onUnknownType: skip` opt-out. |
| Q59 | **CI contract test**: generator on `example/` → Manifest golden → load every `example/` scene with `flame_test` against the generated Registry. |
| Q60 | **Attach**: *Attach debugger* button copies the VM service URL (+ VS Code / Android Studio guides); a **fixed DDS port per project**, auto-picked on first Play and remembered in Pyro's settings (new port + notice if busy); opt-in *Add VS Code attach config* writes `launch.json` after a diff. *Amended by Q75: always with `--disable-service-auth-codes`; then by Q81: authentication stays on, no fixed DDS port, and the attach config reads the current URI from a file Pyro writes.* |
| Q61 | Pyro **hot-reloads on Dart changes** in `lib/` after build_runner is idle; setting, on by default. |
| Q62 | Device dropdown lists running devices plus emulators/simulators and boots one on selection; desktop devices only if the project has that target. |
| Q63 | One Pyro window per project, one running game per project. Quitting/closing stops the game (with confirmation); other exits are detected and shown as "Game stopped". |
| Q64 | Running from the IDE without Pyro is supported with fewer features: scenes load, IDE hot restart picks up scene changes, no Hot-swap or Console. |
| Q65 | v0.1 cuts to v0.1.1: grid slicer + animated sprite Node kind, rename with reference rewriting, multi-select "mixed" values. Play stays in v0.1. Add a **developer preview** (notarized, unpolished, Flame Discord) before v0.1. *Preview scope amended by Q82 (early preview, built from source).* |
| Q66 | Hot-swap uses **Flame's `onHotReload`** (Flame ≥ 1.36) after `app.restart`; flutter_tools already syncs and evicts changed assets. No custom service extension. |
| Q67 | Hot-swap **rebuilds the whole scene, only if its content hash changed**. Node-level patching (with the scene diff shared between Runtime and reconciler) in v0.4. |
| Q68 | Registry and Manifest are both written to **`lib/`** (`pyro.g.dart`, `pyro.manifest.json`) and **committed**; CI uses `build_runner build --only-check`. *Amended by Q76: `--only-check` only on Flutter ≥ 3.47; `git diff` check below.* |
| Q69 | Spike #1 rewritten: Play → Hot-swap on simulator, emulator and physical phone; Dart-only reload doesn't rebuild; IDE attach + hot reload alongside Pyro (the deciding test for Q43). |
| Q70 | **Web devices hidden** from Play in v0.1; best effort from v0.3 or later. |
| Q71 | After a Hot-swap, game code re-runs lookups in a **`PyroScene` `onReloaded` callback**; debug builds warn on first use of a removed Node. *Accepted "for now"; revisit after the early preview (Q82).* |
| Q72 | The Hot-swap hash covers the scene, its `.anim.json` files and (v0.2) its prefabs, not images. Image changes show a *Restart game* toast (hot restart). |
| Q73 | The **developer preview keeps full scope** (items 0–9, 11, 15 of `project-plan.md` §14, ~62 evenings, ~5 months) rather than being trimmed to land at ~3–4 months. *Superseded by Q82.* |
| Q74 | **Hot-swap while an IDE is attached** (spike #1 outcome, 2026-10-16): Pyro runs `flutter run` with the hidden `--project-root` pointing at a **symlink to the project with a different folder name** (`<app support>/run/<project-id>/<name>-pyro`), so its DevFS doesn't share a name with the IDE's and isn't deleted when the IDE attaches. Before every reload it **re-points the engine's asset directory** at its own DevFS (`_flutter.setAssetBundlePath`); if that fails, it reloads, re-points, evicts the changed scene files and reloads once more. Both are private flutter_tools/engine interfaces, so they are re-checked on every Flutter stable release; the old fallback (Pyro stops reloading while an IDE is attached) stays as the escape hatch. ([ADR 0001](adr/0001-studio-runs-the-game-ide-attaches.md), [`ARCHITECTURE.md`](ARCHITECTURE.md#spike-1--play-hot-swap-and-attach)) |
| Q75 | Play always passes **`--disable-service-auth-codes`** with the fixed DDS port: with auth codes the VM service URL changes on every run, which breaks saved attach configurations. *Superseded by Q81.* |
| Q76 | **CI check of the committed Registry and Manifest depends on the Flutter version** (spike #2): Flutter ≤ 3.46 pins `meta` so tightly that build_runner resolves to at most 2.15.1, which has no `--only-check`. Getting Started recommends `dart run build_runner build --only-check` on Flutter ≥ 3.47 (build_runner ≥ 2.16), and below that `dart run build_runner build` followed by `git diff --exit-code lib/pyro.g.dart lib/pyro.manifest.json`. The contract CI job (Q59) uses whichever the repo's Flutter supports. ([`ARCHITECTURE.md`](ARCHITECTURE.md#spike-2--generator-shape-and-latency)) |
| Q77 | **When Pyro's watcher exits because another build_runner took over, it re-probes the lock** (spike #2): held → show "External build_runner" and start its own watcher again once the lock is released (a user's `watch` or one-off `build`, including `--only-check`); free → the user ran `build_runner stop`, so show "Generator stopped" with a *Start* button and don't restart. ([`ARCHITECTURE.md`](ARCHITECTURE.md#spike-2--generator-shape-and-latency)) |
| Q78 | **One Tiled loader, in `pyro_runtime`** (spike #3 outcome, 2026-10-16): `tiledMap` Nodes load through the Runtime's loader, with the disk bundle in Pyro and `rootBundle` in the game, so a map that renders in Pyro also loads in the game. It parses the `.tmx` itself, resolves every tileset, tile and image-layer path against the file that references it (as Tiled does), and hands the parsed map to `RenderableTiledMap.fromTiledMap`. Stock `TiledComponent.load` guesses `.tsx`-relative image paths by segment count and fails on valid maps (e.g. `sets/a.tsx` → `img/a.png`); reported as flame-engine/flame#4117; the loader can go back to stock once it's fixed. ([`ARCHITECTURE.md`](ARCHITECTURE.md#spike-3--disk-rendering)) |
| Q79 | **Pyro's `AssetSource`** is a disk `AssetBundle` (keys are project-relative paths, the same strings the game declares in `pubspec.yaml`) plus a **Pyro-owned image cache**: a changed image is decoded first, and the old one is released only after every Node drawing it has been swapped (Flame's `Images.clear` disposes at once, which blanks the viewport mid-swap). Each Node's build **records the files it reads**, and a file event rebuilds exactly those Nodes. Before rebuilding a map, Pyro drops the affected entries of flame_tiled's process-wide `TiledAtlas` cache. The project folder is watched recursively (real paths, symlinks resolved; ~30 ms debounce). |
| Q80 | **Flame 2.0:** the Runtime keeps supporting the latest stable Flame minor (Q18); when Flame 2.0 ships, the Runtime and Pyro's bundled Flame move to it together in one release, and the 1.x line gets fixes only. Flame's main branch already removes asset path prefixes (flame-engine/flame#4015) and moves flame_tiled to tiled 0.12 (#4073); the Q78 loader and the Q79 `AssetSource` are the code to port. |
| Q81 | **Attach keeps VM service authentication on** (Attach design review, 2026-10-17; supersedes Q75, amends Q60). Play never passes `--disable-service-auth-codes`: flutter_tools marks it deprecated and "not recommended", it also turns authentication off in the VM on the device, and on a wirelessly connected iOS device that VM listens on all network interfaces. Instead Pyro hands each run's authenticated URI (from `app.debugPort`) to the attach workflow: *Attach debugger* copies the current URI, and Pyro writes `{"uri": …}` to `.dart_tool/pyro/vm_service.json` in the project (owner-only, deleted when the game stops), which *Add VS Code attach config* references through the debug adapter's `vmServiceInfoFile`, so `launch.json` holds no URI and never goes stale. No fixed DDS port. The URI stays out of the Console, Pyro's logs and its settings. **Unauthenticated mode** remains only as an explicit per-project development setting, off by default, offered for devices running on this machine (desktop, simulator, emulator), checked to report a loopback URI, and flagged in the toolbar while it runs. ([`project-plan.md`](project-plan.md) §9.3) |
| Q82 | **An early preview replaces the full-scope developer preview** (feedback-latency review, 2026-10-17; supersedes Q73, amends Q65). The final v0.1 scope is unchanged; a smaller milestone lands first (~38 of the ~74.5 evenings, ~13 weeks) to prove the whole editing-to-game loop in a developer's own project: open an existing Flame project, create/save/reopen Scenes, place sprites and edit transforms, edit the hierarchy and basic hitboxes, attach one annotated custom Behavior with editable fields, Play and see Hot-swapped changes. **Cut breadth and polish, never integrity:** the Document model (atomic save, recovery file, `schemaVersion` write refusal, Q49), the Runtime contract (Registry/Manifest, loader, unknown-type handling) and data preservation stay at full strength. Field types Pyro can't edit yet show read-only and round-trip untouched (Overrides only, ADR 0003). In the preview, setup is a README recipe instead of the "Add Pyro" flow (the Runtime compatibility check stays); distribution is a build from source (no signing); Play defaults to the macOS desktop target (⚠ verify Hot-swap there); Attach is limited to *Attach debugger* copying the current URI (Q81's info file, `launch.json` and unauthenticated mode wait for v0.1); the build order gets a vertical slice (hand-written Scene JSON → generator → Runtime → Play → Hot-swap) before the editor UI. Testers are 5–8 hand-picked developers using their own games, with pivot triggers fixed in advance (`project-plan.md` §14). Q-I (stale references after Hot-swap, Q71) is put to them deliberately. |
| Q83 | **Pyro's UI is a separate package, `packages/pyro_ui`** (2026-10-17; amends Q20, Q28). It holds the design system made in Claude Design (prompt 0 of `claude-design-prompts.md`) in Flutter: the tokens (`PrColors`, `PrShadows`, `PrText`, `PrSpacing`, `PrRadii`, `PrSizes`, `PrMotion`), the theme (`PrTheme`) and the presentational widgets. **Presentation only:** widgets take plain values and callbacks; nothing in it knows about scenes, Nodes, the Document, the Type catalog, processes or Riverpod, and the panels (Hierarchy, Inspector, …) stay in the app and compose its widgets. It depends on Flutter only (plus an icon set and bundled fonts), never on `flame`, the Runtime or the app; only the app depends on it, and it is never published. A copy of the design system's `tokens.json` lives in the package (`design/tokens.json`) and a test fails when the Dart tokens drift from it. Why: the look is designed and iterated separately from the editor's logic, the boundary keeps the widgets free of app state (so they can be tested and previewed alone), and the app's `lib/` stays about editing. *Amended by Q84: widgets are built ahead of the panels.* |
| Q84 | **The design system's components are built ahead of the panels, in `pyro_ui`, against a gallery app** (UI components plan, 2026-10-17; amends Q83 and `project-plan.md` §8.6 "widgets as the panels need them"). The package gets all 29 components of the design system, the EditorShell layout and all 60 icons, specified in [`ui-components-plan.md`](ui-components-plan.md): one `Pr` widget per component with its API taken from the guidelines' "Consumer provides", domain-free (generic `T` payloads, plain labels, icons and flags; no Node, asset or device types), every state built on one interaction wrapper (`PrInteractive`: hover, pressed, keyboard-only focus ring, disabled, selected, error; no ripples). A macOS gallery app (`packages/pyro_ui/example`) shows every state next to the design's `preview.html`; widget tests per state and one golden per gallery grid (macOS CI only). **Sub-decisions:** (a) NumberProperty keeps the ↔ cursor visible while scrubbing; hiding and wrapping it at screen edges needs native code and waits behind an `PrPointerLock` hook. (b) ColorProperty ships without the eyedropper; the app adds macOS `NSColorSampler` through an `PrPlatformHooks` callback when Color fields land. (c) Menus are built on Flutter's `RawMenuAnchor`, not the author's `flutter_context_menu` (keyboard and submenu handling come from the framework, and the package stays Flutter-only). (d) `PrTooltip` wraps `RawTooltip` and adds the 0ms hand-off between adjacent controls with a shared warm-up flag. (e) TreeRow computes the drop zone (25/50/25, 50/50 for leaves) and asks the app whether the drop is allowed. (f) `PrIcons` members take the design system's icon names; the node-type → icon map stays in the app. **Estimate and scope:** item 14 is ~23 evenings, not 4 (v0.1 ~74.5 → ~92); a core of ~5.5 (foundations, `PrTreeRow`, `PrPropertyRow`, `PrNumberProperty`, `PrVector2Property`) moves into the early preview because its items 3 and 5 would otherwise build that behaviour in the panels (early preview ~38 → ~42); the rest of the preview keeps themed Material widgets, as Q82 intends. |
| Q85 | **Three small additions from the design-prompts sync** (2026-10-18; amends Q55, Q31/Q53). (a) The **recovery copy interval** (Q55) is a Settings value; there is still no autosave of scene files. (b) The viewport can show an optional **reference rectangle** for a target resolution, set per project and kept in Pyro's settings, never in the project; Pyro can't read the game's camera because it never runs user code. (c) The asset browser marks folders that hold assets but aren't declared in `pubspec.yaml` with **"Not in pubspec.yaml"**, since the game can't load from them; it doesn't edit `pubspec.yaml` on its own, and importing or saving into such a folder declares it as Q53 already says. ([`project-plan.md`](project-plan.md) §8.2, §8.3, §10; [`claude-design-prompts.md`](claude-design-prompts.md) Prompts 4, 6, 11) |
| Q86 | **The app is named Pyro** (2026-10-18; supersedes Q36). The Flame maintainers reserve "Flame Studio" for an official package, so the app, its packages and its API take a name of their own: **Pyro**. It is short, fire-related like the Flame team's own names, and free on pub.dev. Packages: `pyro_annotations`, `pyro_generator`, `pyro_runtime` and the unpublished `pyro_ui`; the app lives in `apps/pyro` with the bundle id `io.github.salah-rashad.pyro`. API: `PyroScene`, `@PyroComponent`, `@PyroBehavior`, `PyroType`; generated files `lib/pyro.g.dart` and `lib/pyro.manifest.json`. The docs say "Pyro" where they said "the Studio". The design system's widget prefix `Fs` becomes `Pr` (`PrButton`, `PrTheme`). Names the Flame team already uses are avoided: Ignite (their project CLI), Ember (their tutorial character), Fire Atlas, Forge2D. The "community project, not affiliated with the Flame team" note stays. Not renamed: `spikes/` (a record of what was tested) and ADR 0001's file name. The GitHub repository is now `salah-rashad/pyro`. |

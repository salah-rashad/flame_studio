# Flame Studio — Design Decisions

Outcome of the design grilling session (2026-10-15/16). Seed for `ARCHITECTURE.md`.
Question numbers (Q1…Q42) refer to the session transcript.

## 1. Product

| # | Decision |
|---|---|
| Q1 | **Open-source community tool** for Flame developers in general. |
| Q2 | v1 core: **scene editor + sprite/animation setup + hitboxes**. No tilemap editor (use Tiled), no visual scripting, no code editor/IDE. |
| Q5 | Built **solo, evenings and weekends**. No target game or deadline. |
| Q11 | **MIT license**, under the author's name. Talk to the Flame maintainers (Discord) early. |
| Q36 | App name **"Flame Studio"** with a "community project, not affiliated with the Flame team" note — *after* asking the maintainers. Fallback: a distinct brand for the app. Packages: `flame_studio_runtime`, `flame_studio_generator` (both unclaimed on pub.dev as of 2026-10-16). Decide before the first `pub publish`. |

## 2. Architecture

| # | Decision |
|---|---|
| Q3 | **Data-driven.** Studio owns scene data; users write logic in Dart. A runtime package loads scenes into Flame. |
| Q7 | **Standalone studio app.** It never runs user code. It builds and launches the user's game as a child process. A **live bridge** (studio ↔ running game over the Dart VM service / websocket) arrives around v0.4. |
| Q38 | User types are discovered by **`flame_studio_generator`** (source_gen), which writes both the **runtime registry** (factories + setters, shipped in games) and a **types manifest (JSON)** that the studio reads (exact output path to be settled in the v0.0 spike — see `project-plan.md` §7.3). One introspection codebase, always in sync with the user's SDK. No analyzer embedded in the studio. |
| Q12 | `source_gen` generator, not `reflectable`. Built-in Flame components use **hand-written descriptors**. Everything sits behind a `StudioTypeRegistry` interface. v1 field types: `int`, `double`, `bool`, `String`, enums, `Vector2`, `Color`, asset references, entity references. |
| Q39 | Studio uses the **user's installed Flutter/Dart SDK** (PATH / `FLUTTER_ROOT` / fvm), overridable in settings. No bundled SDK. |
| Q18 | `flame_studio_runtime` supports the **latest stable Flame minor** until studio 1.0, then current + previous. Flutter stable only. The studio bundles its own Flame for rendering built-ins; the scene format must never depend on a Flame version. |

## 3. Scripting model

| # | Decision |
|---|---|
| Q6 | **Unity-style entity + behaviors first**, custom `Component` subclasses also supported. Custom components with their own rendering show as **placeholders** (optional `@StudioComponent(preview: ...)` image). |
| Q13 | Depend on **`flame_behaviors`**. |
| Q16 | **No user code runs in the editor.** The viewport renders from data only. (`@RunInEditor` dropped; the live bridge replaces it.) |
| Q32 | Code/data drift: **keep unknown data verbatim and flag it** ("Missing script: Patrol"), convert trivial type changes with a warning. `@RenamedFrom` later. Never silently destroy data. |

## 4. Data & formats

| # | Decision |
|---|---|
| Q14 | Scenes are **JSON**, one file per scene, pretty-printed, **sorted keys**, stable **UUID per node**, `schemaVersion` at the top. Merge-friendly. |
| Q35 | **Forward migration guarantee** from day one: any scene from any earlier release loads in later ones (migration chain of pure functions, each with a fixture test). |
| Q15 | **Prefabs as instancing** in v0.2 (`{prefab: "...", overrides: {}}`); overrides later — format ready now. |
| Q27 | Assets referenced by **project-relative path**; renames done in the studio rewrite all references; missing-asset warnings. Animations live in their own **`.anim.json`** files. |
| Q8 | Sprites: **grid slicer** + **Aseprite import** (+ TexturePacker). No drawing tools. |
| Q9 | Collision: **Flame's built-in hitboxes** first; Forge2D later as a plugin. |
| Q10 | **Tiled maps as scene nodes** (reference `.tmx`, rendered in viewport); object-layer → entity conversion later. |

## 5. Editor internals

| # | Decision |
|---|---|
| Q21 | The **document is the source of truth**; the Flame viewport is a projection of it. |
| Q22 | **Snapshot undo** over an immutable document with structural sharing. All edits go through named transactions (`doc.transact('Move', ...)`); continuous gestures are **coalesced**. |
| Q23 | **Flat normalized map** `id → node` (`parentId`, ordered `childIds`), built with **freezed**. |
| Q24 | Viewport sync through a **reconciler** that diffs documents by node ID (identity checks skip unchanged nodes) and patches components. |
| Q25 | **Selection is not undoable** and lives outside the document. |
| Q26 | **Riverpod** for UI state (the author is learning it on this project). |
| Q20 | Panel layout: **fixed resizable panels** (no docking in v1). Visual design produced with **Claude Design** from the prompts in `claude-design-prompts.md`, then implemented by hand in Flutter. |

## 6. Workflow & integration

| # | Decision |
|---|---|
| Q29 | Studio button **"Add Flame Studio to this project"** adds the runtime + generator dependencies, `build.yaml` and `scenes/`. **No other changes to the user's project** (no entrypoint, no macOS target, no entitlements). The studio runs `build_runner watch` and `flutter run --machine` as child processes and shows their output. |
| Q30 | Game code: **non-invasive** `StudioScene.load('scenes/x.scene.json')` → add to any `World`. Lookup by **name** and **tag**; typed accessors later. Debug-only reload hook for hot-swap. |
| Q17 | **Play = `flutter run --machine` on the chosen device.** On save, the studio triggers a hot reload (which syncs the changed scene file) and the runtime reloads the scene in debug builds. |
| Q41 | **Device dropdown** in the toolbar (from `flutter devices`), remembered per project. |
| Q31 | Editor loads assets **from disk** via an `AssetSource` abstraction; games load from the **bundle**. Studio keeps `pubspec.yaml` `assets:` in sync (append only, show diff first time). |

## 7. Platforms, repo, releases

| # | Decision |
|---|---|
| Q4 | Studio: **macOS first-class**; Windows/Linux built in CI, best effort until v0.3. The user's game can target anything. |
| Q28 | **One repo, Dart pub workspaces**: `flame_studio_runtime` (pub, incl. annotations), `flame_studio_generator` (pub), `flame_studio` (desktop app, released as binaries), `example/`. |
| Q40 | **Signed + notarized** builds on **GitHub Releases** for v0.1 (needs an Apple Developer account, $99/yr); **auto-update** (Sparkle/WinSparkle) in v0.2; Homebrew/winget later. |
| Q33 | Tests: heavy on **document/history/serialization/reconciler unit tests**, **generator golden tests** (registry + manifest), **runtime loader tests** (`flame_test`); light widget tests; CI on macOS/Windows/Linux plus a sign/notarize job. |
| Q37 | v0.1 launch: README, `example/` game, **2–3 min demo video/GIF**, Getting Started (incl. install & Gatekeeper), **`ARCHITECTURE.md`** (this document + the *why not reflectable* / *why standalone* rationale). |

## 8. Milestones

**v0.0 — de-risking spike (2–3 evenings, throwaway code, findings go into `ARCHITECTURE.md`)** (Q42)
1. Edit a scene JSON → hot reload through `flutter run --machine` → scene reloads on an iOS simulator / Android emulator.
2. `build_runner watch` refreshes `types.json` within a few seconds on a mid-size project.
3. The studio renders a sprite and a Tiled map loaded from a project folder on disk.
If (1) fails, the live bridge moves into v0.1.

**v0.1 — first public release (macOS)** (Q34)
1. App shell: project list, open project, SDK detection (fvm-aware), "Add Flame Studio to this project"
2. Hierarchy: add / delete / rename / reparent (drag) / duplicate
3. Data-driven viewport: pan/zoom, grid, click-select, move/rotate/scale gizmos, snapping
4. Inspector: transform + all `@Editable` field types from `types.json`
5. Built-in nodes: entity, sprite, animated sprite, rectangle/circle/polygon hitboxes; placeholders for custom components
6. Behaviors: attach/remove, edit fields, Missing-script / Missing-asset warnings
7. Assets: browser, **grid slicer** → `.anim.json`, `pubspec.yaml` asset sync *(cut line)*
8. Document: save/load, undo/redo with coalescing, `schemaVersion` migrations
9. Play: device dropdown, build/log console, **scene hot-swap on save** *(cut line)*
10. Packages: `flame_studio_runtime`, `flame_studio_generator`, `example/` game
11. Signed + notarized `.dmg` on GitHub Releases

If v0.1 runs past ~4 months, ship without items 7 and 9 and release them as v0.1.1.

**Roadmap**
- **v0.2:** Aseprite import, prefab instancing, Tiled map nodes, auto-update
- **v0.3:** Windows + Linux first-class, Homebrew / winget
- **v0.4:** live bridge to the running game (select/tweak live, exact custom rendering), prefab overrides, `@RenamedFrom`, typed scene accessors
- **Later:** Forge2D, particle/effects editors, docking panels

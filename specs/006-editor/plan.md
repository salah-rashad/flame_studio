# Implementation Plan: Editor (Phase 4)

**Branch**: `specs/006-editor` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-editor/spec.md`

## Summary

Phase 4 builds the editor on top of everything Phases 1–3 made: the `Pr` design system
(`PrEditorShell` + 29 components), the Document model of spec 002 (`SceneDocument`,
`DocumentSession`, `RecoveryStore`), the Generator's Manifest (spec 003) and the Runtime's Node
model and `AssetSource` interface (spec 004). Six items in §14's order: the app shell and editor
window (#1), the Type catalog (#6), the viewport with its reconciler (#4), the hierarchy (#3),
the inspector (#5) and Behaviors in the inspector (#9). Everything the panels show and edit goes
through the data contract; the panels compose `Pr` widgets and reach other features only
through public Riverpod providers (§8.5). The reconciler — document diff → preview-component
operations — is the phase's heavily-tested pure seam (constitution V).

## Technical Context

**Language/Version**: Dart SDK `^3.12.0`, Flutter 3.44.2 stable (toolchain pinned by *Q94*;
reference machine: macOS, Apple M4).

**Primary Dependencies** (already in `apps/editor/pubspec.yaml` unless noted):

- `flutter_riverpod` 3.3.2 + `riverpod_annotation` 4.0.3 (codegen via `riverpod_generator`
  4.0.4, generated files committed, *Q94*)
- `freezed` 3.2.6-dev.1 for new immutable models (catalog descriptors, view states)
- `fast_immutable_collections` (already used by the Document model)
- `flame` 1.38.2 (`>=1.36.0 <2.0.0`) — **viewport only**, in the app, never in `pyro_ui`
- `pyro_ui` (workspace) — every panel widget; `pyro_runtime` (workspace) — Node model,
  `SceneCodec`, `AssetSource` interface, `Scene.currentSchemaVersion`
- `file`, `crypto`, `clock`, `uuid` (existing, from spec 002)
- **New: `yaml` ^1.x** for parsing the project's `pubspec.yaml` (asset folders) and
  `pubspec.lock` (Runtime version). BSD-3 licensed, MIT-distribution compatible. The only new
  dependency this phase; called out here per constitution II.

**Storage**: Scene files (`*.scene.json`, canonical form) and recovery copies
(`RecoveryStore`, app-support) — both existing. New: an editor-settings JSON in Pyro's
application-support folder (recent projects, per-project `PrShellSizes`), written atomically,
never inside a user project.

**Testing**: `flutter test` in `apps/editor`; reconciler as pure-function unit tests; panel
widget tests (reparent-by-drag, Reset-to-default, Missing behavior) on the gallery's
font-loading pattern (new `apps/editor/test/flutter_test_config.dart`); deterministic —
`package:file` memory FS, `fake_async`, injected `NodeIdSource`, recorded/fixture data only
(existing `test/document/helpers/` extend to the new features).

**Target Platform**: macOS first-class (unsandboxed desktop); CI analyzes and tests on macOS,
Windows, Linux (no new platform work; no signing until Phase 8).

**Project Type**: Flutter desktop app (`apps/editor`) inside the pub workspace.

**Performance Goals** (constitution III, spec SC-004/SC-005): 60 fps (≤ 16 ms frames, profile
mode, reference Mac) during interactive editing on a 1,000-Node scene; a changed image file
reaches the viewport in ≤ 200 ms rebuilding only the Nodes that read it; identity-skipping
reconciler (`identical` Nodes never patched); panels watch `nodeProvider(id)`, never the whole
document.

**Constraints**: never import or execute user code (constitution II, *Q7*); never write the
user's pubspec; all saves through `DocumentSession.save` (atomic, version-gated); unknown
types and kept values preserved verbatim (constitution IV); no new `pyro_ui` dependency on
Flame/Riverpod/scenes.

**Scale/Scope**: 6 work items, ~18 evenings estimate (§14), one spec, `example/` as the
reference project throughout.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan complies | Verdict |
|---|---|---|
| I — Clean Code | Shared `analysis_options.yaml` (strict casts/inference/raw types); app disables only `public_member_api_docs` (existing app exception); glossary words in all UI text; new models freezed-immutable; the only mutation path is `DocumentSession.transact` | PASS |
| II — Modular Boundaries | `pyro_ui` stays presentation-only — no Flame/Riverpod/document knowledge reaches it; the app does not depend on `pyro_generator`; features reach each other only through public providers; the Type catalog lives in `project/` (no new top-level feature folder); two flagged additions below | PASS (flagged) |
| III — Performance by Design | Budgets stated in Technical Context; reconciler skips `identical` Nodes; `nodeProvider(id)` + `select` for narrow rebuilds; image decode and hashing off the UI isolate (existing `Offload` seam); regressions block the change | PASS |
| IV — User Data Integrity | Every save via `DocumentSession` (atomic write, digest refusal, `runtimeReadsUpTo` gate); recovery copies via the existing store; the catalog never writes scenes; no pubspec edits — the new-scene dialog warns instead | PASS |
| V — Tested Core | Reconciler = Heavy (pure-function tests for identity skip / patch / add / remove / subtree move); panel widget tests for the three named flows; deterministic tests only; contract job keeps guarding the format | PASS |

**Flagged for the record** (constitution II, "a change that adds a dependency or crosses a
boundary MUST say so in its plan"):

1. New app dependency `yaml` (see Technical Context).
2. One candidate `pyro_ui` delta: `PrMenuItem` cannot show a disabled-entry reason (Prompt 3's
   hitbox-under-root entries want "A hitbox needs a Node to belong to…"). If taken, it is a
   presentation-only addition proposed to the author per *Q87* — decided at implementation,
   not smuggled in. Phase 4 works without it (entries disabled, reason in the hierarchy's
   Add-child tooltip).

**Outcome (T050, 2026-10-24).**

1. `yaml: ^3.1.4` was added in T001 (the `^1.14.0` in the task text was a mistyped version) (`apps/editor/pubspec.yaml`) and is used by
   `lib/project/asset_folders.dart` and `lib/project/runtime_compat.dart`; BSD-3, compatible with
   the MIT distribution.
2. The `PrMenuItem` disabled-reason delta is **declined**, and `pyro_ui` has no such addition.
   The Add menu disables the refused entries, and the reasons show in the tooltip of the Add
   button (`addRefusals`, hitbox-under-root among them), which was enough in use: the rule that a
   user can't guess is stated where the Add button is. The Add Behavior list needs no reason on a
   line, since it offers only what fits and puts the reason on its disabled button. If testers
   miss a reason on the line itself, it comes back as a *Q87* proposal.

**Tech constraints**: Flutter stable 3.44.2 with prerelease freezed (*Q94*) — no toolchain
change this phase; MIT-compatible dependencies only.

## Project Structure

### Documentation (this feature)

```text
specs/006-editor/
├── plan.md              # This file
├── research.md          # Phase 0 output: API survey, Riverpod/Flame patterns, decisions
├── data-model.md        # Phase 1 output: catalog, parenting rules, reconciler ops, view states
├── quickstart.md        # Phase 1 output: the manual end-to-end validation run
├── contracts/
│   ├── type-catalog.md  # TypeDescriptor shape, built-in descriptors, parenting rules
│   └── reconciler.md    # The diff→operations seam and its invariants
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
apps/editor/
├── bin/play.dart               # existing CLI (spec 005) — unchanged, kept until the Play button
├── lib/
│   ├── main.dart               # runner: window config (hidden macOS title bar), PyroApp
│   ├── app/                    # NEW #1 — the editor window
│   │   ├── shell.dart          # PrEditorShell composition, panel slots, seams, sizes store
│   │   ├── scene_tabs.dart     # PrTabs document style, dirty dots, close flow
│   │   ├── dialogs.dart        # unsaved-changes, new-scene, save-refused, Restore prompt
│   │   ├── shortcuts.dart      # ⌘N/⌘O/⌘S/⌘W, panel cycling, focus nodes
│   │   └── providers.dart      # openScenesProvider, activeSceneProvider (tab model)
│   ├── document/               # existing spec 002 — public API unchanged
│   ├── project/                # NEW #1/#6 — open project and its types
│   │   ├── recent_projects.dart# project list store (app-support JSON)
│   │   ├── sdk.dart            # SDK detection (fvm → FLUTTER_ROOT → PATH)
│   │   ├── runtime_compat.dart # pubspec.lock → runtimeReadsUpTo (compat table)
│   │   └── catalog/            # Type catalog
│   │       ├── manifest_parse.dart  # pyro.manifest.json → descriptors (+ errors/warnings)
│   │       ├── built_in.dart   # hand-written descriptors for the built-in Node kinds
│   │       ├── parenting.dart  # allowed-child rules (incl. hitbox-under-root, Q115)
│   │       └── provider.dart   # typeCatalogProvider + file watcher (last-good on failure)
│   ├── viewport/               # NEW #4/#6 — the preview world
│   │   ├── editor_game.dart    # EditorGame (FlameGame), camera pan/zoom, pause when hidden
│   │   ├── reconciler.dart     # PURE: (oldDoc, newDoc) → List<PreviewOp>
│   │   ├── preview/            # preview components per Node kind + placeholders + missing
│   │   ├── overlay.dart        # selection outline, hover, move gizmo (camera viewfinder slot)
│   │   ├── disk_assets.dart    # AssetSource over the project folder + image cache (Q79)
│   │   └── providers.dart      # camera state, reconciler wiring, image watcher
│   ├── panels/                 # NEW #3/#5/#9
│   │   ├── hierarchy/          # tree view (flatten, keyboard nav), Add menu, rename, DnD
│   │   ├── inspector/          # transform section, field editors by FieldType, read-only rows
│   │   └── behaviors.dart      # Behavior cards, Add/remove, Missing/incompatible states
│   └── process/                # existing spec 005 — untouched this phase
└── test/
    ├── flutter_test_config.dart # NEW — gallery-style font loading for Pr widgets
    ├── app/  project/  viewport/  panels/   # mirroring lib/
    └── document/  process/                # existing
```

No changes to `packages/` (unless the flagged menu-item delta is approved) or `example/`
(the done-when runs *against* `example/`; the manifest-regeneration drill uses
`build_runner` by hand).

**Structure Decision**: the constitution's six app feature folders hold everything; the Type
catalog joins `project/` (it is derived state of the open project, read through
`typeCatalogProvider`) rather than adding a seventh folder. The viewport owns Flame; panels
never import `flame`; document/ and process/ are untouched.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. The two flagged items (the `yaml` dependency; the optional `PrMenuItem`
disabled-reason delta) are additive and recorded above, not rule breaks.

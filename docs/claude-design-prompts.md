# Flame Studio — Claude Design Prompts

| | |
|---|---|
| **Last synced** | 2026-10-18, against [`project-plan.md`](project-plan.md) (Q1–Q85), [`ui-components-plan.md`](ui-components-plan.md) and `packages/flame_studio_ui` |
| **Design system** | Made in Claude Design from Prompt 0. Its `tokens.json` is copied to `packages/flame_studio_ui/design/tokens.json`; its 29 components, the EditorShell and the 60 icons are built in Flutter in `packages/flame_studio_ui` (*Q83, Q84*) |

## How to use

1. **Prompt 0 is done.** It produced the design system; keep it here as the record. Don't run it
   again: that would replace the system the Flutter package was built from. To change the system,
   write a short delta prompt ("change token X", "add state Y to component Z"), then copy the new
   `tokens.json` into the package (its `tokens_test.dart` shows what drifted).
2. **Design views in their own documents, never in the design-system document.** That document
   is the source of the package's `tokens.json`; designing views there invites changes to tokens
   and components that the Flutter side never hears about.
3. **One document per view**, each a new design that uses the Flame Studio design system: paste
   the **shared preamble** below, then that view's prompt, and ask for every listed state as a
   separate frame. Prompts 2 and 9 may share a document, since both design the toolbar and the
   Play cluster. Run Prompt 2 first (every other view sits inside its shell), then follow the
   build order: 3, 4, 5 and 8 for the early preview, then the rest.
4. Each view prompt ends by asking for a **"New patterns"** list: anything the view needed that
   the component set doesn't have. Add those to the design system with a delta prompt (step 1)
   and to `ui-components-plan.md` before the panel is built, rather than letting them live only
   in a view document.
5. The output is a *reference design*, re-implemented by hand in Flutter: the app's panels compose
   `flame_studio_ui` widgets. Wording in the prompts uses the project vocabulary
   ([`GLOSSARY.md`](../GLOSSARY.md)) so the designs show the words the app will use.

| Prompt | View | Needed for | Run |
|---|---|---|---|
| 0 | Design system | — | ✅ |
| 1 | Project list (welcome window) | early preview (list, open, SDK, Runtime check); v0.1 rest | |
| 2 | Editor shell, toolbar, scene tabs | v0.1 (the early preview uses themed Material widgets, *Q82*) | |
| 3 | Hierarchy | early preview (add, delete, rename, reparent); v0.1 rest; prefabs v0.2 | |
| 4 | Viewport | early preview (selection, move gizmo, pan/zoom); v0.1 rest; animated sprites v0.1.1; Tiled v0.2 | |
| 5 | Inspector | early preview (core field types); v0.1 rest; mixed values v0.1.1 | |
| 6 | Asset browser | v0.1; rename with reference rewriting v0.1.1 | |
| 7 | Grid slicer & animation editor | v0.1.1; Aseprite import v0.2 | |
| 8 | Console | early preview | |
| 9 | Play, devices, Attach | early preview (macOS target, copy URI); v0.1 rest | |
| 10 | "Add Flame Studio to this project" | v0.1 (a README recipe in the early preview) | |
| 11 | Settings, About, warnings & empty states | v0.1 | |

---

## Prompt 0 — Design system ✅ done

Kept as the record of what produced the system. What came out of it, and what the view prompts can
rely on: dark tokens only (ember accent `accent` / `accent-text`, `surface-*` levels, semantic
`success`/`warning`/`error`/`info`, plus `prefab`, `axis-x`/`axis-y`, `status-idle`, `scrim`);
Inter + JetBrains Mono; Lucide icons; 29 components; an EditorShell example.

```
Design the design system for "Flame Studio", a desktop game-editor app for the Flame 2D game engine
(Flutter). Think of the category of Godot, Unity, Defold and Figma: a professional, dense,
keyboard-friendly tool used for hours at a time. Users are Dart/Flutter game developers.

Platform & constraints
- Desktop only: macOS first, later Windows and Linux. Minimum window 1280×800, designed at 1440×900.
- Mouse + keyboard, no touch. Every action has a hover state; focused elements show a visible
  focus ring for keyboard navigation.
- It will be rebuilt in Flutter, so: no web-only effects (no backdrop blur, no complex CSS
  filters), use solid fills, 1px borders, simple shadows only for floating layers (menus,
  dialogs, tooltips).

Visual direction
- Dark theme first (a light theme comes later — define tokens so it can be added).
- Neutral, low-saturation greys for the chrome so the game content in the viewport is the most
  colourful thing on screen.
- One warm accent colour (ember/orange family, nodding to "Flame") for primary actions, selection
  and the Play button. Do not copy the Flame logo or branding.
- Semantic colours: success, warning, error, info — used for console output, badges and
  inline warnings.
- Information-dense: 4px spacing grid, compact row heights (22–24px for tree and property rows),
  13px UI text.
- Typography: a clean UI sans (e.g. Inter) and a monospace (e.g. JetBrains Mono) for numbers in
  property fields, file paths and the console.
- Icons: a single consistent outline icon set at 16px (panels/toolbars) and 14px (tree rows).

Deliver
1. Colour tokens (surface levels for panel / panel-raised / input / hover / selected, borders,
   text primary/secondary/disabled, accent, semantic colours) with values.
2. Type scale and spacing scale.
3. Component sheet with all states (default, hover, pressed, focused, disabled, selected, error):
   - Buttons: primary, secondary, ghost, icon-only, toggle, split button (button + dropdown)
   - Toolbar and toolbar groups, segmented control
   - Panel: header with title + actions, collapsible section header
   - Tree row (expand chevron, icon, name, badges, inline rename state, drag-over-above /
     drag-over-inside / drag-over-below indicators)
   - Property rows for each field kind, label left / editor right:
     • int / double: numeric field you can drag horizontally on the label to scrub the value,
       with optional range slider variant
     • bool: checkbox / switch
     • String: text field
     • enum: dropdown
     • Vector2: paired X / Y numeric fields with coloured axis labels
     • Color: swatch + hex field
     • Asset reference: slot showing thumbnail + file name, drop target state, "missing" state,
       clear button
     • Entity reference: slot showing referenced node name, picker button, drop target state,
       "missing" state
     • "Mixed values" state for multi-selection
     • "Default from code" state (value not overridden) vs "overridden" state with reset action
   - Inputs: text field, search field, dropdown, number field
   - Tabs, context menu (with shortcuts and submenus), tooltip, toast, modal dialog,
     inline banner (info / warning / error)
   - Badges/pills: warning count, "missing", "prefab", device chips
   - Empty-state block (icon, title, one-line explanation, primary action)
   - Progress: indeterminate bar, small spinner, status-dot (idle / working / ok / error)
4. Example of the full editor shell using the components (see the view prompts for content).
```

---

## Shared preamble for view prompts

Paste this before every view prompt (1–11).

```
This design uses the Flame Studio design system. Do not change or restyle the system itself.

Use only its tokens (colours, type styles, spacing, radii, sizes, shadows), its Lucide icons and
its components: Button, IconButton, ToggleButton, SplitButton, SegmentedControl, Toolbar,
TextField, SearchField, NumberField, Dropdown, PropertyRow, NumberProperty, BoolProperty,
Vector2Property, ColorProperty, AssetSlot, EntitySlot, Panel, SectionHeader, Tabs, TreeRow,
ContextMenu, Tooltip, Dialog, Toast, Banner, Badge and DeviceChip, Progress (bar, spinner,
status dot), EmptyState.

Editor window = the EditorShell: title bar 38px (macOS traffic lights on the left, centred
"<project> — <scene file>" title), main toolbar 32px, Hierarchy panel on the left (260px), centre
column with the scene tabs (28px), the viewport toolbar (32px) and the viewport, the bottom dock
under the centre column only (Console / Assets tabs, 220px), Inspector on the right (320px),
status bar 22px; panels separated by 1px seams of bg-app. The focused panel shows its title in
text-primary with the 2px accent-text top edge; selection in an unfocused panel uses
surface-selected-inactive.

Words to use in the UI: Scene (not level or map), Node, Entity, Behavior (not script), Custom
component, Prefab, Prefab instance, Type ID, "default from code" / "overridden" (an Override),
Missing behavior / Missing component, Play, Attach, Hot-swap. Property labels are the Dart field
names verbatim (speed, jumpForce). Sentence case; messages say what happened and what to do;
disabled controls keep a tooltip that says why. Sample content: a pixel-art platformer project
called "Platformer" with scenes level_1.scene.json and main_menu.scene.json, a Player custom
component and Patrol / Health behaviors.

Frames at 1440×900 unless stated, one frame per listed state. The Studio never runs the user's
game code inside itself: anything it can't draw from data is a placeholder.

At the end, list under "New patterns" anything this view needed that the component set doesn't
have (name, states, tokens used), so it can be added to the Flutter package.
```

---

## Prompt 1 — Project list (welcome window)

```
Design the welcome / project list window shown when the app starts (a smaller window, ~960×640).
The Studio opens existing Flame projects; there is no "New project" flow.

Content
- App name and version, links to docs and GitHub, and a short "Community project, not affiliated
  with the Flame team" line.
- Recent projects list: project name, path (monospace, truncated in the middle), detected Flame
  version, Flutter SDK it will use (with an "fvm" Badge when the project pins one), last opened,
  and one status Badge: "Ready", "Not set up" (no Flame Studio dependencies yet), "Runtime too old"
  (its flame_studio_runtime is older than this Studio supports), "Needs a newer Studio",
  "Flame version unsupported" (below Flame 1.36), "Folder missing", "Open" (already open in
  another window; opening it focuses that window).
- Actions: "Open project…" (folder picker, primary), "Remove from list" (hover action and
  ContextMenu; removes from the list only, never touches files), "Reveal in Finder".
- Footer: detected Flutter SDK (version, path, where it came from: .fvmrc / FLUTTER_ROOT / PATH /
  Settings) with a "Change…" link.

States to show
1. Several recent projects with mixed status badges, one hovered with its row actions.
2. First launch: EmptyState ("Open a Flame project to get started", Open project…).
3. Flutter SDK not found: blocking error Banner with "Locate Flutter SDK…"; open actions disabled
   with a tooltip saying why.
4. A project whose folder no longer exists (dimmed, "Folder missing", "Locate…" / "Remove").
5. A "Runtime too old" project selected: a warning explaining that saving scenes needs an
   upgrade, actions "Upgrade runtime…" (opens the setup flow's diff, Prompt 10) and "Open anyway".
6. After a crash: Dialog "Flame Studio quit unexpectedly. Restore unsaved changes to
   level_1.scene.json?" listing the scenes with a recovery copy and when each was written;
   "Restore" (primary) / "Discard" (destructive).
```

---

## Prompt 2 — Editor shell, main toolbar and scene tabs

```
Design the main editor window (1440×900) for an open project, using the EditorShell layout from
the preamble. Fixed, resizable panels; no docking or dragging panels around.

Title bar
- "Platformer — level_1.scene.json", centred. No native controls besides the traffic lights.

Main toolbar (Toolbar, main style), left to right
- Undo / Redo IconButtons (disabled state with "Nothing to redo").
- Transform tools: SegmentedControl Select, Move, Rotate, Scale (Q W E R in the tooltips).
- Snapping ToggleButton showing the grid size ("8 px"), with a grid-size Dropdown.
- Centre: the Play cluster (detailed in Prompt 9): Play, Stop.
- Right: device DeviceChip/dropdown ("iPhone 16 Simulator", "Pixel 8 Emulator", "macOS"), a
  status dot for hot reload ("Hot reload ready" / "Reloading…" / "Reload failed"), and while a
  game runs, the "Attach debugger" button.

Scene tabs (Tabs, document style, above the viewport)
- One tab per open scene, each with its own undo history: file icon, file name, dirty dot that
  becomes × on hover, ⌘W closes. Opening a scene: double-click it in Assets, or ⌘O.
- A "New scene…" action (⌘N): Dialog with name and folder (default assets/scenes/); if the folder
  isn't declared in pubspec.yaml yet, a line says it will be added.

Status bar
- Generator status dot + text: "Types up to date" / "Generating…" / "Generator error — see
  Console" / "External build_runner" / "Generator stopped" with a Start link.
- Warning count Badge (click → Console filtered to warnings).
- Right side: cursor world coordinates (mono-small), zoom %.

States to show
1. Normal editing, a Node selected, Hierarchy focused (accent top edge on its header).
2. Same, but the Inspector focused: the Hierarchy selection turns surface-selected-inactive.
3. Game running on a device: Play cluster in its running state, device chip "Running",
   Toolbar highlighted (accent outline), Attach debugger visible.
4. Generator failing: status bar error state; Play still available, its tooltip warns that the
   last good types are in use.
5. Status bar crops for "External build_runner" and "Generator stopped — Start".
6. Bottom dock collapsed to its 28px tab strip.
7. Splitter hover and dragging (border-strong / accent-text seam, resize cursor).
8. Minimum window 1280×800: the docks shrink in proportion (~237 / 291 / 187) and the viewport
   keeps at least 750×520.
9. Three scene tabs, one dirty, one hovered showing ×; closing the dirty one opens the unsaved
   changes Dialog (Prompt 11).
10. No scene open: tab strip empty, viewport EmptyState ("Open a scene or create one", New
    scene… / Open from Assets), Inspector empty.
11. The New scene Dialog, including the pubspec.yaml note.
```

---

## Prompt 3 — Hierarchy panel

```
Design the Hierarchy panel (Panel titled "Hierarchy", not "Scene"): the tree of Nodes in the
current scene, built from TreeRows.

Content
- Panel header: "+" add-node IconButton opening a ContextMenu: Entity, Sprite, Animated Sprite,
  Rectangle Hitbox, Circle Hitbox, Polygon Hitbox, Tiled Map, Prefab instance…, then a "Custom
  components" submenu listing the project's @StudioComponent classes by Type ID (grouped by
  category). Search/filter SearchField under the header.
- Node kind icons: entity → box, sprite → image, animated sprite → film, hitbox → hitbox
  (dashed square), Tiled map → layers, prefab instance → box in the prefab colour, custom
  component → circle-dot, scene root → layers.
- Tree rows: chevron, kind icon, Node name, optional tag pills, trailing Badges (warning for a
  Missing behavior / Missing component / missing asset, prefab), a visibility toggle shown on
  hover (editor-only: hides the Node in the viewport, not saved in the scene; a hidden Node's row
  is dimmed).
- Scene root row at the top.

Interactions & states to show
1. A ~20-Node tree, some expanded, one selected, one hovered, the keyboard cursor on another
   (inset focus ring); Hierarchy focused.
2. Multi-selection (shift / cmd-click).
3. Inline rename of a row (F2 / Enter, Esc cancels).
4. Drag-and-drop reparenting: drop above, inside and below; an invalid drop (into its own child,
   or into a Prefab instance) with the reject border and not-allowed cursor; auto-expand while
   hovering a collapsed row.
5. Right-click ContextMenu: Rename (F2), Duplicate (⌘D), Delete (⌫, destructive), Add Child ▸,
   Frame in Viewport (F), with shortcuts.
6. Missing behavior / Missing component Badge with its Tooltip ("Patrol no longer exists in your
   code. Its values are kept.").
7. Two siblings with the same name: warning Badge and Tooltip "Two Nodes named goblin under
   enemies: scene.find('goblin') will throw. Rename one or look it up by path."
8. Filter active: matches highlighted, non-matching parents dimmed, "3 of 20" in the field; and
   the no-match state.
9. Deleting a Node other fields point to: Dialog "Delete player? 2 fields reference it: Patrol.target
   on goblin_1, CameraFollow.target on camera." Delete (destructive) / Cancel.
10. A Prefab instance row (v0.2): prefab tone, its children shown read-only.
11. Empty scene: EmptyState ("Add your first Node", Add Entity).
```

---

## Prompt 4 — Viewport

```
Design the scene Viewport: a 2D canvas in the centre column that draws the scene being edited
from its data (pixel-art platformer content). Above it sits the viewport Toolbar (viewport
style, 32px strip, not floating).

Content
- Infinite canvas on bg-viewport with a subtle grid and world origin axes (axis-x / axis-y).
- Optional reference rectangle for a target resolution (a viewport setting, e.g. "1280×720"),
  labelled; it is not read from the game.
- Sprites (and, from v0.1.1, animated sprites; from v0.2, Tiled maps) drawn as in the game;
  hitboxes drawn as coloured outlines (toggleable).
- Custom components can't be drawn (no user code runs in the Studio): a placeholder box sized to
  the component's size with its Type ID and the circle-dot icon, clearly different from real art.
  Variant: a component with a @StudioComponent(preview:) image draws that image with a small
  "preview" Badge. Variant: a Missing component, as an error-toned placeholder.
- Viewport Toolbar: zoom % Dropdown, Fit selection, Fit scene, ToggleButtons for grid / hitboxes
  / reference rectangle.

Interactions & states to show
1. One Node selected with the Move gizmo (X/Y arrows in axis colours + centre square).
2. Rotate gizmo and Scale gizmo variants.
3. Multi-selection with a shared bounding box.
4. Marquee (rubber-band) selection in progress.
5. Snapping while dragging: snap guide lines and a small position readout.
6. Hover highlight on an unselected Node with its name label.
7. Drag and drop from Assets: an image becomes a sprite (ghost preview at the drop point);
   other drops: .anim.json → animated sprite, .tmx → Tiled map, a scene → Prefab instance.
8. Picking an entity reference (started from an EntitySlot's crosshair in the Inspector): Nodes
   whose type fits the field are highlighted on hover, the others dimmed, a hint bar "Click a
   Node of type Player · Esc to cancel".
9. Panning (space-drag / middle-drag) with the grab cursor, and zoomed in at 400% with pixel art
   kept sharp.
10. Empty scene: centred hint ("Drag an image here or add a Node from the Hierarchy").
```

---

## Prompt 5 — Inspector

```
Design the Inspector panel (Panel titled "Inspector"), which edits the selected Node. Rows are
PropertyRows inside a PropertyList (shared, resizable 40% label column); sections are
SectionHeaders.

Content, top to bottom
- Header: kind icon, editable Node name (TextField), tags editor (pills + add).
- Transform section: position (Vector2Property), angle (degrees), scale (Vector2Property with
  aspect lock), size (Vector2Property), anchor (a 3×3 picker of named anchors + Vector2 for a
  custom one).
- Built-in sections where they apply:
  • Sprite: image AssetSlot (thumbnail), source rect, flip X / Y, opacity (range slider)
  • Animated Sprite (v0.1.1): .anim.json AssetSlot, animation Dropdown (the names in that file),
    playing toggle, a strip of its frames
  • Hitbox: shape, size / radius / vertices, collisionType Dropdown (active / passive / inactive)
- Custom component Node: a section named by its Type ID with its @Editable fields.
- Behaviors: each Behavior is a collapsible card (SectionHeader with the Type ID, its source file
  as an "Open in editor" link, overflow menu: Move up, Move down, Reset all to default, Remove).
  Its @Editable fields use the property components by field type: int / double (NumberProperty,
  range slider when the code gives min and max), bool, String, enum (Dropdown), Vector2, Color,
  asset reference (Sprite, SpriteAnimation, image path), entity reference (EntitySlot).
- Override display: a field with no Override shows "default from code" (text-secondary value;
  a non-constant default shows its source text, e.g. Vector2(1, 0)); an overridden field shows the
  accent-text bar, the label in text-primary and a ↺ "Reset to default". The label Tooltip shows
  type, default and the doc text from @Editable(tooltip:): "double · default 50 · Pixels per
  second".
- "Add Behavior" Button opening a searchable list of the project's Behaviors, grouped by category
  (label, source file, one-line doc). Only Behaviors whose required parent type fits the Node are
  offered; on a Custom component that doesn't mix in EntityMixin the button is disabled ("Boss
  can't hold Behaviors: it doesn't mix in EntityMixin").

States to show
1. An Entity with transform, sprite and two Behaviors mixing field types (double with range
   slider, enum, Vector2, Color, asset reference, entity reference), some overridden, some
   default from code.
2. Scrubbing a number on its label (↔ cursor, accent edge).
3. Multi-selection of 3 Nodes (v0.1.1): shared fields editable, differing values "—" (mixed),
   sections only some Nodes have are hidden with a note.
4. "Missing behavior: Patrol" card: explanation, the preserved values read-only, actions
   "Remove" and "Keep".
5. "Unused values" group on a Behavior whose field was removed from the code: the orphaned
   values read-only, "Remove".
6. A field whose type changed in code (int → double): converted value with a warning Badge and
   Tooltip.
7. Missing asset in an AssetSlot (error state with the old file name and "Locate…"); missing
   entity reference in an EntitySlot.
8. A field the Studio can't edit yet (early preview): value shown read-only with a lock icon and
   "Edit in the scene file for now" Tooltip; it is kept untouched on save.
9. The Add Behavior list with results, incompatible ones explained, and the empty-result state.
10. Generator running or failing: a non-blocking info / warning Banner above the Behavior cards
    ("Types are being regenerated" / "Generator error: showing the last good types").
11. Nothing selected: EmptyState ("Select a Node to inspect it").
```

---

## Prompt 6 — Asset browser

```
Design the Assets tab of the bottom dock: a browser of the project's asset folders, read from
disk (changes on disk appear at once).

Content
- Left: folder tree of the asset folders. A folder that exists but isn't declared in
  pubspec.yaml (the game can't load from it) carries a warning Badge "Not in pubspec.yaml".
- Right: grid of thumbnails (images, spritesheets, .anim.json files with their animation count
  and a play-on-hover preview, .tmx Tiled maps, audio files with a waveform icon, .scene.json
  scenes). Toggle to a list view (name, type, size, path as the Flutter asset key).
- Toolbar: breadcrumb path, SearchField, type filter, thumbnail size slider, "Import…" Button.

Interactions & states to show
1. Grid view with mixed asset types, one selected, one hovered.
2. List view.
3. Dragging an asset out: the drag ghost, and every compatible AssetSlot in the Inspector showing
   its quiet accept state while the drag is in flight.
4. ContextMenu: Open (scenes open in a new tab), Rename (⏎), Reveal in Finder, Open in Slicer
   (images), Copy asset path, Delete (destructive).
5. Rename that updates references (v0.1.1): Dialog "3 scenes and 2 animations reference
   goblin_sheet.png. Their references will be updated." listing them.
6. Delete of a referenced file: Dialog listing what will show as missing.
7. Importing into a folder not yet in pubspec.yaml: notice "assets/images/enemies/ will be added
   to pubspec.yaml" with a small diff preview (shown the first time).
8. Empty folder state and "no search results" state.
```

---

## Prompt 7 — Grid slicer & animation editor (v0.1.1)

```
Design the Spritesheet Slicer: a large modal (or its own window) opened from an image asset or
an existing .anim.json, used to slice a spritesheet into frames and define its animations. One
spritesheet has one .anim.json file holding all its animations.

Content
- Left: the spritesheet at zoomable scale, pixel art kept sharp, with the slicing grid overlaid;
  frames numbered.
- Right sidebar: slicing settings (cell width / height, offset X/Y, spacing X/Y; rows / columns
  derived) and the list of animations in this file.
- Animation editor area: name, ordered frame strip (drag to reorder, remove a frame), one step
  time for all frames or a duration per frame, loop toggle, live preview player (play / pause,
  speed).
- Footer: "Save" with the target path (assets/images/goblin_sheet.anim.json, next to the image),
  Cancel.

States to show
1. Fresh sheet: grid being configured, frames highlighted as cells.
2. Selecting frames on the sheet (click / shift-click / drag) to build an animation.
3. Two animations defined ("walk", "idle" with per-frame durations), one being previewed.
4. Validation: cell size doesn't divide the image (warning), duplicate animation name (error),
   empty animation (Save disabled, Tooltip says why).
5. Reopening an existing .anim.json that scenes use: a note that renaming an animation affects
   the Nodes that play it.
6. Aseprite import variant (v0.2): tags from Aseprite's JSON export listed as animations,
   frame timing read-only with an "Override" option.
```

---

## Prompt 8 — Console

```
Design the Console tab of the bottom dock. It shows output from what the Studio runs: the code
generator (build_runner watch), the running game (flutter run) and the Studio's own events.

Content
- Source filter: All, Generator, Game, Studio; level filter (info / warning / error) with counts;
  SearchField; Clear; auto-scroll toggle.
- Log lines in mono-console with timestamp, source chip, level colour; multi-line stack traces
  collapsible; file:line links that open the user's external editor.
- Studio's own events styled distinctly ("Scene reloaded on iPhone 16 Simulator", "Game stopped
  (exit code 0)").
- The debugger URI is a secret and never appears: the Studio shows "Debugger available ·
  Attach debugger" instead, and any raw line that carries the URI shows it redacted
  (ws://127.0.0.1:53712/••••/ws).

States to show
1. Normal mixed output while a game runs, including hot reload lines.
2. Generator error with an expanded, clickable stack trace.
3. Game crashed / exited with an error: Banner "Game exited (code 1)" with "Run again".
4. Filtered to warnings only, with counts on the filters.
5. Generator in external mode: an info line "build_runner is running outside the Studio; its
   output appears in that terminal."
6. A redacted debugger line and the "Debugger available" event.
7. Empty state before anything has run.
```

---

## Prompt 9 — Play, devices and Attach

```
Design the Play flow in the main toolbar. The Studio runs the game on a device with the user's
Flutter SDK; the IDE can attach its debugger to that running game.

Content
- Device dropdown (from the DeviceChip): devices grouped (Simulators & emulators, Physical
  devices, Desktop) with platform icons and connection state; simulators / emulators that aren't
  running are listed too and boot when chosen ("Booting…"); "Refresh devices". Desktop devices
  appear only if the project has that platform; web is not offered. The last choice is remembered
  per project.
- Play cluster: Play (primary, the filled Play glyph) and Stop (IconButton, disabled with
  "The game is not running"). States: Ready, Booting device, Building (progress + elapsed time +
  Cancel), Running, Error. While running, Hot reload and Restart game (hot restart) are available
  (as Play's split-button menu or next to it — choose one). There is no "Play in window": the game
  always runs on the chosen device.
- "Attach debugger" Button while running: copies this run's debugger URI (it changes every run)
  and opens a popover with the URI masked, a Copy button, and short steps for VS Code ("select the
  game's device in the status bar, run Flutter: Attach to Process, paste") and Android Studio,
  a note that VS Code may show a stale "paused" state after a hot restart, and an "Add VS Code
  attach config…" link (shows the .vscode/launch.json diff before writing). An "IDE attached"
  indicator when a debugger is connected.
- Unauthenticated mode (a development-only project setting, off by default, only for devices on
  this machine): an "Unauthenticated" warning Badge next to Stop while such a run is active.
- Hot reload on Dart changes: "Waiting for generator…" while build_runner is busy, then
  "Reloading…".
- Toasts while running: "Scene reloaded on <device>"; "Image changed — Restart game" (with a
  Restart action).

States to show
1. Dropdown open with several devices: one running, one emulator not booted, one offline phone
   hidden; desktop group with macOS.
2. First build in progress (can take minutes): progress with elapsed time and a "Show log" link.
3. Running, with a recent "Scene reloaded" toast and the Attach debugger popover open.
4. Running, with the "Image changed — Restart game" toast.
5. Running with an IDE attached and the Unauthenticated Badge.
6. Build failed: error state, "Show in Console".
7. Game stopped from outside the Studio (crash, IDE stop, window closed): "Game stopped", Play
   available again.
8. Fallback mode: Toast / Banner "Reloads paused while an IDE is attached — reload from your
   IDE".
9. Unauthenticated run refused because the debugger address isn't local: error Dialog
   explaining why the run was stopped.
10. Closing the project or quitting while the game runs: Dialog "Stop the game and close
    Platformer?" Stop and close / Cancel.
11. No devices found: empty state in the dropdown with a help link.
12. Early preview variant: the device chip is fixed to "macOS", no dropdown.
```

---

## Prompt 10 — "Add Flame Studio to this project" flow

```
Design the setup flow shown when a user opens a Flame project that doesn't use Flame Studio yet.
It's a modal Dialog (form width), 3 steps.

Content
1. Explanation: what will be added — the flame_studio_runtime and flame_studio_generator
   dependencies, build_runner (2.14 or later; an existing older one is upgraded), a build.yaml,
   an assets/scenes/ folder and its pubspec.yaml asset entry — and the promise "Nothing else in
   your project is changed. Your main.dart is not edited."
2. Review: a file-change list with a readable diff for pubspec.yaml and the new files. Checkbox
   "Run flutter pub get and start the code generator".
3. Progress + result: steps with status dots (Updating pubspec.yaml, flutter pub get, generator
   first run). Success: the one line to add to the game, ready to copy
   (world.add(await StudioScene.load('assets/scenes/level_1.scene.json', registry: studioRegistry))),
   a note that lib/flame_studio.g.dart and lib/flame_studio.manifest.json are generated and
   meant to be committed, and "Create first scene" (primary). Failure: error details and
   "Open Console".

Variants
- Unsupported Flame version: which version was found, that Hot-swap needs Flame 1.36 or later,
  and "Continue anyway" / "Cancel".
- Upgrade runtime: the same review + progress steps for a project whose flame_studio_runtime is
  older than this Studio supports ("Upgrade flame_studio_runtime 0.1.2 → 0.2.0").
```

---

## Prompt 11 — Settings, About, warnings & empty states

```
Design:

A. Settings window (sidebar sections):
   - General: theme (Dark; Light "coming later", disabled), recovery copy interval (the Studio
     never saves scene files on its own; it keeps a recovery copy for crashes).
   - Flutter SDK: detected path, version and source (.fvmrc / FLUTTER_ROOT / PATH), override path
     picker, "Re-detect".
   - External editor: VS Code, Android Studio / IntelliJ, custom command — used by "Open in
     editor" and Console file:line links.
   - Play: "Hot-reload on Dart changes" (on by default); per project, "Allow unauthenticated
     debugger connections (development only)", off, with a warning that anyone on this machine
     can then control the game.
   - Viewport: grid colour, default snapping, gizmo size; per project, the reference
     rectangle's resolution (e.g. 1280×720).
   - Keyboard shortcuts: searchable list, rebind, conflict warning.

B. About window: app version, "Community project, not affiliated with the Flame team", MIT
   licence, links, and "Third-party licences".

C. A sheet of the global warning / error / empty patterns used across the app:
   - Unsaved changes on closing a scene tab or the window (Save / Don't save / Cancel).
   - Scene file from a newer Studio: can't open, says which version is needed.
   - Scene upgraded from an older format: info Banner "Upgraded from format v2 — will be saved as
     v3".
   - Project's Runtime can't read the current format: saving blocked with "Upgrade runtime…";
     project's Runtime newer than this Studio: "Update Flame Studio".
   - External change to the open scene file: Banner with Reload / Keep mine.
   - Restore after a crash (recovery copy found).
   - Generated types out of date / generator not running / external build_runner.
   - Missing behavior, Missing component, missing asset, broken entity reference, duplicate
     sibling names, unused values (inline variants).
   - Empty states: no scene open, no Behaviors in the project ("Create a class extending
     Behavior and annotate it with @StudioBehavior()"), no assets, no devices.
```

---

## Sync log

**2026-10-18** — synced with the plan through Q85 and the built `flame_studio_ui`:

- Prompt 0 marked done and kept as the record; added the shared preamble (component names,
  EditorShell layout, glossary words, "New patterns" list) and the status table.
- Prompt 2 follows the EditorShell: title bar, Play cluster in the toolbar centre, scene tabs
  (several open scenes, chosen over the old scene switcher), bottom dock under the centre
  column, viewport toolbar as a strip; status bar gets the external / stopped generator states
  (*Q77*); adds the 1280×800, panel-focus and no-scene frames.
- Removed what the plan doesn't have: node and Behavior enable toggles, autosave (*Q55*: recovery
  copy only), Copy / Paste of Nodes, Priority, "Play in window", a game-camera rectangle read from
  the game.
- Added states the plan requires: Runtime compatibility (*Q49*), crash recovery (*Q55*),
  duplicate sibling names (*Q51*), Missing component (*Q50*), unused values and type conversion
  (§11), delete-referenced-Node warning, Behavior compatibility and EntityMixin (*Q50, Q57*),
  read-only fields in the early preview (*Q82*), entity-reference picking in the viewport,
  one `.anim.json` per spritesheet (*Q54*), redacted debugger URI and "Debugger available"
  (*Q81*), Attach guide details, IDE-attached fallback (*Q74*), quit-while-running (*Q63*),
  setup success snippet and committed generated files (*Q30, Q68*), Upgrade runtime flow, About
  window (§12, *Q36*), Play settings (*Q61, Q81*).
- "How to use" and the preamble: views go in their own documents, one per view, not in the
  design-system document.
- Three additions proposed here and accepted as *Q85*: the recovery copy interval setting, the
  per-project viewport reference rectangle, and the "Not in pubspec.yaml" folder warning.

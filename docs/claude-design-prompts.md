# Flame Studio — Claude Design Prompts

How to use: paste **Prompt 0 (design system)** first and keep it as the shared context. Then run one
view prompt at a time (1–11), always in the same design-system context. Each view prompt lists the
states and interactions to show — ask for every listed state as a separate frame.

The output is a *reference design*. It will be re-implemented by hand in Flutter, so prompt 0 asks for
things that translate cleanly to Flutter widgets.

---

## Prompt 0 — Design system

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

## Prompt 1 — Project list (welcome window)

```
Using the Flame Studio design system, design the welcome / project list window shown when the
app starts (a smaller window, ~960×640).

Content
- App name and version, link to docs and GitHub.
- Recent projects list: project name, path (monospace, truncated in the middle), Flame version
  detected, last opened, a small status badge ("Ready", "Not set up", "Folder missing").
- Actions: "Open project…" (folder picker), "Remove from list" (hover action / context menu).
- Footer: detected Flutter SDK (version + path, "fvm" badge if pinned) with a "Change…" link.

States to show
1. Several recent projects, one hovered.
2. First launch: empty state ("Open a Flame project to get started").
3. Flutter SDK not found: blocking banner with "Locate Flutter SDK…" action; open buttons disabled.
4. A project whose folder no longer exists (greyed, "Folder missing", "Locate…" / "Remove").
```

---

## Prompt 2 — Editor shell & main toolbar

```
Using the Flame Studio design system, design the main editor window (1440×900) for an open project.

Layout (fixed, resizable panels — no docking/tabs-dragging)
- Top toolbar.
- Left: Hierarchy panel (~260px).
- Centre: Viewport with its own small overlay toolbar.
- Right: Inspector panel (~320px).
- Bottom: tabbed area with "Assets" and "Console" (~220px), collapsible.
- Status bar at the very bottom.
Show the splitters between panels (hover and dragging states).

Top toolbar, left to right
- Project name + current scene name with an unsaved-changes dot; scene switcher dropdown.
- Undo / Redo (with disabled states).
- Transform tool group: Select, Move, Rotate, Scale (segmented, keyboard shortcuts in tooltips).
- Snapping toggle + grid size dropdown.
- Right side: device dropdown (e.g. "iPhone 16 Simulator", "Pixel 8 Emulator", "macOS"),
  Play / Stop button (accent colour), Hot-reload indicator.

Status bar
- Code-generation status dot + text ("Types up to date" / "Generating…" / "Generator error —
  see Console"), warning count (click → filter Console), cursor world coordinates, zoom level.

States to show
1. Normal editing, a node selected.
2. Game running on a device: Play becomes Stop, device chip shows "Running", subtle accent
   outline on the toolbar.
3. Code generation failing: status bar error state, Play shows a warning tooltip.
4. Bottom panel collapsed.
```

---

## Prompt 3 — Hierarchy panel

```
Using the Flame Studio design system, design the Hierarchy panel: a tree of the nodes in the
current scene.

Content
- Panel header: "Hierarchy", "+" add-node button (menu: Entity, Sprite, Animated Sprite,
  Rectangle Hitbox, Circle Hitbox, Polygon Hitbox, Tiled Map, custom components from the project),
  search/filter field.
- Tree rows: chevron, type icon, name, optional tag pills, trailing badges (warning icon for
  missing behavior / asset, prefab icon), visibility toggle on hover.
- Scene root row at the top.

Interactions & states to show
1. A ~20-node tree, some expanded, one selected, one hovered.
2. Multi-selection (shift / cmd-click).
3. Inline rename of a row.
4. Drag and drop reparenting: drop-above, drop-inside and drop-below indicators; an invalid drop
   (into its own child) indication.
5. Right-click context menu: Rename, Duplicate, Delete, Add Child ▸, Copy / Paste, Select in
   Viewport, with shortcuts.
6. A node with a "Missing behavior" warning badge and tooltip.
7. Filter active with matches highlighted and non-matching parents dimmed.
8. Empty scene state ("Add your first node").
```

---

## Prompt 4 — Viewport

```
Using the Flame Studio design system, design the scene Viewport: a 2D canvas showing the game
scene being edited (pixel-art platformer sample content is fine).

Content
- Infinite canvas with a subtle grid and world origin axes; the game's camera/viewport bounds
  drawn as a labelled rectangle.
- Sprites and animated sprites drawn as in the game; hitboxes drawn as coloured outlines
  (toggleable).
- Custom components that can't be drawn: a placeholder box with the class name and an icon,
  sized to the component's size, clearly different from real art.
- Overlay toolbar (top-left of the viewport, floating): zoom %, "fit selection", "fit scene",
  toggles for grid / hitboxes / camera bounds.

Interactions & states to show
1. One node selected with the Move gizmo (X/Y arrows + centre square, axis colours).
2. Rotate gizmo and Scale gizmo variants.
3. Multi-selection with a shared bounding box.
4. Marquee (rubber-band) selection in progress.
5. Snapping active while dragging: snap guide lines and a small position readout.
6. Hover highlight on an unselected node with its name label.
7. Drag-and-drop from the asset browser: an image being dropped creates a sprite (ghost preview).
8. Empty scene: centred hint ("Drag an image here or add a node from the Hierarchy").
```

---

## Prompt 5 — Inspector

```
Using the Flame Studio design system, design the Inspector panel, which edits the selected node.

Content, top to bottom
- Header: node type icon, editable name, tags editor (pills + add), enable/disable toggle.
- Transform section: Position (Vector2), Angle (degrees), Scale (Vector2), Size (Vector2),
  Anchor (3×3 picker + Vector2), Priority (int).
- Built-in component sections where applicable:
  • Sprite: image asset slot (thumbnail), source rect, flip X/Y, paint/opacity
  • Animated Sprite: animation asset slot (.anim.json), playing toggle, preview strip of frames
  • Hitbox: shape type, size/radius/vertices, collision type (active / passive / inactive)
- Behaviors: each behavior is a collapsible card (class name, file path link "Open in editor",
  enable toggle, overflow menu: Remove, Move up/down, Reset). Its @Editable fields are rendered
  with the property-row components; fields not overridden show "default from code".
- "Add Behavior" button opening a searchable list of behaviors found in the project
  (name, source file, short doc comment).

States to show
1. An entity with transform, sprite and two behaviors with a mix of field types (double with
   range slider, enum, Vector2, Color, asset reference, entity reference).
2. Multi-selection of 3 nodes: shared fields editable, differing values as "mixed".
3. "Missing behavior: Patrol" card: explanation, the preserved field values shown read-only,
   actions "Remove" and "Keep".
4. A field whose referenced asset is missing (error state with "Locate…").
5. The Add Behavior search popup with results and an empty-result state.
6. Nothing selected: empty state ("Select a node to inspect it").
7. Types out of date (generator running): non-blocking banner at the top of behavior cards.
```

---

## Prompt 6 — Asset browser

```
Using the Flame Studio design system, design the Assets tab of the bottom panel: a browser of the
project's assets folder.

Content
- Left: folder tree of the project's asset folders.
- Right: grid of thumbnails (images, spritesheets, .anim.json animations with a play-on-hover
  preview, .tmx Tiled maps, audio files with a waveform icon, scene files). Toggle to list view
  (name, type, size, path).
- Toolbar: breadcrumb path, search, filter by type, thumbnail size slider, "Import…" button.

Interactions & states to show
1. Grid view with mixed asset types, one selected, one hovered.
2. List view.
3. Dragging an asset out (towards the viewport / an inspector slot).
4. Context menu: Rename, Reveal in Finder, Open Slicer (for images), Delete, Copy path.
5. Rename that will update references: confirmation dialog listing "3 scenes and 2 animations
   reference this file — references will be updated".
6. Importing files into a folder not yet listed in pubspec.yaml: notice "This folder will be
   added to pubspec.yaml assets" with a small diff preview.
7. Empty folder state and "no search results" state.
```

---

## Prompt 7 — Grid slicer & animation editor

```
Using the Flame Studio design system, design the Spritesheet Slicer: a large modal (or full
window) opened from an image asset, used to slice a spritesheet into frames and save animations
as .anim.json files.

Content
- Left: the spritesheet at zoomable scale with the slicing grid overlaid; frames numbered.
- Right sidebar: slicing settings (cell width / height, offset X/Y, spacing X/Y, rows/columns
  auto-detected), and a list of animations defined from this sheet.
- Animation editor area (bottom or right): name, ordered frame strip (drag to reorder, remove
  frame), per-frame duration or a global FPS / step time, loop toggle, live preview player
  (play/pause, speed).
- Footer: "Save animations" (writes .anim.json files, shows target paths), Cancel.

States to show
1. Fresh sheet: grid being configured, frames highlighted as cells.
2. Selecting frames on the sheet (click / shift-click / drag) to build an animation.
3. Two animations defined ("walk", "idle"), one being previewed.
4. Validation errors: cell size doesn't divide the image (warning), duplicate animation name.
5. An Aseprite-import variant (v0.2): tags from the .aseprite JSON listed as animations,
   read-only frame timing with an "override" option.
```

---

## Prompt 8 — Console panel

```
Using the Flame Studio design system, design the Console tab of the bottom panel. It shows output
from the child processes the studio runs: the code generator (build_runner watch) and the running
game (flutter run).

Content
- Source selector: "All", "Generator", "Game"; level filter (info / warning / error); search;
  clear; auto-scroll toggle.
- Log lines in monospace with timestamp, source chip, level colour; multi-line stack traces
  collapsible; file:line links that open the user's code editor.
- Studio's own messages (e.g. "Scene hot-swapped on iPhone 16 Simulator") styled distinctly.

States to show
1. Normal mixed output while a game runs.
2. Generator error with an expanded, clickable stack trace.
3. Game crashed / exited with an error: banner "Game exited (code 1)" with "Run again".
4. Filtered to warnings only, with counts on the filter chips.
5. Empty state before anything has run.
```

---

## Prompt 9 — Play & device selection

```
Using the Flame Studio design system, design the Play flow in the top toolbar.

Content
- Device dropdown: devices grouped (Simulators/Emulators, Physical devices, Desktop) with
  platform icons and connection state; simulators/emulators that aren't running are listed too
  and boot when chosen ("Booting…"); "Refresh devices". Desktop devices appear only if the
  project has that platform; web is not offered.
- Play button states: Ready, Booting device, Building (progress + elapsed time + Cancel), Running
  (becomes Stop, plus a Hot-reload button and a "Restart" in an overflow), Error.
- "Attach debugger" button while running: copies the debugger URL, with a popover showing it,
  short "VS Code" / "Android Studio" instructions, and an optional "Add VS Code attach config…"
  link. A small "IDE attached" indicator when a debugger is connected.
- Small transient toasts while running: "Scene reloaded on <device>"; "Image changed — Restart
  game" (with a Restart action).
- Status-bar generator indicator: up to date / generating / error / "External build_runner".

States to show
1. Dropdown open with several devices: one running, one emulator not yet booted.
2. First build in progress (can take minutes): progress state with "Show log" link.
3. Running, with a recent hot-swap toast and the Attach debugger popover open.
4. Running, with the "Image changed — Restart game" toast.
5. Build failed: error state, "Show in Console" action.
6. Game stopped from outside the Studio (crash or IDE): "Game stopped" state, Play available again.
7. No devices found: empty state in the dropdown with help link.
```

---

## Prompt 10 — "Add Flame Studio to this project" flow

```
Using the Flame Studio design system, design the setup flow shown when a user opens a Flame
project that doesn't use Flame Studio yet. It's a modal dialog, 2–3 steps.

Content
1. Explanation step: what will be added (the runtime and generator dependencies, build_runner,
   a build.yaml, an assets/scenes/ folder and its pubspec.yaml asset entry) and the promise
   "Nothing else in your project is changed."
2. Review step: a file-change list with a readable diff for pubspec.yaml and the new files.
   Checkbox "Run flutter pub get and start the code generator".
3. Progress + result: steps with status dots (Updating pubspec, pub get, generator first run),
   success state with "Create first scene" primary action; failure state with error details and
   "Open Console".

Also show the "project uses an unsupported Flame version" warning variant: which version was
found, which is supported, and a "Continue anyway" / "Cancel" choice.
```

---

## Prompt 11 — Settings, warnings & empty states sheet

```
Using the Flame Studio design system, design:

A. Settings window (sidebar sections): General (theme, autosave interval), Flutter SDK (detected
   path, version, fvm detection, override path picker, "Re-detect"), External editor (VS Code,
   Android Studio/IntelliJ, custom command — used for "Open in editor" links), Viewport (grid
   colour, default snapping, gizmo size), Keyboard shortcuts (searchable list, rebind).

B. A sheet of all global warning/error/empty patterns used across the app, for consistency:
   - Unsaved changes dialog on close/switch scene (Save / Don't save / Cancel)
   - Scene file from a newer studio version (can't open, explanation)
   - Scene migrated from an older format (info banner "Upgraded from format v2 — will be saved as
     v3")
   - External change detected on the open scene file (Reload / Keep mine)
   - Generated types out of date / generator not running
   - Missing behavior, missing asset, broken entity reference (inline variants)
   - Empty states for: no scene open, no behaviors in project ("Create a class extending Behavior
     and annotate it with @StudioBehavior"), no assets
```

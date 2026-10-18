# Flame Studio — UI components plan

| | |
|---|---|
| **Status** | Built (2026-10-18): every component, the EditorShell, the icons, the gallery with one golden per page, and a side-by-side review against `preview.html` |
| **Date** | 2026-10-17 |
| **Scope** | `packages/flame_studio_ui`: the 29 components and the EditorShell of the Claude Design design system, their shared foundations, the icon set, a gallery app and the tests |
| **Decisions** | *Q83* (package boundary), *Q84* (this plan) |
| **Sources** | The design system in Claude Design (`project/README.md`, `components/<Name>/README.md` and `preview.html`, `design-system.json`); `packages/flame_studio_ui/`; [`project-plan.md`](project-plan.md) §8.6, §14 |

The design system's component guidelines already give each widget's inputs ("Consumer provides")
and every state (`preview.html`). So the widgets can be built ahead of the panels, against a gallery,
instead of one at a time as panels need them. This plan says what each widget's Dart API is, what
it depends on, in what order to build it and how long it takes. It contains no widget code.

---

## Contents

1. [Rules every widget follows](#1-rules-every-widget-follows)
2. [Shared foundations](#2-shared-foundations)
3. [Components](#3-components)
4. [EditorShell](#4-editorshell)
5. [Icons](#5-icons)
6. [Gallery app and tests](#6-gallery-app-and-tests)
7. [Decisions for the user](#7-decisions-for-the-user)
8. [Order and estimate](#8-order-and-estimate)
9. [Files](#9-files)

---

## 1. Rules every widget follows

- **Domain-free (*Q83*).** Widgets take plain values (`String`, `double`, `bool`, `Color`,
  `IconData`, `Widget`) and callbacks. No Node, asset, device, scene or Type catalog types. Where
  the design names a domain thing, the API takes what is drawn: a label, an icon, a flag. Payloads
  that pass through a widget untouched (drag data, dropdown values, menu results) are a generic `T`.
- **One widget per component, `Fs` prefix**, one file per component under `lib/src/<group>/`,
  exported from `flame_studio_ui.dart`. A component that has variants takes an enum
  (`FsButtonVariant.primary`), not separate classes.
- **Colours from tokens only.** `FsColors.of(context)` and `FsShadows`; no hex literals, no
  opacity for disabled (the design says never), no Material `InkWell`, no ripples.
- **States through one wrapper** (§2.1). Every interactive widget reports `hovered`, `pressed`,
  `focused` (keyboard only), `disabled`, `selected` and `error` through `FsInteractive`, so
  states look and behave the same everywhere.
- **`onX == null` means disabled**, as in Flutter. A disabled control still shows its tooltip
  (the design: "say why").
- **Disabled controls are out of the Tab order**, as in native toolkits: a focused control that
  ignores Enter feels broken, and dead stops slow keyboard use down. The exception is opt-in,
  per control: `focusableWhenDisabled: true` (on `FsInteractive`, `FsButton` and
  `FsIconButton`) keeps the Tab stop so keyboard users can reach the tooltip's disabled reason
  ("Run game" with no device connected). Use it only for the few commands whose reason lives in
  the tooltip; prefer showing the reason where it can always be read (a banner, the empty
  state, the status bar). Menus and roving groups keep skipping disabled items, as macOS does.
- **Fixed heights** from `FsSizes`; rows never grow with content.
- **Value conventions shared by the Inspector widgets:**
  - `FsValueSource { codeDefault, overridden }`: how the PropertyRow draws the label and whether
    it shows the reset button. The words are the design's ("default from code", "overridden"); the
    widget doesn't know what an Override is.
  - Mixed values: the value parameter is nullable and `mixed: true` draws "—". For `Vector2Property`
    each axis has its own `mixed` flag.
  - Continuous editing: `onChanged(value)` while scrubbing or dragging, then `onCommit(value)`
    once per gesture or edit, which the app turns into one undo entry (design: "one undo entry per
    scrub gesture").
- **Text from the caller.** Widgets show the strings they are given and add none of their own,
  except the design's fixed glyphs ("—", "×").

---

## 2. Shared foundations

Built first. Every component below uses one or more of them.

### 2.1 `FsInteractive`: the interaction-state wrapper

A widget that turns pointer and keyboard input into a `Set<WidgetState>` and hands it to a
builder. Every button, field box, row, tab, segment, slot and menu item is built on it.

```dart
FsInteractive({
  required Widget Function(BuildContext, Set<WidgetState> states) builder,
  VoidCallback? onPressed,           // null = disabled
  bool selected = false,
  bool error = false,
  WidgetStatesController? statesController, // for callers that need to drive or read states
  FocusNode? focusNode,
  bool autofocus = false,
  bool focusable = true,             // false inside roving-focus groups (Toolbar, SegmentedControl)
  bool focusableWhenDisabled = false, // keep the Tab stop while disabled (§1, disabled controls)
  MouseCursor cursor = SystemMouseCursors.basic,
  Map<ShortcutActivator, Intent>? shortcuts,
  Map<Type, Action<Intent>>? actions,
  String? semanticsLabel,
  bool? semanticsToggled,            // ToggleButton
})
```

- Built on `FocusableActionDetector` and a `WidgetStatesController`; `ActivateIntent`
  (Enter/Space) calls `onPressed`.
- **Keyboard-only focus ring:** `focused` is added only while
  `FocusManager.instance.highlightMode == FocusHighlightMode.traditional`; it listens to
  `addHighlightModeListener`, so a mouse click never shows the ring.
- **Disabled** controls drop out of the Tab order unless `focusableWhenDisabled`. With it, a
  disabled control takes focus and shows the ring, is still announced as disabled, and swallows
  Enter and Space; `onPressed`, `shortcuts` and `actions` stay inactive until it is enabled.
- **Pressed** comes from a `Listener` (pointer down and up inside), not a `GestureDetector`, so
  the wrapper can sit inside drag sources (TreeRow) without fighting the gesture arena.
- **Forced states for the gallery and goldens:** an `FsDebugStates` InheritedWidget, read only in
  debug and profile builds, adds a fixed set of states to every `FsInteractive` below it. This is
  how the gallery shows Hover, Pressed and Focused side by side like `preview.html`.
- Helpers next to it: `FsFocusRing.outside` (`FsShadows.focus`, the 2px ring outside the edge)
  and `FsFocusRing.inset` (`focusInset`, for rows in scrolling lists), and
  `FsStateColor.resolve(states, {...})`, a small map-to-colour helper.

### 2.2 `FsFieldBox`: the shared field chrome

The box drawn by TextField, SearchField, NumberField, Dropdown and the inspector fields: fill
`surface-input`, 1px border `border-control` → hover `border-strong` → focus `focus-ring` border
plus a 1px outer ring, `error` border, disabled `surface-panel` and `border-subtle`, read-only
flat. Two heights: `FsFieldSize.regular` (24) and `.dense` (20, inside property rows). It takes
`leading`, `child` and `trailing` slots and an `accentEdge` flag (scrubbing: `accent-text`
border). It has no text logic of its own.

### 2.3 `FsPanelFocus`: panel-focus propagation

```dart
FsPanelFocus({required Widget child})   // inserted by FsPanel; also usable alone
static bool FsPanelFocus.of(BuildContext context) // true outside any panel
```

A `FocusScope` plus an `InheritedNotifier` that exposes `hasFocus` (the scope's
`hasFocus`, so focus anywhere inside the panel counts). TreeRow, Tabs and list rows read it to
choose `surface-selected` or `surface-selected-inactive`, and Panel uses it for the header
(title colour and the 2px `accent-text` top edge). Panel cycling (⌃Tab, ⌘1–⌘4) is the app's
business: it owns the panel order, and `FsPanel` takes a `focusNode` it can request focus on.

### 2.4 Overlay plumbing: `FsAnchoredOverlay`

One positioner for everything that floats next to an anchor: tooltips, Dropdown lists,
ContextMenu and SplitButton menus, the colour picker popover.

- Built on `OverlayPortal` (no `OverlayEntry` bookkeeping) with a `CustomSingleChildLayout`
  that places the overlay below the anchor (or at a point, for context menus), with a gap,
  then **flips** to the other side when it doesn't fit and **shifts** to stay inside the window.
- Dismissal: outside tap (`TapRegion`), Esc (`DismissIntent`), and anchor removal.
- Menus use `RawMenuAnchor` for focus and submenus (§7.3) and only borrow the positioner;
  tooltips use `RawTooltip` (§7.4) with the same positioner as its `positionDelegate`.

### 2.5 `FsToastHost`

```dart
FsToastHost({required Widget child})            // once, above the EditorShell
FsToastController FsToastHost.of(BuildContext)
FsToastHandle controller.show(FsToastData data) // .update(...) for progress, .dismiss()
```

A host `Stack` at the bottom right with a 16px inset: newest on top, at most 3 visible (older ones
wait in a queue), 200ms enter and exit, and success/info dismissed after 4s with the timer paused
while hovered. Logging every toast to the Console is the app's job (the design says the toast
is "never the only record"), so `show` stays a plain call.

### 2.6 Platform hooks: `FsPlatformHooks`

An InheritedWidget with optional callbacks that need native code, which the app supplies from its
macOS runner (the package stays Flutter-only, *Q83*):

```dart
FsPlatformHooks({
  Future<Color?> Function()? sampleScreenColor, // ColorProperty eyedropper (§7.2)
  FsPointerLock? pointerLock,                    // NumberProperty cursor hide + wrap (§7.1)
  required Widget child,
})
```

Widgets check for the hook and hide or simplify the feature when it is missing, so the gallery and
tests run without native code.

---

## 3. Components

Estimates are in evenings (~3 h) and include the widget, its gallery page and its widget tests
(§6). "Uses" lists the foundations and other components each widget is built from.

### 3.1 Actions

#### `FsButton`: 0.5

```dart
FsButton({
  required String label,
  required VoidCallback? onPressed,
  FsButtonVariant variant = FsButtonVariant.secondary, // primary, secondary, ghost, danger
  IconData? icon,
  String? tooltip, String? shortcut,
  FocusNode? focusNode, bool autofocus = false,
})
```

States: default, hover, pressed, focused, disabled, per variant (4 × 5 in `preview.html`), plus
with-icon. No selected or error state (the design: use ToggleButton, or put the error on the
field). Uses: `FsInteractive`, `FsTooltip`.

#### `FsIconButton`: 0.25

```dart
FsIconButton({
  required IconData icon,
  required String tooltip,          // required; also the semantics label
  required VoidCallback? onPressed,
  String? shortcut,
  bool selected = false,            // latched look
  FsIconButtonSize size = FsIconButtonSize.regular, // regular 24 (toolbar), small 20 (header, row)
})
```

States: default, hover, pressed, focused, disabled, selected; 24 and 20 sizes. Uses:
`FsInteractive`, `FsTooltip`.

#### `FsToggleButton`: 0.25

```dart
FsToggleButton({
  IconData? icon, String? label,    // at least one; icon-only draws like FsIconButton
  required bool value,
  required ValueChanged<bool>? onChanged,
  required String tooltip, String? shortcut,
})
```

States: off, hover, pressed, focused, disabled, on, on + hover (`surface-selected`), on +
focused; icon form and text form (on adds an `accent-text` border). Exposes
`Semantics(toggled:)`. Uses: `FsInteractive`, `FsTooltip`.

#### `FsSplitButton<T>`: 0.5

```dart
FsSplitButton<T>({
  required String label, IconData? icon,
  required VoidCallback? onPressed,             // main action
  required List<FsMenuEntry<T>> menuItems,      // caret menu; a check marks the current default
  ValueChanged<T>? onSelected,
  FsButtonVariant variant = FsButtonVariant.primary, // primary or secondary
  String? tooltip,
})
```

Two hit targets with their own hover and pressed states. States: default, hover main, hover
caret, pressed, focused, open, disabled; primary and secondary. Enter/Space runs the main action;
↓ or Alt+↓ opens the menu. "The main action always repeats the last choice" is the app's rule: it
passes the matching `label` and `onPressed`. Uses: `FsInteractive`, `FsContextMenu` (menu
building), `FsTooltip`.

#### `FsSegmentedControl<T>`: 0.5

```dart
FsSegmentedControl<T>({
  required List<FsSegment<T>> segments, // FsSegment(value:, icon:, label:, count:, tooltip:, shortcut:)
  required T selected,
  required ValueChanged<T>? onChanged,
})
```

States per segment: default, hover, pressed, focused (inset ring), selected, disabled; icon form
(tools) and text form (filters, with count badges). One Tab stop; ← → move and select. The single-key
tool shortcuts (Q W E R) are app shortcuts; the control only shows them in tooltips. Uses:
`FsInteractive` (with `focusable: false` per segment), `FsTooltip`, `FsBadge`.

#### `FsToolbar`: 0.5

```dart
FsToolbar({
  required List<FsToolbarGroup> leading,  // FsToolbarGroup(children: [...])
  List<FsToolbarGroup> center = const [],  // the Play cluster in the main toolbar
  List<FsToolbarGroup> trailing = const [],
  FsToolbarStyle style = FsToolbarStyle.main, // main (surface-raised) or viewport (surface-panel)
})
```

32px; buttons 2px apart inside a group; 1px × 16px `border-subtle` dividers between groups.
**Roving focus:** the toolbar is one Tab stop, ← → move between its controls (a
`FocusTraversalGroup` with a custom policy). The design's running-game state (an `accent` outline on
the toolbar, Prompt 2) is a `bool highlighted` flag. Uses: none of the others directly; hosts
any of them.

### 3.2 Inputs

#### `FsTextField`: 0.75

```dart
FsTextField({
  TextEditingController? controller, String? value, // one or the other
  String? placeholder,
  String? Function(String)? validator,  // non-null result = error state + message
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  bool mono = false,                     // paths
  bool readOnly = false, bool enabled = true,
  FsFieldSize size = FsFieldSize.regular,
  FsErrorDisplay errorDisplay = FsErrorDisplay.below, // below (one line) or tooltip (dense rows)
  FocusNode? focusNode, bool autofocus = false, bool selectAllOnFocus = false,
})
```

States: filled, empty + placeholder, path (mono); default, hover, focused, disabled, error,
read-only. Built on `EditableText` inside `FsFieldBox`, not Material `TextField` (whose
`InputDecoration` fights the 20/24px heights). Text selection colours come from `FsTheme`. Uses:
`FsFieldBox`, `FsTooltip` (error in dense rows).

#### `FsSearchField`: 0.25

```dart
FsSearchField({
  required String query,
  required ValueChanged<String> onChanged,  // live, no Enter
  String? resultLabel,      // "3 of 12"; the app formats it
  bool noMatch = false,     // "No match" in error
  String? noMatchLabel,
  String? shortcutHint,     // "⌘F", shown while empty
  VoidCallback? onExit,     // second Esc: focus back to the list
  VoidCallback? onNext, VoidCallback? onPrevious, // ↓ ↑
})
```

States: empty, with query; default, hover, focused, disabled, no results. Uses: `FsTextField`
internals, `FsFieldBox`.

#### `FsNumberField`: 0.5

```dart
FsNumberField({
  required double? value, bool mixed = false,
  FsNumberKind kind = FsNumberKind.double, // int or double
  double? min, double? max, double step = 1,
  String? unit,
  bool stepper = true,
  ValueChanged<double>? onChanged, ValueChanged<double>? onCommit,
  FsFieldSize size = FsFieldSize.regular,
  double? width,
})
```

States: plain, with unit; default, hover, scrubbing (drag the field itself), focused, disabled,
error, mixed. Shares the number-editing core with NumberProperty (parsing, expressions, ↑/↓
steps, scrub maths). Uses: `FsFieldBox`, `FsNumberEditing` (internal, see 3.3).

#### `FsDropdown<T>`: 0.75

```dart
FsDropdown<T>({
  required List<FsDropdownOption<T>> options, // FsDropdownOption(value:, label:, icon:, detail:)
  required T? value, bool mixed = false,
  required ValueChanged<T>? onChanged,
  FsFieldSize size = FsFieldSize.regular,
  bool monoOptions = false,   // enum values in the list show their Dart name in mono
  String? errorText,
})
```

States: default, hover, pressed, focused, disabled, error, mixed, open. Space, Enter and ↓
open it; type-ahead jumps to a match; the list opens on the current value; Esc closes it
without a change. The field shows `label` and the list shows `detail` (the Dart name, e.g.
`Anchor.center`) in mono. Uses: `FsFieldBox`, `FsAnchoredOverlay`, the `FsContextMenu` item
row (for consistent list items).

### 3.3 Inspector

#### `FsPropertyRow` (+ `FsPropertyList`): 0.75

```dart
FsPropertyList({required List<Widget> children, double initialLabelFraction = 0.4,
                ValueChanged<double>? onLabelFractionChanged}) // shares one label column
FsPropertyRow({
  required String label,           // the Dart name, verbatim
  required Widget editor,
  FsValueSource source = FsValueSource.codeDefault,
  VoidCallback? onReset,           // shown when overridden
  String? resetTooltip,
  bool mixed = false, bool readOnly = false, bool enabled = true,
  String? error,
  String? tooltip,                 // type + default value, formatted by the app
  FsScrubHandle? labelScrub,       // set by NumberProperty / Vector2Property
})
```

24px; label 40% (min 72px), resizable by dragging the column boundary. `FsPropertyList` holds
the shared width so every row's boundary moves together, and reports the new width so the app
can persist it. States: default from code, overridden (2px `accent-text` bar, label
`text-primary` 500, ↺ reset), mixed, error, disabled/read-only, hover (whole row
`surface-hover`). Uses: `FsInteractive`, `FsIconButton` (reset), `FsTooltip`.

#### `FsNumberProperty`: 1.25

```dart
FsNumberProperty({
  required String label,
  required double? value, bool mixed = false,
  FsNumberKind kind = FsNumberKind.double,
  double? min, double? max, double? step,
  bool slider = false,            // range variant; needs min and max
  String? unit,                   // "px", "°", "px/s"
  FsValueSource source = FsValueSource.codeDefault, VoidCallback? onReset,
  required ValueChanged<double> onChanged,  // continuous while scrubbing
  required ValueChanged<double> onCommit,   // once per gesture or edit
  String? Function(double)? validator,      // "Expected a number between 0 and 1"
  bool enabled = true,
})
```

- **Scrub:** press on the label and drag; 1 step per 2px, Shift ×10, Alt ×0.1; label and field
  border `accent-text`; cursor ↔ (`SystemMouseCursors.resizeLeftRight`). `onCommit` fires on
  drag end. Cursor hiding and edge wrapping depend on §7.1.
- **Edit:** click or Enter edits with the value selected; Enter or Tab commits; Esc reverts;
  ↑/↓ step (Shift ×10). Simple expressions (`32*2`, `+=8`) are evaluated on commit by a small
  parser in the package (`+ - * /`, parentheses, `+= -= *= /=`); it's ~100 lines and
  needs no dependency.
- **Range variant:** a slider (track `border-control`, fill `accent`, 12px thumb) plus a 56px
  number field.
- States: int, double + unit, range slider; default, hover on the label, scrubbing,
  focused/editing, disabled, error (with its tooltip), mixed, overridden.
- Uses: `FsPropertyRow`, `FsNumberEditing` (internal: parse, format, expression, step,
  scrub), `FsFieldBox`, `FsTooltip`.

#### `FsBoolProperty` (+ `FsCheckbox`, `FsSwitch`): 0.5

```dart
FsCheckbox({required bool? value, required ValueChanged<bool>? onChanged}) // null = mixed
FsSwitch({required bool value, required ValueChanged<bool>? onChanged})
FsBoolProperty({
  required String label, required bool? value, bool mixed = false,
  FsValueSource source = FsValueSource.codeDefault, VoidCallback? onReset,
  required ValueChanged<bool>? onChanged,
  FsBoolStyle style = FsBoolStyle.checkbox, // switch only for live, unsaved toggles
})
```

States: off, on, hover, pressed, focused, disabled off, disabled on, mixed (checkbox only),
overridden. Clicking the label toggles; Space toggles. `FsCheckbox` is exported on its own:
SectionHeader and Dialog use it. Uses: `FsInteractive`, `FsPropertyRow`.

#### `FsVector2Property`: 0.5

```dart
FsVector2Property({
  required String label,
  required double? x, required double? y,
  bool mixedX = false, bool mixedY = false,
  FsValueSource source = FsValueSource.codeDefault, VoidCallback? onReset,
  bool? aspectLocked,                          // null = no lock button
  ValueChanged<bool>? onAspectLockChanged,
  required void Function(double x, double y) onChanged,
  required void Function(double x, double y) onCommit,
  bool enabled = true,
})
```

Two 20px fields with a 16px axis cell ("X" `axis-x`, "Y" `axis-y`); drag a letter to scrub that
axis, drag the label to scrub both. Keeping the aspect ratio while locked is done inside the widget
(it only has the two numbers), so `onChanged` already gets the locked pair. States:
default, hover, scrubbing Y, focused X, disabled, error Y, mixed X, overridden; with and without
the aspect lock. Tab order X → Y → next row. Uses: `FsPropertyRow`, `FsNumberEditing`,
`FsFieldBox`, `FsToggleButton` (lock).

#### `FsColorProperty` (+ `FsColorPicker`): 0.75 + 0.75

```dart
FsColorProperty({
  required String label, required Color? value, bool mixed = false,
  FsValueSource source = FsValueSource.codeDefault, VoidCallback? onReset,
  required ValueChanged<Color> onChanged, required ValueChanged<Color> onCommit,
  List<Color> recentColors = const [],   // the app keeps the list
  bool enabled = true,
})
FsColorPicker({required Color value, required ValueChanged<Color> onChanged,
               required ValueChanged<Color> onCommit, List<Color> recentColors = const []})
```

Swatch 28×16 with a 1px inner white-15% edge, 6-digit upper-case hex field, separate 52px alpha
% field. Invalid hex gives an `error` border, and the swatch keeps the last valid colour. The swatch
opens the picker popover: an SV area, a hue slider, hex + alpha, recent colours, and the eyedropper
when `FsPlatformHooks.sampleScreenColor` is set (§7.2). States: default, hover, focused hex,
disabled, error, mixed, overridden; picker open. Uses: `FsPropertyRow`, `FsFieldBox`,
`FsNumberField` (alpha), `FsAnchoredOverlay`, `FsIconButton`.

#### `FsAssetSlot<D>` and `FsEntitySlot<D>` (on a shared `FsSlot<D>`): 0.75 + 0.25

Both are a 20px reference slot that is also a drop target. They differ in their icon and their actions,
so they share one internal `FsSlot<D>` (`D` = the drag payload type the app uses):

```dart
FsAssetSlot<D>({
  required String? fileName,        // null = empty
  required String placeholder,      // "None (Sprite)"
  Widget? thumbnail, IconData typeIcon = FsIcons.image, // thumbnail wins when set
  bool missing = false, String? missingLabel,           // keeps the old name visible
  bool mixed = false, String? mixedLabel,               // "— (2 different)"
  VoidCallback? onBrowse, VoidCallback? onClear,
  VoidCallback? onReveal, VoidCallback? onOpen,         // click / double-click on the name
  FsDropAcceptance Function(D data)? willAccept,        // accept, reject, ignore
  ValueChanged<D>? onDrop,
  String Function(D data)? dropHint,                    // "Drop coin.png here"
  bool enabled = true,
})
FsEntitySlot<D>({
  required String? name, required String placeholder, // "None (CameraComponent)"
  IconData? typeIcon,
  bool missing = false, bool picking = false,          // picking: crosshair latched
  String? pickingHint,                                 // "Click a node in the scene…"
  VoidCallback? onPick, VoidCallback? onCancelPick, VoidCallback? onClear,
  VoidCallback? onReveal,                              // select and frame the node
  FsDropAcceptance Function(D data)? willAccept, ValueChanged<D>? onDrop,
  String Function(D data)? dropHint, bool enabled = true,
})
```

The *thumbnail provider* the design names is just `Widget? thumbnail`: the app builds the image,
and the package never loads files. The *accepted types* become `willAccept`, so the app decides what
fits. States (both): empty, filled, hover, focused, drop target accepts, drop wrong type
(`error` border, not-allowed cursor), missing, disabled, mixed, overridden; EntitySlot adds
picking. ⌫ clears when focused; Esc cancels picking. The "every compatible slot lights up while a
drag is in flight" behaviour comes from Flutter's `DragTarget.onWillAcceptWithDetails`, which runs
only under the pointer. So `FsSlot` also takes an optional `FsDragInFlight<D>`
(a `ValueListenable<D?>`), which the app sets while a drag runs, to show the quiet accept state
everywhere. Uses: `FsInteractive`, `FsIconButton`, `FsBadge` ("Missing"), `FsPropertyRow`.

### 3.4 Structure

#### `FsPanel`: 0.5

```dart
FsPanel({
  required String title, IconData? icon,
  List<Widget> actions = const [],          // ≤ 3 FsIconButtons
  List<FsMenuEntry<void>> overflow = const [], // the ⋯ menu
  required Widget body,
  Widget? headerProgress,                    // FsProgressBar under the header
  FocusNode? focusNode,                      // the app's panel cycling targets it
})
```

28px header (`surface-raised`, title `heading`), body `surface-panel`. Focused: title
`text-primary` plus the 2px `accent-text` top edge; unfocused: `text-secondary`. Inserts
`FsPanelFocus`. States: focused, unfocused, header action latched and hovered. Uses:
`FsPanelFocus`, `FsIconButton`, `FsContextMenu` (overflow).

#### `FsSectionHeader`: 0.5

```dart
FsSectionHeader({
  required String title, IconData? icon, String? subtitle,
  required bool expanded, required ValueChanged<bool> onExpandedChanged,
  VoidCallback? onToggleAll,           // Alt-click
  bool? enabled, ValueChanged<bool>? onEnabledChanged, // the component checkbox; null = none
  List<FsMenuEntry<void>> menu = const [],
  bool error = false,
})
```

24px; states: expanded, collapsed; default, hover, pressed, focused (inset ring), disabled
(title and icon `text-disabled`, the properties stay editable), error (alert-circle in `error`,
subtitle says why). The expand/collapse body animation (150ms) is `FsCollapsible`, a small helper
exported alongside. Uses: `FsInteractive`, `FsCheckbox`, `FsIconButton`, `FsContextMenu`.

#### `FsTabs<T>`: 0.75

```dart
FsTabs<T>({
  required List<FsTab<T>> tabs, // FsTab(value:, label:, icon:, dirty:, closable:, badges:, error:)
  required T selected,
  required ValueChanged<T> onSelect,
  ValueChanged<T>? onClose,      // ⌘W and middle-click call it too
  FsTabsStyle style = FsTabsStyle.document, // document (above the viewport) or dock (bottom)
})
```

28px. States: default, hover, pressed, focused, disabled, selected, selected in an unfocused
panel (top edge `text-secondary`), dirty (dot that becomes × on hover), error; badges for
counts. ⌃Tab / ⌃⇧Tab cycling is an app shortcut that calls `onSelect`. Uses: `FsInteractive`,
`FsPanelFocus`, `FsBadge`.

#### `FsTreeRow<T>`: 1.25

```dart
FsTreeRow<T>({
  required int depth,
  required String name, IconData? icon,
  bool hasChildren = false, bool expanded = false, ValueChanged<bool>? onExpandedChanged,
  bool selected = false, bool keyboardCursor = false,
  FsTreeRowTone tone = FsTreeRowTone.normal,  // normal, dimmed (hidden node), prefab, error
  List<Widget> badges = const [],
  List<FsTreeRowAction> actions = const [],   // visibility, lock: shown on hover, pinned when set
  VoidCallback? onTap, VoidCallback? onDoubleTap, VoidCallback? onSecondaryTap, // + position
  // Inline rename
  bool renaming = false, ValueChanged<String>? onRenameCommit, VoidCallback? onRenameCancel,
  // Drag and drop
  T? dragData, Widget Function()? dragFeedback,
  bool canHaveChildren = true,                // leaf rows: 50/50 zones
  bool Function(T data, FsDropZone zone)? canAccept,
  void Function(T data, FsDropZone zone)? onAccept,
  VoidCallback? onAutoExpand,                 // after 600ms hovering "inside"
})
enum FsDropZone { above, inside, below }
```

22px; 16px indent per level + 4px; 16px chevron box; 14px icon. States: default, hover (row
actions appear), pressed, focused (keyboard cursor, inset ring), selected with the panel focused or
unfocused, focused + selected, disabled (hidden node), error, badges, inline rename, drag over
above, inside and below, drop not allowed. The row computes the zone (§7.5), asks `canAccept`,
and paints the insertion line, inside fill or reject border. Keyboard navigation (↑ ↓ → ← Space
⇧/⌘) is the app's tree view, because only it knows siblings and parents. The row exposes
`keyboardCursor` and the panel's `Shortcuts`. Rows are meant for a `ListView.builder` over the
flattened, visible tree. Uses: `FsInteractive`, `FsPanelFocus`, `FsTextField` (rename),
`FsIconButton`, `FsBadge`.

### 3.5 Floating

#### `FsContextMenu<T>`: 1.25

```dart
sealed class FsMenuEntry<T>
  FsMenuItem<T>({required String label, IconData? icon, FsShortcutLabel? shortcut,
                 bool enabled = true, bool checked = false, bool destructive = false,
                 T? value, VoidCallback? onSelected, List<FsMenuEntry<T>>? submenu})
  FsMenuSeparator<T>()
  FsMenuHeader<T>(String label)

Future<T?> showFsContextMenu<T>(BuildContext context,
    {required Offset position, required List<FsMenuEntry<T>> entries, String? header})
FsContextMenuRegion<T>({required List<FsMenuEntry<T>> Function() entries,
                        ValueChanged<T>? onSelected, required Widget child}) // right-click
FsMenuButton<T>(...)  // anchored variant used by Dropdown-like triggers, ⋯ menus, SplitButton
FsShortcutLabel(SingleActivator activator) // renders ⌘⇧⌥⌃⌫↩ on macOS, "Ctrl+Shift+D" elsewhere
```

248px wide (min 180), 24px items, the 16px icon column always reserved. Hover and keyboard focus look
the same (`accent` fill, `text-on-accent`). Disabled items show no highlight. Destructive items are
`error`, highlighted with `error-border`. The parent of an open submenu keeps `surface-pressed`. Submenus open
after 150ms hover or →, close with ←, and Esc closes one level. States: default, hover/focus, pressed,
checked, disabled, destructive, destructive hover, submenu open, section header. Built on
`RawMenuAnchor` (§7.3). Uses: `FsAnchoredOverlay` (positioner), `RawMenuAnchor`.

#### `FsTooltip`: 0.75

```dart
FsTooltip({
  required String message, FsShortcutLabel? shortcut, List<String> details = const [],
  required Widget child,
})
FsTooltipGroup({required Widget child}) // optional; one at the app root is enough
```

`surface-overlay`, 1px `border-overlay`, `radius-sm`, `shadow-tooltip`, 4×8 padding, max
240px, `small` text, shortcut in a 16px key cap. 500ms delay, **0ms when moving between adjacent
tooltipped controls** (§7.4), hides on press or Esc, placed below with a 4px gap and flips or
shifts to stay inside the window. Also shown after the same delay when the anchor takes keyboard
focus (not on a click that moves focus) and hidden when focus leaves. Shown for disabled controls
too; keyboard users reach those only with `focusableWhenDisabled`. States in the gallery: property
label, truncated name, disabled control. Uses: `RawTooltip`, `FsAnchoredOverlay` (positioner).

#### `FsDialog`: 0.5

```dart
Future<T?> showFsDialog<T>(BuildContext context, {required FsDialog<T> dialog})
FsDialog<T>({
  required String title,             // a question or an action
  String? body, Widget? content,     // fields, a checkbox
  required FsDialogAction<T> primary,   // FsDialogAction(label:, value:)
  FsDialogAction<T>? secondary,         // "Cancel": also Esc
  FsDialogAction<T>? destructive,       // left, apart
  FsDialogWidth width = FsDialogWidth.regular, // 440 or form 560
})
```

Built on `showGeneralDialog` with the `scrim` barrier and a 200ms fade (no scale). The primary button has initial focus and answers Enter, Esc returns the secondary value,
focus is trapped (the route's `FocusScope`), and focus goes back to the trigger on close (route
default). Uses: `FsButton`, `FsIconButton` (close).

#### `FsToast`: 0.75 (with `FsToastHost`, §2.5)

```dart
FsToastData({
  required FsToastKind kind,   // success, info, warning, error, progress
  required String title, String? message,
  List<FsToastAction> actions = const [],  // ≤ 2 ghost buttons
  bool dismissible = true,
  double? progress,            // progress kind; null = indeterminate
})
```

320px, overlay surface. States: one per kind, with and without message and actions, a stack of
3, hovered (timer paused). Uses: `FsToastHost`, `FsButton` (ghost), `FsIconButton`,
`FsProgressBar`.

### 3.6 Status

#### `FsBanner`: 0.25

```dart
FsBanner({required FsStatusKind kind,   // info, warning, error, success
          required InlineSpan message,  // the caller bolds the subject
          FsBannerAction? action, VoidCallback? onDismiss})
```

States: the four kinds, with an action, with dismiss. Uses: `FsButton` (ghost, 20px),
`FsIconButton`.

#### `FsBadge` and `FsDeviceChip`: 0.5

```dart
FsBadge({required FsBadgeKind kind,  // warning, error, missing, prefab, info, success, neutral, accent
         String? label, int? count, IconData? icon, bool pill = false})
FsDeviceChip({required IconData icon, required String label, String? detail, // "852×393", "offline"
              bool selected = false, bool error = false, VoidCallback? onPressed})
```

Status badges get their icon from the kind (warning → triangle, error → alert-circle), so colour
never stands alone. `FsDeviceChip` takes an icon, a label and a detail string, so the app maps its
device model to them. States: every badge kind and the pill; chip default, hover, pressed, focused,
disabled, selected, error. Uses: `FsInteractive` (chip).

#### `FsProgressBar`, `FsSpinner`, `FsStatusDot`: 0.5

```dart
FsProgressBar({double? value, FsProgressTone tone = FsProgressTone.foreground}) // or .background (info)
FsSpinner({double size = 14})               // 16 in toolbars
FsStatusDot({required FsStatus status, required String label}) // idle, working, ok, error
FsDelayedProgress({required bool busy, required Widget child}) // shows child after 300ms
```

Under reduce-motion (`MediaQuery.disableAnimations`) spinners and the working pulse slow down
instead of stopping. States: indeterminate, determinate, spinner 14/16, the four dots.
Uses: none.

#### `FsEmptyState`: 0.25

```dart
FsEmptyState({required IconData icon, required String title, required String message,
              required FsButton action, String? shortcutHint})
```

Centred 48px tile, `title` text, the message at most 280px wide, one button (the caller picks primary or
secondary). Uses: `FsButton`.

---

## 4. EditorShell

`FsEditorShell`, 1.5 evenings: a layout that knows only slots and sizes.

```dart
FsEditorShell({
  required Widget titleBar,        // centred document title; the shell reserves the
  double titleBarLeadingInset = 78,//   macOS traffic-light zone on the left
  required Widget toolbar,         // usually an FsToolbar
  required Widget left,            // Scene / Hierarchy panel
  required Widget center,          // document tabs + viewport toolbar + viewport
  required Widget right,           // Inspector
  Widget? bottom,                  // dock (Console / Assets); null hides it
  bool bottomCollapsed = false, ValueChanged<bool>? onBottomCollapsedChanged,
  required Widget statusBar,
  required FsShellSizes sizes,     // left, right, bottom
  required ValueChanged<FsShellSizes> onSizesChanged, // during a drag
  ValueChanged<FsShellSizes>? onSizesChangeEnd,       // the app persists them per project
  FsShellLimits limits = FsShellLimits.standard,
})
```

- Regions: title bar 38, toolbar 32, three columns separated by 1px of `bg-app`, bottom dock under
  the centre column (Prompt 2 and the EditorShell preview put it there, not across the full width),
  status bar 22.
- **Seams:** each 1px line has a 4px hit area (`MouseRegion` with the ↔ or ↕ cursor and a drag
  handler). Hover and dragging show `border-strong` and `accent-text` (Prompt 2 asks for both
  states). Dragging clamps to the limits.
- **Sizes are reported, not stored:** `onSizesChanged` fires during the drag (the parent rebuilds
  with the new `sizes`) and `onSizesChangeEnd` on drag end, when the app saves them per project.
  Defaults 260 / 320 / 220.
- **Fitting the window:** the centre keeps at least 750 × 520 (`FsShellLimits.minCenterWidth`,
  `minCenterHeight`); when the docks don't fit with it, they shrink in proportion, never below
  their minimum (layout, not persisted). At the 1280×800 minimum the defaults come out at about
  237 / 291 / 187. A drag starts from the size on screen. (Built this way rather than a fixed
  240 / 288 / 180 below 1280×800: a cap on the stored size would swallow a drag that grows a
  capped dock, and a rule based on room has no jump when the window shrinks.)
- **Collapsed bottom dock:** shows its top 28px (the dock's tab strip) and keeps the dock laid out
  at its expanded height underneath, so its state survives. With `onBottomCollapsedChanged`,
  dragging the seam below half the minimum height collapses the dock and dragging it up expands it.
- The title bar draws nothing native. Hiding the macOS title bar and placing the traffic lights
  (`NSWindow` full-size content view) is app runner configuration, not package code.
- The gallery shows the full EditorShell preview with placeholder panels built from the package's
  components (§6).

Uses: `FsPanelFocus` (indirectly through the panels the app passes in), nothing else.

---

## 5. Icons

`FsIcons` grows from 11 to the 60 icons in the design system's Icons group. Each was compared
shape-by-shape against `lucide_icons_flutter` 4.0.0 in the pub cache (the design's SVGs from the
artifact against the SVG in each constant's doc comment).

**Naming rule:** each `FsIcons` member takes the **design system's icon name**, camel-cased
(`chevron-down` → `chevronDown`), and its doc comment names the Lucide glyph. That already
covers `hitbox`, and it covers the seven renamed below.

**Role names for node types: not in the package.** Node types (camera, sprite, prefab, script…)
are Studio concepts, and per *Q83* the package knows nothing about Nodes. The app keeps a
`nodeKindIcon(…)` map in its Hierarchy code. The `FsIcons` doc comment records the design's
convention (camera → video, sprite → image, sprite animation → film, text → type, hitbox → hitbox,
group → layers, world → globe, particles → sparkle, generic component → circle-dot,
component/prefab → box, script → file-code) so the app's map follows it.

### 5.1 Names that differ from Lucide, or where the same name is the wrong glyph

| Design name | `FsIcons` | `LucideIcons` | Note |
|---|---|---|---|
| `external` | `external` | `externalLink` | |
| `more` | `more` | `ellipsis` | `moreHorizontal` is an alias for it |
| `reset` | `reset` | `rotateCcw` | |
| `rotate` | `rotate` | `rotateCw` | |
| `scale` | `scale` | `maximize2` | ⚠ `LucideIcons.scale` exists but is the balance scale |
| `pointer` | `pointer` | `mousePointer2` | ⚠ `LucideIcons.pointer` exists but is a hand |
| `grid` | `grid` | `grid3x3` | `grid` is an alias for it |
| `hitbox` | `hitbox` | `squareDashed` | (already) |
| `stop` | `stop` | `square` | Lucide has no `stop`; the design draws a 14px rounded square, Lucide's is 18px, so it looks slightly larger |
| `sliders` | `sliders` | `slidersHorizontal` | ⚠ `LucideIcons.sliders` is an alias for **sliders-vertical** |
| `step-forward` | `stepForward` | `skipForward` | ⚠ `LucideIcons.stepForward` is a different glyph (bar on the left); the design's triangle + bar on the right is `skip-forward` |
| `check-circle` | `checkCircle` | `circleCheck` | ⚠ `LucideIcons.checkCircle` is an alias for **circle-check-big** (open circle, big tick); the design's is `circle-check` |
| `alert-circle` | `alertCircle` | `circleAlert` | old name is an alias; use the current one |
| `alert-triangle` | `alertTriangle` | `triangleAlert` | as above |
| `unlock` | `unlock` | `lockOpen` | as above |
| `filter` | `filter` | `funnel` | as above |
| `trash` | `trash` | `trash` | not `trash2` (that one has two inner lines) |

Five of these would have been wrong with a plain name match (`scale`, `pointer`, `sliders`,
`stepForward`, `checkCircle`). So `icons_test.dart` should pin each of these to its expected
`LucideIcons` constant, as it already does for `hitbox`.

### 5.2 The other 43: same name in Lucide

`box`, `check`, `chevronDown`, `chevronRight`, `circleDot`, `code`, `copy`, `crosshair`, `eye`,
`eyeOff`, `file`, `fileCode`, `film`, `folder`, `globe`, `image`, `info`, `layers`, `link`,
`listTree`, `lock`, `magnet`, `minus`, `monitor`, `move`, `music`, `panelBottom`, `pause`,
`pipette`, `play`, `plus`, `redo`, `save`, `search`, `smartphone`, `sparkle`, `terminal`,
`type`, `undo`, `user`, `video`, `x`, `zap`.

The shapes are the same glyph. Lucide's current drawings differ in detail (Lucide's `magnet` is
drawn diagonally, the design's is upright; `sparkle` and `play` are rounder; circles are r=10, not r=9).
The design README asks for official Lucide glyphs, so these differences are expected.

### 5.3 The filled Play

The design draws `play` filled in the Play button and nowhere else. An icon font can only draw
Lucide's outline. `FsPlayGlyph`, a ~20-line `CustomPainter` that fills the design's rounded
triangle at 16px, is used only by the Play button. `FsIcons.play` stays the outline glyph for menus
and elsewhere.

Estimate: 0.25 evening (constants, doc comments, the pinning test, `FsPlayGlyph`).

---

## 6. Gallery app and tests

### 6.1 Gallery: `packages/flame_studio_ui/example`

- A macOS Flutter app (`flutter create --platforms=macos`), added to the root `pubspec.yaml`
  workspace list, depending only on `flame_studio_ui`. Never released.
- One page per component, in the design system's groups (Actions, Inputs, Inspector,
  Structure, Floating, Status, Shell), and **one grid per `preview.html`**: the same row and column
  labels (Default · Hover · Pressed · Focused · Disabled · …) and the same sample content
  (`Add component`, `jumpForce`, `player_run.png`), so the two can be laid side by side. Static
  states come from `FsDebugStates` (§2.1); next to each grid, a live copy to try with mouse and
  keyboard.
- A last page assembles the EditorShell preview from the package's widgets with placeholder
  content. It is the integration check that the pieces fit at 1440×900 and 1280×800.
- **Comparing with `preview.html`:** open the preview in a browser at the same zoom and compare
  by eye, page by page. That is the acceptance check for each component, recorded with a tick in
  the gallery's page list. Automatic pixel comparison against HTML isn't worth building: font
  rendering differs between Chrome and Skia anyway.

### 6.2 Tests

- **Test config:** `test/flutter_test_config.dart` loads Inter, JetBrains Mono and the Lucide
  font with `FontLoader`, so tests and goldens render real glyphs (by default flutter_test draws
  every glyph as a box).
- **Widget tests per state** (in every component's estimate). Colours: pump with forced states
  and check the resolved fill, border and text colours against `FsColors.dark`. Behaviour, through
  real input: hover with a mouse `TestGesture`; keyboard focus with the highlight mode set to
  traditional (and a check that a click does **not** show the ring); scrub maths and the
  single `onCommit` with drags; DnD zones by dropping at 10%, 50% and 90% of a row; Esc, Enter and Tab;
  roving focus in Toolbar and SegmentedControl; tooltip delay and hand-off with
  `tester.pump(duration)`; toast auto-dismiss and hover pause.
- **Goldens: yes, but one per gallery grid** (~30 files), not one per state. They are the only
  automatic check that a component still *looks* like its `preview.html` after a token or layout
  change, and the tokens test can't see layout. Restrictions keep them cheap: tagged `golden`, run
  only in the macOS CI job (goldens differ between platforms), and refreshed deliberately with
  `--update-goldens` when the design changes. ~0.75 evening for the harness, plus a few minutes per
  component (in its estimate).
- **Out of scope here:** the panels' tests (§13 of `project-plan.md`, "Panels: Light") stay in the
  app.

Estimate: gallery skeleton, test config and golden harness, 0.75 evening.

---

## 7. Decisions for the user

### 7.1 NumberProperty: hide and wrap the cursor while scrubbing

Flutter can hide the cursor (`SystemMouseCursors.none`), but it can't move it. Wrapping at the screen
edges needs native code (macOS `CGWarpMouseCursorPosition` or
`CGAssociateMouseAndMouseCursorPosition(false)`, a ~40-line method channel in the app's runner).
Without wrapping, hiding the cursor is worse than not hiding it: the hidden pointer stops at the screen
edge and the scrub stops with it, and the user can't see why.

**Recommendation: drop hiding and wrapping for v0.1.** Keep the ↔ cursor visible. The 2px-per-step rate with Shift
×10 covers large ranges, and a second drag continues from the new value. The package defines
`FsPointerLock` in `FsPlatformHooks` (§2.6), so the macOS runner can add hide + wrap later without
changing the widget's API. Revisit if the early-preview testers scrub large values.

### 7.2 ColorProperty: the eyedropper

Sampling the screen needs native code. On macOS that's `NSColorSampler` (10.15+), ~30 lines
in the runner, and it also covers the system colour panel's loupe UI.

**Recommendation: ship the picker without the eyedropper first.** The button appears only when
`FsPlatformHooks.sampleScreenColor` is set. Add the `NSColorSampler` channel in the app when Color
fields land (v0.1 work item 5, ~0.25 evening). Sampling only the game viewport, with
`RenderRepaintBoundary.toImage`, is a portable fallback for Windows and Linux in v0.3.

### 7.3 ContextMenu: `flutter_context_menu` or Flutter's menu widgets

`project-plan.md` §8.6 currently says the author's `flutter_context_menu` package provides context
menus. It does submenus, headers, dividers and custom entries, and its theming starts from the Material
theme. Its documentation says nothing about keyboard navigation, shortcut labels or checked items, which the design
requires (→ opens and ← closes submenus, Esc closes one level, focus = hover highlight, parent
item keeps `surface-pressed`). It would also be a second dependency in a package *Q83* limits to
Flutter plus the icon font and the bundled fonts.

Flutter 3.44 has **`RawMenuAnchor`** in the widgets layer (no Material styling). It handles nested
menus, focus traversal with arrow keys, Esc, outside taps and `onOpenRequested`/`onCloseRequested`
hooks, which give the 150ms submenu delay and the open animation. Material's `MenuAnchor` sits on
the same base but adds Material styling to override.

**Recommendation: build `FsContextMenu` on `RawMenuAnchor`** and drop `flutter_context_menu` from
the plan. It keeps the package Flutter-only, the keyboard behaviour comes from the framework, and
the same base serves Dropdown lists, SplitButton menus and the ⋯ menus. If `flutter_context_menu`
should stay in use elsewhere, it can be ported to `RawMenuAnchor` as a separate project.

### 7.4 Tooltip: the 0ms hand-off

Material's `Tooltip` uses the same `waitDuration` for every show, so it can't do "0ms when moving
between adjacent tooltipped controls". Flutter 3.44 has **`RawTooltip`** in the widgets layer:
no Material look, a per-instance `hoverDelay`, a `positionDelegate`, and dismissal on tap and on
`dismissAllToolTips`.

**Recommendation: a custom `FsTooltip` on `RawTooltip`, not one from scratch.** The only custom
part is the hand-off. `FsTooltipGroup` holds a "warm" flag that is set while any tooltip is visible
and for ~300ms after it hides. Each `FsTooltip` listens to it and rebuilds its `RawTooltip`
with `hoverDelay: Duration.zero` while warm and 500ms otherwise. Esc and hide-on-press come from
`RawTooltip`'s dismissal plus a `TapRegion`. This saves rebuilding hover tracking, the overlay and
semantics, ~0.5 evening less than a widget from scratch.

### 7.5 TreeRow: who decides whether a drop is allowed

**Recommendation: yes, the row only computes the zone.** It works out `FsDropZone` from the
pointer's height in the row (top 25% above, middle 50% inside, bottom 25% below; 50/50 above/below
when `canHaveChildren` is false), then asks the app's `canAccept(data, zone)` and paints the
result: insertion line, inside fill, or reject border with the not-allowed cursor. "Into its own
child", type rules and prefab locks are tree knowledge that lives in the app. The only thing the
row adds is the 600ms auto-expand timer (`onAutoExpand`), because that is about the pointer resting
on the row.

---

## 8. Order and estimate

### 8.1 Estimate

| Group | Items | Evenings |
|---|---|---|
| Foundations | `FsInteractive` + focus ring + forced states 1 · `FsFieldBox` 0.5 · `FsPanelFocus` 0.25 · `FsAnchoredOverlay` 0.5 · icons 0.25 · gallery, test config, golden harness 0.75 | 3.25 |
| Actions | Button 0.5 · IconButton 0.25 · ToggleButton 0.25 · SplitButton 0.5 · SegmentedControl 0.5 · Toolbar 0.5 | 2.5 |
| Inputs | TextField 0.75 · SearchField 0.25 · NumberField 0.5 · Dropdown 0.75 | 2.25 |
| Inspector | PropertyRow 0.75 · NumberProperty 1.25 · BoolProperty 0.5 · Vector2Property 0.5 · ColorProperty 0.75 + picker 0.75 · AssetSlot 0.75 · EntitySlot 0.25 | 5.5 |
| Structure | Panel 0.5 · SectionHeader 0.5 · Tabs 0.75 · TreeRow 1.25 | 3 |
| Floating | ContextMenu 1.25 · Tooltip 0.75 · Dialog 0.5 · Toast + host 0.75 | 3.25 |
| Status | Banner 0.25 · Badge + DeviceChip 0.5 · Progress 0.5 · EmptyState 0.25 | 1.5 |
| Shell | EditorShell 1.5 | 1.5 |
| | **Total** (before the usual 1.3–1.5× overrun) | **~23** |

Counted bottom-up, the whole set is **~23 evenings, not 12–16**. The gap is mostly behaviour the
design specifies and a component sheet hides: scrubbing with modifiers and expressions,
drop zones and rename, submenus and keyboard handling, the tooltip hand-off, toast queueing,
resizable seams, and widget tests per state. v0.1 work item 14's 4 evenings
covered tokens and the theme (now done) and a restyle, not this. If ~23 is too much for v0.1,
these can move to v0.1.1 with nothing lost before then: the colour picker popover (hex + alpha
fields still edit, −0.75), NumberProperty expressions (−0.25), goldens (−0.75), SplitButton (a
Button next to an `FsMenuButton` caret works, −0.25). That brings it to ~21.

### 8.2 The early preview (*Q82*)

The early preview leaves out the visual design: its panels would be built with Material widgets
styled by `FsTheme.dark()`. Most of that is fine to throw away later (a button is a button). Four
widgets aren't: **TreeRow** (drop zones, focus-aware selection, rename), **NumberProperty** and
**Vector2Property** (label scrubbing), and **PropertyRow** (the Override marker and *Reset to
default*). The preview's own work items 3 and 5 already have to build that behaviour (reparent by
drag, numeric editing, Override markers). Built inside the panels, it would be written twice. Built
in the package, it is written once.

**Recommendation: move a narrow core into the early preview, not the proposed first set.**

| In the early preview (item 14 core) | Evenings |
|---|---|
| `FsInteractive`, `FsFieldBox`, `FsPanelFocus`, icons, gallery skeleton and test config (no goldens yet) | 2.5 |
| `FsTreeRow` (all states, DnD zones, rename) | 1.25 |
| `FsPropertyRow` (fixed 40% label column; resizing waits) | 0.5 |
| `FsNumberProperty` (scrub, modifiers, edit, commit; no expressions, no range slider) | 0.75 |
| `FsVector2Property` (no aspect lock) | 0.5 |
| **Total** | **~5.5** |

In return, items 3 and 5 no longer build their own drag zones, scrub fields and override rows
(~0.5 off item 3 and ~1 off item 5), so the preview grows by **~4 net (38 → ~42, ~14 weeks)**. Everything else in the
preview (buttons, text fields, dropdowns, context menus, dialogs, toasts, tooltips, the panel layout)
uses themed Material widgets as Q82 intended. Because the package's APIs take plain strings for
tooltips and labels, swapping in `FsButton`, `FsTooltip` and the rest later changes the panels'
call sites, not their logic.

Not recommended: moving the proposed first set (11 components) in whole. That's ~10–11
evenings (~+8 net) for looks the preview deliberately cuts, and it delays first feedback by ~3 weeks.

### 8.3 Build order

**Early preview** (inside the preview's build order, before the panels that use it):
`… → 6 → 4 → 14 core (foundations → PropertyRow → NumberProperty → Vector2Property → TreeRow)
→ 3 → 5 → 9 → …`

**v0.1, after the preview.** First the rest of the proposed first set, so the preview's panels
switch from Material to the design in one pass, then the components each deferred panel needs,
built just before that panel:

1. Button, IconButton, Tooltip (with `FsAnchoredOverlay`), TextField, Panel, SectionHeader,
   ContextMenu: the remainder of the proposed first set.
2. Dropdown, BoolProperty: the rest of the preview inspector's editors.
3. Dialog, Toast + host, Badge, Banner, Progress: the preview's dialogs, image-restart toast,
   Missing states and Play progress.
4. EditorShell, Toolbar, Tabs, StatusDot: the window chrome.
5. Then by deferred panel: SearchField (Hierarchy filter, item 3); SegmentedControl, ToggleButton,
   NumberField (gizmo modes, snapping, grid size, item 4); ColorProperty, AssetSlot, EntitySlot,
   PropertyRow label resizing, NumberProperty expressions and range slider (item 5); SplitButton,
   DeviceChip (device list, item 11); EmptyState (project list and empty panels, item 1).
6. Goldens for every gallery grid, then a final side-by-side pass against `preview.html`.

---

## 9. Files

All under `packages/flame_studio_ui/` unless noted.

| Path | Holds |
|---|---|
| `lib/flame_studio_ui.dart` | exports (grows by one line per component) |
| `lib/src/foundation/` | `interactive.dart`, `focus_ring.dart`, `debug_states.dart`, `field_box.dart`, `panel_focus.dart`, `anchored_overlay.dart`, `platform_hooks.dart`, `value_source.dart`, `number_editing.dart`, `shortcut_label.dart` |
| `lib/src/actions/`, `inputs/`, `inspector/`, `structure/`, `floating/`, `status/`, `shell/` | one file per component, grouped as in §3 |
| `lib/src/icons.dart` | 60 `FsIcons` + `FsPlayGlyph` |
| `test/` | `flutter_test_config.dart`, one `<component>_test.dart` each (the goldens live in the gallery, `example/test/goldens/`, since they render its pages) |
| `example/` | the gallery app (macOS) |
| root `pubspec.yaml` | `packages/flame_studio_ui/example` added to `workspace:` |
| `README.md` | "Not done yet" replaced by a component list with links to the gallery |

# flame_studio_ui

The Flame Studio design system in Flutter: design tokens, the theme and (as
they are built) the editor's widgets. Only the Studio app (`apps/flame_studio`)
uses it; it is never published.

```dart
MaterialApp(theme: FsTheme.dark(), home: ...);

final c = FsColors.of(context);
Container(color: c.surfacePanel, height: FsSizes.rowTree);
Text('Inspector', style: FsText.heading.copyWith(color: c.textPrimary));
Icon(FsIcons.hitbox, size: FsSizes.iconSm);
```

## What belongs here (Q83)

- **Yes:** tokens, the theme, and presentational widgets from the design
  system (buttons, fields, property rows, tree rows, menus, dialogs, panel
  chrome). Widgets take plain values and callbacks.
- **No:** anything that knows about scenes, Nodes, the Document, the Type
  catalog, processes or Riverpod. The Hierarchy, Inspector and other panels
  live in the app and compose these widgets.
- **Dependencies:** Flutter and the Lucide icon font (`lucide_icons_flutter`);
  the fonts are bundled. Never `flame`, `flame_studio_runtime` or the app.

## Source of the tokens

The design system was made in Claude Design from prompt 0 of
[`docs/claude-design-prompts.md`](../../docs/claude-design-prompts.md).
[`design/tokens.json`](design/tokens.json) is an unmodified copy of its
`tokens.json`; `test/tokens_test.dart` fails when the Dart tokens drift from
it. To pick up a design change, replace the file and fix the Dart side until
the test passes.

Naming: token `surface-panel` is `FsColors.surfacePanel`, `space-2` is
`FsSpacing.s2`, `radius-sm` is `FsRadii.sm`, `size-row-tree` is
`FsSizes.rowTree`, text style `body-strong` is `FsText.bodyStrong`.

## Fonts and icons

- **Fonts.** [`fonts/`](fonts) holds Inter 4.1 (400, 500, 600) and JetBrains
  Mono 2.304 (400, 500), the static `.ttf` files from the
  [rsms/inter](https://github.com/rsms/inter/releases/tag/v4.1) and
  [JetBrains/JetBrainsMono](https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304)
  releases; the design system's `.woff2` files don't load in Flutter. Both are
  SIL OFL 1.1 (`fonts/*-OFL.txt`). The `FsText` styles name the package, so
  the app gets them without declaring anything.
- **Icons.** Lucide, from
  [`lucide_icons_flutter`](https://pub.dev/packages/lucide_icons_flutter)
  (MIT, an icon font; it also ships thinner stroke weights as
  `LucideIcons100`…`600`). Widgets use `FsIcons`, which names the icons the
  design system uses; add an icon there before using it.

## Components

Built from [`docs/ui-components-plan.md`](../../docs/ui-components-plan.md)
(Q84). Each has a page in the [gallery](example) (`cd example && flutter run
-d macos`) laid out like its `preview.html`, and widget tests per state.

All 29 components of the design system, the EditorShell and the 60 icons are
built.

| Group | Widget | Notes |
|---|---|---|
| Foundations | `FsInteractive`, `FsStateColor` | interaction states; focus ring for keyboard focus only |
| | `FsFocusRing`, `FsDebugStates` | ring outside / inset; forced states for the gallery and tests |
| | `FsFieldBox`, `FsPanelFocus`, `FsValueSource`, `FsScrubHandle` | field chrome; panel-focus propagation |
| | `FsAnchoredOverlay`, `FsShortcutLabel` | floating-layer positioner (flip and shift); ⌘⇧ glyphs on macOS, "Ctrl+Shift" elsewhere |
| | `FsPlatformHooks` | native callbacks the app supplies: `sampleScreenColor` (eyedropper), `pointerLock` (scrub cursor) |
| Icons | `FsIcons` (60), `FsPlayGlyph` | `test/icons_test.dart` pins the names that differ from Lucide |
| Actions | `FsButton`, `FsIconButton`, `FsToggleButton` | primary, secondary, ghost, danger; disabled controls keep a tooltip |
| | `FsSplitButton`, `FsSegmentedControl`, `FsToolbar` | split main/caret targets; roving focus in the toolbar and segments |
| Inputs | `FsTextField`, `FsSearchField`, `FsNumberField`, `FsDropdown` | on `EditableText` inside `FsFieldBox`, not Material fields |
| | `FsCheckbox`, `FsSwitch` | the checkbox has a mixed state |
| Inspector | `FsPropertyList`, `FsPropertyRow` | shared, resizable label column; default from code / overridden + reset |
| | `FsNumberProperty` | label scrub with modifiers, expressions (`32*2`, `+=8`), range slider |
| | `FsBoolProperty`, `FsVector2Property` | per-axis scrub and mixed; aspect lock |
| | `FsColorProperty`, `FsColorPicker` | hex + alpha; the eyedropper shows only with `sampleScreenColor` |
| | `FsAssetSlot`, `FsEntitySlot` | on a shared `FsSlot`; drop targets, `FsDragInFlight` for the quiet accept state |
| Structure | `FsPanel`, `FsSectionHeader`, `FsCollapsible` | panel focus edge; collapsible sections |
| | `FsTabs` | document and dock styles; dirty dot, close |
| | `FsTreeRow` | all states, drop zones, inline rename, auto-expand |
| Floating | `FsContextMenu` (`showFsContextMenu`, `FsContextMenuRegion`, `FsMenuButton`) | on `RawMenuAnchor`; submenus, checked and destructive items |
| | `FsTooltip`, `FsTooltipGroup` | on `RawTooltip`; 0ms hand-off between adjacent controls |
| | `FsDialog` (`showFsDialog`), `FsToastHost`, `FsToast` | toasts: at most 3 visible, the rest queue |
| Status | `FsBanner`, `FsBadge`, `FsDeviceChip`, `FsEmptyState` | |
| | `FsProgressBar`, `FsSpinner`, `FsStatusDot`, `FsDelayedProgress` | slower, not stopped, under reduce-motion |
| Shell | `FsEditorShell` | slots and resizable seams; sizes reported to the app, which persists them |

## Not done yet

- **Goldens** (one per gallery grid, macOS CI only), then the final
  side-by-side pass against each `preview.html` (`ui-components-plan.md` §8.3).
- **Native hooks.** The eyedropper (`NSColorSampler`) and hiding and wrapping
  the cursor while scrubbing need code in the app's macOS runner; until then
  the widgets hide or simplify those features (Q84).
- **Light theme.** Tokens exist for dark only; a light theme adds a second
  `FsColors` and `FsShadows` constant.

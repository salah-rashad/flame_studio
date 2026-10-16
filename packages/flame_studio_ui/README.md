# flame_studio_ui

The Flame Studio design system in Flutter: design tokens, the theme and (as
they are built) the editor's widgets. Only the Studio app (`apps/flame_studio`)
uses it; it is never published.

```dart
MaterialApp(theme: FsTheme.dark(), home: ...);

final c = FsColors.of(context);
Container(color: c.surfacePanel, height: FsSizes.rowTree);
Text('Inspector', style: FsText.heading.copyWith(color: c.textPrimary));
```

## What belongs here (Q83)

- **Yes:** tokens, the theme, and presentational widgets from the design
  system (buttons, fields, property rows, tree rows, menus, dialogs, panel
  chrome). Widgets take plain values and callbacks.
- **No:** anything that knows about scenes, Nodes, the Document, the Type
  catalog, processes or Riverpod. The Hierarchy, Inspector and other panels
  live in the app and compose these widgets.
- **Dependencies:** Flutter only (plus an icon set and bundled fonts once the
  widgets need them). Never `flame`, `flame_studio_runtime` or the app.

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

## Not done yet

- **Fonts.** The design system ships Inter and JetBrains Mono as `.woff2`,
  which Flutter can't load. Bundle the `.ttf` releases (both SIL OFL) as
  package fonts; until then the styles fall back to the platform fonts.
- **Icons.** The design system's icons follow Lucide; pick and pin a Lucide
  port for Flutter.
- **Light theme.** Tokens exist for dark only; a light theme adds a second
  `FsColors` and `FsShadows` constant.
- **Widgets.** None yet (v0.1 work item 14).

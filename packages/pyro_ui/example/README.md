# pyro_ui gallery

Every `pyro_ui` component in every state, one page per component,
laid out like the design system's `preview.html` pages (same row and column
labels, same sample content) so the two can be compared side by side. The
static grids force their states with `PrDebugStates`; next to each grid is a
live copy to try with mouse and keyboard.

```bash
cd packages/pyro_ui/example && flutter run -d macos
```

**Acceptance check:** open the component's `preview.html` in a browser at the
same zoom and compare by eye. When a page matches, set `reviewed: true` for it
in `lib/main.dart`; the page list shows a tick.

**Goldens:** `test/goldens_test.dart` renders every page (at the gallery's
1440×900 content width, as tall as the page) and compares it with
`test/goldens/<page>.png`. They run on macOS only, since fonts rasterise
differently per platform. After a deliberate visual change:

```bash
flutter test --tags golden --update-goldens
```

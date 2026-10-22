# Contract: `example/`

What the sample game holds, and the values the checks rely on. The contract test, the latency
benchmark and the manual check all read this. A change here changes them.

## Package

| | |
|---|---|
| Path | `example/` (workspace member, added to the root `pubspec.yaml`) |
| Name | `pyro_example`, `publish_to: none` |
| Dependencies | `flame`, `flame_behaviors`, `flutter`, `pyro_annotations`, `pyro_runtime` |
| Dev dependencies | `build_runner ^2.15.1`, `flame_test`, `flutter_lints`, `flutter_test`, `pyro_generator` |
| Assets | `assets/images/`, `assets/scenes/` |
| Platforms | `macos/` only (spec FR-006) |
| Generated, committed | `lib/pyro.g.dart`, `lib/pyro.manifest.json` (*Q68*); no `build.yaml` (*Q107*) |

## Annotated types

| Type ID | Role | Class | Editable fields (type = default) |
|---|---|---|---|
| `Spin` | Behavior, parent `PyroEntity` | `lib/behaviors/spin.dart` | `turnsPerSecond` (`double` = 0.25), `clockwise` (`bool` = true) |
| `Banner` | Custom component (`TextComponent`), no Behaviors | `lib/components/banner.dart` | `message` (`String` = `'Pyro'`), `color` (`Color` = white) |

Nothing else in `lib/` is annotated (spec FR-002).

## Scene `assets/scenes/level1.scene.json`

Canonical form (spec 001), `schemaVersion` 1.

| Node ID | Kind | Name | Parent | Content |
|---|---|---|---|---|
| `root` | root | — | — | children: `ship`, `title` |
| `ship` | entity | `ship` | `root` | centre of an 800×600 world, size 64×64, anchor centre; Behavior `Spin` with Override `turnsPerSecond: 0.5` (`clockwise` left at default) |
| `hull` | sprite | `hull` | `ship` | `assets/images/ship.png`, size 64×64 |
| `body` | rectangleHitbox | `body` | `ship` | position [8, 8], size 48×48 |
| `title` | custom `Banner` | `title` | `root` | position [400, 48], anchor topCenter; Override `message: "Hello from Pyro"` (`color` left at default) |

## Game

- `lib/main.dart` runs `GameWidget(game: ExampleGame())`.
- `ExampleGame.onLoad` calls
  `PyroScene.load('assets/scenes/level1.scene.json', registry: pyroRegistry, onReloaded: …)`
  and adds the scene to `world`. The camera shows the 800×600 world.
- A HUD in the viewport, outside the Scene, shows `time: <s>s  swaps: <n>  code: <codeMarker>`.
- Log lines, printed with `print` so they reach the daemon in debug on macOS:
  - after the first load: `[pyro_example] Scene loaded: assets/scenes/level1.scene.json`;
  - in `onReloaded`: `[pyro_example] Scene reloaded: assets/scenes/level1.scene.json`.
  The latency benchmark matches the second one exactly (research R14).
- `lib/code_marker.dart`: `const codeMarker = 'v1';`, the string the Dart-only check edits.

## Image

`assets/images/ship.png`: 32×32 RGBA, drawn for this repository and MIT licensed. It is made by
`tool/draw_ship.dart`, which encodes the PNG itself with `dart:io`'s `zlib` (no image
package). Its source and licence are listed in `example/README.md` (spec FR-008).

## Golden

`test/goldens/pyro.manifest.json.golden` is a byte-for-byte copy of the reviewed Manifest. It is
updated only by the documented `cp` (research R13).

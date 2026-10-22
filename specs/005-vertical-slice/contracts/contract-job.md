# Contract: the CI contract checks

The checks spec 005 adds to `.github/workflows/ci.yml` (FR-009–FR-015, research R13), and the
commands that reproduce each one locally (FR-014). All run with the repository's pinned Flutter
(`FLUTTER_VERSION`, 3.44.2) after `dart pub get` at the root.

## In `analyze-test` (macOS, Windows, Linux)

| Step name | Working directory | Command |
|---|---|---|
| Check the example game's generated files | `example` | `dart run build_runner build -d` then `git diff --exit-code -- lib/pyro.g.dart lib/pyro.manifest.json` |
| Check formatting | root | existing step, its path list gains `example` |
| Analyze Flutter packages and the app | root | existing step, its path list gains `example` |
| Analyze the example game's Registry | `example` | `flutter analyze --fatal-infos lib/pyro.g.dart` |
| Test the example game | `example` | `flutter test` |

## The `contract` job (Linux, `ubuntu-24.04`)

Named **Contract test**; replaces the TODO job and its comment. Each check is its own step, so a
failure names it (FR-013):

| # | Step name | Working directory | Command | Fails when |
|---|---|---|---|---|
| 1 | Generate the example game's Registry and Manifest | `example` | `dart run build_runner build -d` | the Generator reports an error |
| 2 | Check the committed Registry and Manifest | `example` | `git diff --exit-code -- lib/pyro.g.dart lib/pyro.manifest.json` | the Generator's output changed and the commit didn't include it |
| 3 | Check the Manifest against its golden | `example` | `diff -u test/goldens/pyro.manifest.json.golden lib/pyro.manifest.json` | the Manifest changed and the golden wasn't deliberately updated |
| 4 | Load every example Scene with the real Registry | `example` | `flutter test test/contract/` | a Scene doesn't load, or loads with a Runtime warning (the error or warning names the Scene, Node, Type ID or field) |
| 5 | Analyze the example game | `example` | `flutter analyze --fatal-infos . lib/pyro.g.dart` | an analysis issue, including in the generated Registry (FR-013) |

The comment above step 2 keeps the Flutter ≥ 3.47 alternative,
`dart run build_runner build --only-check`, for when the pin moves (US2 #7). The comment above
step 3 gives the update command:

```text
cp lib/pyro.manifest.json test/goldens/pyro.manifest.json.golden
```

## `test/contract/scenes_test.dart`

- Lists `assets/scenes/` on disk at test time, recursively, `*.scene.json`, sorted.
- Fails if the list is empty.
- One `testWithFlameGame` per file: `PyroScene.load(<asset path>, registry: pyroRegistry)` with
  the default `UnknownType.fail`, `ensureAdd`, `ready`. A load error fails the test with the
  Runtime's message.
- While each load runs, `debugPrint` is recorded. Any Runtime warning (an unused Override, a
  repaired tree, a skipped type) fails the test, quoting the warning (spec FR-012, US2 #4).

## Budget

On a warm cache the `contract` job should finish in under 3 minutes (SC-003). Setup and
`dart pub get` are ~1 min, the generator ~20 s, and the tests ~30 s.

## Line endings

`.gitattributes` gains:

```text
example/lib/pyro.* -text
example/assets/** -text
example/test/goldens/** -text
```

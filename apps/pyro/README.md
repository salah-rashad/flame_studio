# Pyro (desktop app)

The Pyro editor: a Flutter desktop app (macOS first-class; Windows and
Linux built in CI). Released as binaries on GitHub Releases, not on pub.dev.

```bash
flutter run -d macos
```

Run `dart pub get` once at the repository root first: the app is a member of
the root pub workspace.

> **Status:** skeleton. See [`docs/project-plan.md`](../../docs/project-plan.md)
> §5 for the planned layout under `lib/`.

## Play from the command line

Until the editor has a Play button, `bin/play.dart` runs a game through
Pyro's Play client (`lib/process/`, spec 005). It starts the game with
`flutter run --machine` on macOS, and hot-reloads it when a Scene under
`assets/scenes/` is saved, so the Scene Hot-swaps in the running game:

```bash
dart run bin/play.dart ../../example
```

| Option | Meaning |
|---|---|
| `--flutter <path>` | the `flutter` executable (default: `flutter` on `PATH`) |
| `--record <file>` | also write `flutter run`'s raw output to `<file>`, auth codes masked |

While it runs, type `r` + Enter to hot-reload, or `q` + Enter (or Ctrl-C) to
stop. It exits with 1 if the game couldn't start, otherwise with the game's
exit code. The VM service address never appears in its output.

To measure the save-to-screen loop on the `example/` game (spec 005,
SC-004–SC-006), with the game not already running:

```bash
dart run benchmark/hot_swap_latency.dart ../../example
```

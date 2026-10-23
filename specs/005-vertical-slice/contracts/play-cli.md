# Contract: `bin/play.dart`

The slice's entry point for the Play client (spec Clarifications, FR-025). It is a thin caller: it
parses arguments, starts a session, prints its events, and maps keys and signals to client calls.

## Usage

From `apps/editor`:

```text
dart run bin/play.dart <project> [--flutter <path>] [--record <file>]
```

| Argument | Meaning |
|---|---|
| `<project>` | path to the game, e.g. `../../example` (required) |
| `--flutter <path>` | the `flutter` executable; default `flutter` on `PATH` |
| `--record <file>` | also write every raw stdout line of `flutter run` to `<file>`, with auth codes masked (transcripts, research R6) |

## Keys (type, then Enter)

| Key | Action |
|---|---|
| `r` | hot reload now (`PlaySession.reload`) |
| `q` | stop the game and exit |

Ctrl-C (`SIGINT`) and `SIGTERM` behave like `q`.

## Output

One line per event on stdout, prefixed with the time since start:

```text
+0.000s  starting: flutter run --machine -d macos --debug  (in /…/example)
+0.412s  tool: Launching lib/main.dart on macOS in debug mode...
+14.203s debugger available
+14.950s started (app 8f2c…) in 14.9s
+14.951s game: flutter: [pyro_example] Scene loaded: assets/scenes/level1.scene.json
+31.004s reloading: assets/scenes/level1.scene.json
+31.071s reloaded in 67ms
+31.090s game: flutter: [pyro_example] Scene reloaded: assets/scenes/level1.scene.json
+40.500s stopped (exit 0)
```

Failures read `reload failed: <message>` and `failed: <message>`, followed by the output tail
indented under it. stderr lines from the tool are prefixed `stderr:`. Nothing printed contains a VM
service auth code.

## Exit status

| Status | When |
|---|---|
| 0 | stopped by `q` or a signal, or the game exited with 0 |
| the game's exit code | the game exited by itself with a non-zero code |
| 1 | the game couldn't start (`PlayStartException`, `PlayFailed`) |
| 64 | bad arguments (usage printed to stderr) |

## Lifetime

It lives as long as the session. After Phase 4 it is either kept as a documented developer tool
(`apps/editor/README.md`) or removed when the Play button replaces it (spec FR-025). That is decided
then, not here.

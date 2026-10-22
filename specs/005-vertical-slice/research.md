# Research: Vertical Slice

Phase 0 of [plan.md](plan.md). Each entry is a decision the plan relies on, why it was made, and
what else was considered. Spike #1 (`spikes/01_play_hotswap/`, its driver in
`driver/bin/studio_driver.dart`) already spoke the daemon protocol on macOS and is cited as
"spike #1" (ARCHITECTURE.md, "Spike #1"). This planning session had no Flutter SDK. Protocol facts
come from that driver and its recorded findings, not from a run here. The first implementation
task on the Mac records real transcripts that replace the hand-written ones (R6).

## R1. Toolchain and dependencies

**Decision:** stay on Flutter 3.44.2 (Q94) and the lock's versions. `example/` depends on
`flame`, `flame_behaviors`, `pyro_runtime` and `pyro_annotations`, and has dev dependencies on
`pyro_generator`, `build_runner ^2.15.1`, `flame_test` and `flutter_lints`. These match
`fixture_game`. The app gains **no** dependency. File watching uses `dart:io` `FileSystemEntity.watch`
(FSEvents on macOS). Process spawning uses `dart:io` `Process`. Timers and the debounce use the app's
existing `clock` and, in tests, `fake_async`.

**Rationale:** everything the client needs is in `dart:io`. A new package such as `watcher` or
`process` would be a boundary change (constitution II) for no gain. The test seams below
(R3, R7) replace what those packages would offer.

**Alternatives considered:** `package:watcher`. It polls on some platforms, and its macOS
backend is FSEvents through `dart:io` anyway. `package:process`'s `ProcessManager` is a fine seam,
but a one-function typedef does the same job (R3).

## R2. Where the client lives, and the CLI

**Decision:** the client is the app's `process/` feature (constitution II's feature list):
`apps/pyro/lib/process/process.dart` is the public library and the code sits under
`lib/process/src/`. It imports only `dart:io`, `dart:async`, `dart:convert`, `clock` and `meta`.
It imports no Flutter and no Riverpod, so a plain Dart entry point can run it. The CLI is
`apps/pyro/bin/play.dart`, run as `dart run bin/play.dart <project>` from `apps/pyro`
(contracts/play-cli.md). In Phase 4 a Riverpod provider wraps the same `PlayClient` for the
Play button.

**Rationale:** the author chose a command-line entry point (spec Clarifications). Keeping the
feature free of Flutter imports lets the CLI run on the Dart VM and its tests run with `dart test`
semantics under `flutter test`, with no binding. `bin/` in a Flutter package works with
`dart run` as long as the script's imports never reach `dart:ui`.

**Alternatives considered:** a separate package `packages/pyro_process`. That is a new workspace
member for one feature with one future caller, and §5 puts process orchestration inside the app.
A `tool/` script: `bin/` is the Dart convention for an entry point people run, and `tool/` holds
maintenance scripts.

## R3. Spawning `flutter run` and the process seam

**Decision:** `PlayClient` takes a `ProcessStarter` (typedef matching `Process.start`'s
`(executable, arguments, {workingDirectory})`), with `Process.start` as the default. The
executable is `flutter`, found on `PATH`, or the CLI's `--flutter <path>` (basic SDK detection is
#1). The arguments are `run --machine -d macos --debug`. There is no `--project-root` (R9) and no
`--dds-port` or `--disable-service-auth-codes` (auth codes stay on, *Q81*). The working directory
is the project. Tests pass a fake `Process` whose stdout replays a transcript and whose stdin
records what the client sent.

**Rationale:** one injected function is the smallest seam that makes the client testable without
an SDK (constitution V: "Process clients are tested against recorded daemon transcripts, never a
real Flutter SDK"). `-d macos` is the device ID `flutter devices` reports for the macOS desktop
target. The device list is #11, rest.

**Alternatives considered:** looking up the device through `flutter devices --machine` first.
That is a second process and ~1 s more, for a target that is fixed in this slice.

## R4. The daemon messages the client uses

*From spike #1's driver and the flutter_tools daemon protocol (`doc/daemon.md` in flutter_tools),
as used with Flutter 3.44.2.*

**Decision:** stdout is read as UTF-8 lines. A line that starts with `[{` and ends with `}]` and
decodes as a JSON list is a batch of daemon messages. Any other line, or one that fails to decode,
is raw output: desktop targets write the game's stdout through unchanged, not as `app.log`. The
client handles:

| Message | Use |
|---|---|
| `daemon.connected` | ignored (version and pid, for a later check) |
| `app.start` `{appId, deviceId, directory, launchMode}` | keep `appId`; state → starting |
| `app.debugPort` `{wsUri, baseUri, port}` | noted only as "debugger available"; the URI is dropped (R5) |
| `app.started` `{appId}` | state → running; reloads allowed from here |
| `app.log` `{log, error?}` | output line from the game |
| `app.progress` `{message, finished, progressId}` | output line from the tool (build progress) |
| `daemon.logMessage` `{level, message}` | output line from the tool |
| `app.stop` `{appId, error?}` | state → stopped (with the error, if any) |
| a response `{id, result}` / `{id, error}` | completes the matching request |
| anything else | kept as a tool output line, never an error |

Requests: `app.restart {appId, fullRestart: false, pause: false, reason: "pyro"}` for a hot
reload, and `app.stop {appId}` to stop. A hot-reload result carries `{code, message}`. `code`
is 0 on success, and anything else is a failed reload, reported with its message. Requests are
written to stdin as `[{"id": n, "method": ..., "params": ...}]` followed by a newline.

**Rationale:** this is exactly the subset spike #1 used on macOS, plus `app.progress` and
`daemon.logMessage`, which it printed. Treating unknown events as output keeps the client working
when a Flutter release adds events (spec Edge Cases).

**Alternatives considered:** the VM service for reloads. §9.3 rules it out, because it skips the
asset sync that Hot-swap depends on.

## R5. Keeping the VM service URI out of logs

**Decision:** the client never stores or reports `wsUri`. `app.debugPort` becomes a
`PlayDebuggerAvailable` event with no address. Every output line it passes on, whether raw,
`app.log`, `app.progress` or `daemon.logMessage`, goes through `redactAuthCodes`. That is spike
#1's pattern: `(https?|wss?)://host/<code>=` becomes `…/<auth-code>=`. The redaction is a public
pure function with its own tests. Attach (#11, rest) will read the URI from the daemon message
directly.

**Rationale:** on desktop the engine prints its VM service URI to stdout as a raw line (§9.3).
Spec FR-021 says nothing the client reports may contain it. Dropping the URI rather than keeping
it privately means the slice holds no secret at all.

**Alternatives considered:** keeping the URI on the session for a later Attach. That is
speculative (constitution I), and it would be the first place the secret lives in memory without
a consumer.

## R6. Transcripts for the parsing tests

**Decision:** daemon transcripts are text files under `apps/pyro/test/fixtures/daemon/`. Each
line is what `flutter run --machine` wrote, in order: `start.txt` (build progress, a raw
VM-service line with an auth code, `app.start`, `app.debugPort`, `app.started`), `reload_ok.txt`,
`reload_failed.txt` (a compile error: a non-zero `code` and a message), `stop.txt`,
`crash.txt` (the process exits with no `app.stop`) and `no_macos_target.txt` (the tool's error,
then exit 1). The first versions are written by hand from spike #1's logs and the protocol doc.
Then a task on the Mac records real ones with `bin/play.dart --record <file>` and replaces them,
with auth codes masked before they are committed. The fake process replays a file and lets the
test choose when the replay advances (after a request, at exit).

**Rationale:** SC-009 asks for the parsing tests to pass with no real `flutter` process. Hand-written files unblock
the tests in a session without Flutter, and real recordings pin the actual format of 3.44.2.

**Alternatives considered:** only hand-written transcripts. They would drift from the real format
unnoticed. A recording proxy outside the CLI: `--record` is a few lines in the CLI and tees the
same stdout the client reads.

## R7. Watching Scene files

**Decision:** while a session runs, the client watches `<project>/assets/scenes/` recursively
(spec Assumptions: the folder the README recipe prescribes) and keeps events for paths ending in
`.scene.json`. It handles create, modify and move: for a move, it uses the destination, which is
how an atomic temp-then-rename save arrives. Deletes are passed on (spec Edge Cases: the reload
then reports the Runtime's missing-file error). The watcher is injected as a
`Stream<FileSystemEvent> Function(Directory)`. The default is `dir.watch(recursive: true)`, and
tests push events by hand. If the folder doesn't exist, the session runs without watching and says
so once as a tool output line.

The client does not compare file contents. A save with the same bytes still sends a reload, and
the Runtime's text comparison leaves the Scene alone (spec US3 #3; *Q67*).

**Rationale:** FSEvents reports an atomic save as a create or move of the target, sometimes with a
modify too. The debounce (R8) folds them. Filtering by suffix ignores the editor's temp files
(`.scene.json.tmp`, `.swp`, `~`).

**Alternatives considered:** hashing files in the client to skip no-op reloads. The Runtime
already does this, per Scene and exactly. Doing it twice adds state for a reload that costs
~60 ms.

## R8. Coalescing and one reload at a time

**Decision:** a change starts (or restarts) a **150 ms** quiet timer. When it fires, one reload
is requested for all files changed since the last one. If a reload is already in flight, at most
**one** more is queued, and it covers every change that arrives meanwhile. Changes before
`app.started` are dropped, because the game reads the file from disk when it starts (spec Edge
Cases). Manual reloads (the CLI's `r`) go through the same queue with no debounce. The timer
uses `clock` and `Timer`, so `fake_async` drives it in tests.

**Rationale:** SC-004's budget is a 500 ms median from save to screen. Spike #1 measured the
macOS reload at ~58 ms and FSEvents delivers in tens of milliseconds, so 150 ms of quiet leaves
room and still folds an editor's write-then-rename and a burst of saves (SC-006: ten saves in one
second → at most two reloads: one after the burst settles, and possibly one already in flight).

**Alternatives considered:** no debounce, one reload per event. That breaks SC-006 and races the
asset sync. A longer quiet period such as 300 ms eats most of the median budget.

## R9. No run link, no asset re-point

**Decision:** the slice runs `flutter run` in the project itself, with no `--project-root` link,
and never calls `_flutter.setAssetBundlePath` or `ext.flutter.evict`.

**Rationale:** both workarounds exist only to keep Hot-swap working while an IDE is attached
(§9.3, *Q74*). In spike #1 with only the driver attached, macOS check (a) passed without them.
The spec keeps IDE-attached Hot-swap out of scope. If the manual check shows they are needed even
without an IDE, that is a finding (spec FR-026), not a silent addition.

**Alternatives considered:** building them now. They are in #11, rest's estimate, they need the
VM service connection this slice avoids (R5), and they would hide whether plain macOS Hot-swap
works.

## R10. Stopping and cleaning up

**Decision:** `stop()` sends `app.stop` and waits up to **5 s** for the process to exit. After
that it sends `SIGTERM`, waits 2 s, then `SIGKILL`. `stop()` completes once the process has exited,
and is idempotent. If the process exits on its own, with or without `app.stop` first, the session
reports `PlayStopped(exitCode, reason)` and closes its watcher and streams. The CLI traps `SIGINT`
and `SIGTERM`, calls `stop()`, and exits with the game's status. Closing the macOS window ends the
app, and `flutter run` then exits. Spike #1 saw `app.stop` and an exit in that case.

**Rationale:** SC-007 needs nothing left running. `app.stop` lets flutter_tools stop the app
properly. Killing `flutter run` alone can leave the macOS app running, which the manual check
watches for (quickstart §5).

**Alternatives considered:** killing the process group. That isn't portable through `dart:io`,
and it is unnecessary when `app.stop` works. It is the fallback to record if the manual check finds
an orphaned app.

## R11. Start failures

**Decision:** there is no start timeout: a first macOS build can take minutes. Failures are
detected from what the tool does:
- `flutter` can't be started (`ProcessException`): `PlayFailed` naming the executable and the
  OS error.
- The process exits before `app.started`: `PlayFailed` with the exit code and the last 20
  output lines, already redacted. That covers no macOS target, a compile error and a missing
  `pubspec.yaml`.
- `app.stop` with `error` before `app.started`: the same.

`start` also checks, before spawning, that the project path holds a `pubspec.yaml` and a `macos/`
folder, and fails with the path if not. This is a cheap, clear message for the commonest mistake.

**Rationale:** spec US4 #3 asks for an error rather than waiting forever. A Flutter failure always
ends the process, so watching for the exit is enough. The tail of the output is where the tool
puts its reason.

**Alternatives considered:** a fixed timeout. It would fail slow first builds, and it can't tell
"slow" from "stuck".

## R12. The example game

**Decision:** `example/` (package `pyro_example`) is a workspace member with a macOS runner from
`flutter create --platforms=macos` and nothing else. It contains:

- **Behavior `Spin`** (`lib/behaviors/spin.dart`, on `PyroEntity`). Editable fields are
  `turnsPerSecond` (`double`, default 0.25) and `clockwise` (`bool`, default true). It turns its
  entity every frame, so a changed Override is visible at once.
- **Custom component `Banner`** (`lib/components/banner.dart`, a `TextComponent`). Editable fields
  are `message` (`String`, default `'Pyro'`) and `color` (`Color`, default white). It applies them
  to `text` and its text paint in `onLoad`. The field isn't called `text`, which
  `TextComponent` already owns.
- **Scene** `assets/scenes/level1.scene.json`. It holds an entity `ship` at the centre with `Spin`
  (Override: `turnsPerSecond: 0.5`, `clockwise` left at its default), a sprite `hull` and a
  rectangle hitbox `body` under it, and a `Banner` `title` near the top (Override: `message`).
  It is written in canonical form (spec 001).
- **Image** `assets/images/ship.png`: 32×32, drawn for this repository (MIT), made by a script
  under `example/tool/` that stays in the repository so the image can be regenerated. Its source
  and licence are listed in `example/README.md`.
- **Game** (`lib/main.dart`, `lib/example_game.dart`). `onLoad` loads the Scene with
  `pyroRegistry` and adds it to the world. A HUD outside the Scene shows a seconds counter (game
  state that must survive a swap), a Hot-swap count incremented in `onReloaded`, and
  `codeMarker`, a string constant in `lib/code_marker.dart` that the Dart-only reload check edits.
  `onReloaded` also prints `[pyro_example] Scene reloaded: <path>`, which the latency benchmark
  waits for (R14).

**Rationale:** the spec asks for one of each and two Field types on the Behavior. `double` and
`bool` are the first types the inspector edits. A `Color` on the Custom component exercises the
string-to-colour path end to end. A spinning ship makes any `Spin` Override visible within a
frame, and the banner makes a text Override readable. The HUD gives the visible checks for
US3 #1–#4 without a debugger. A new image rather than `fixture_game`'s keeps the fixture free to
change.

**Alternatives considered:** reusing `fixture_game`. It is a generator fixture with every Field
type and deliberate edge cases (a legacy duplicate name), not a sample of what a developer's
project looks like (spec FR-007), and it has no platform runner.

## R13. The contract job

**Decision:**
1. **Committed files** (FR-010), as a step in the existing `analyze-test` matrix on all three
   OSes (FR-009a) and again in the `contract` job:
   `dart run build_runner build -d`, then `git diff --exit-code -- lib/pyro.g.dart
   lib/pyro.manifest.json`, in `example/`. This is the same shape as `fixture_game`'s step.
2. **Manifest golden** (FR-011), Linux, `contract` job:
   `diff -u test/goldens/pyro.manifest.json.golden lib/pyro.manifest.json` in `example/`.
   To update it, deliberately: `cp lib/pyro.manifest.json test/goldens/pyro.manifest.json.golden`,
   documented in `example/README.md` and in a comment on the step.
3. **Analyse** `example/` with the workspace rules, plus `lib/pyro.g.dart` by name (the root
   options exclude `*.g.dart`), as `fixture_game` does.
4. **Scenes** (FR-012), Linux: `flutter test test/contract/` in `example/`.
   `scenes_test.dart` lists `assets/scenes/` on disk at test time (recursively, `*.scene.json`)
   and creates one `testWithFlameGame` per file that loads it with `PyroScene.load(path,
   registry: pyroRegistry)` through the bundle. It also checks that the list is not empty.
   A Scene missing from the bundle (an undeclared folder) fails as a missing file, which is also
   a contract break.

The job is renamed from "Contract test (TODO)" to "Contract test". Each check is its own step
with its own name, so the run summary shows which one failed (FR-013). `example/` joins the
format step, the Flutter analyze step and a `flutter test` step in `analyze-test`, like every
member. `.gitattributes` gains `example/lib/pyro.* -text`, `example/assets/** -text` and
`example/test/goldens/** -text`.

**Rationale:** this mirrors the TODO comment already in `ci.yml` (Q59) and the `fixture_game`
pattern that is green on three OSes. Running the committed-files check in the matrix closes
spec 003's open T043 cross-system check at the cost of one step per OS (spec Clarifications).
A shell `diff` shows the golden difference in the log with no test harness. Listing Scenes at
test time meets "no hard-coded list" (FR-012).

**Alternatives considered:** a golden test in Dart with an update flag. That is more code for the
same result, and `diff -u` output is what a reviewer wants to see. `build_runner build
--only-check`: it needs Flutter ≥ 3.47 (§7.3, *Q76*), and the job comment keeps the switch
documented (US2 #7).

## R14. Measuring save-to-screen

**Decision:** `apps/pyro/benchmark/hot_swap_latency.dart` is a Dart script that uses
`PlayClient` against a project path (default `../../example`). It starts the game and waits for
`started` and for the game's first frame line. Then it runs three timed sections, printing a
table and exiting non-zero on a failed criterion:
- **SC-004:** ten times, write a changed copy of `level1.scene.json` atomically (temp + rename,
  moving the ship), then time from just before the rename to the arrival of the game's
  `[pyro_example] Scene reloaded` line. It reports the median and worst. The pass limits are
  median < 500 ms and worst < 1 s.
- **SC-005:** ten times, alternately touch the Scene with the same bytes and edit
  `lib/code_marker.dart` then send a manual reload. It waits 2 s each time and counts
  `Scene reloaded` lines. Pass: zero.
- **SC-006:** ten changed writes within one second, then wait for things to settle. It counts the
  reloads the client sent and checks that the game's last `Scene reloaded` follows the last
  write. Pass: at most two reloads.

It restores both files on exit, as spike #1's driver did. The time is measured to the log line,
not to the frame: the line is printed in `onReloaded`, after the swap, and the change is drawn on
the next frame (≤ 16 ms later at 60 Hz). That is noted with the results.

**Rationale:** ten-run statistics by hand are error-prone. The spike's `--ci` mode shows a script
can do the checks reliably. It belongs under `benchmark/`, where the app already keeps its
measurement scripts (spec 002), because it is rerun on each Flutter release (§13 "End-to-end").

**Alternatives considered:** a stopwatch by eye, which is too coarse for a 500 ms median.
Measuring in the game alone: the game can't know when the file was saved.

## R15. The release check on `example/`

**Decision:** spec FR-027 reuses spec 004 T043's check: `flutter build macos --release` in
`example/`, then
`strings "build/macos/Build/Products/Release/pyro_example.app/Contents/Frameworks/App.framework/App" | grep -c "couldn't Hot-swap"`
→ 0. Run on the Mac with the manual check (quickstart §5). If it passes, spec 004's T043 release
part is closed too.

**Rationale:** `example/` is the first real game. Its release build is the honest place to check
that the debug-only Hot-swap path tree-shakes away (constitution III).

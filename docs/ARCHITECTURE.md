# Flame Studio — Architecture

How Flame Studio is built and why. This document starts from the v0.0 de-risking spikes
([`project-plan.md`](project-plan.md) §14) and grows with the code. The plan describes the
intended design; this file records what was verified, what had to change, and what depends on
behavior we don't control.

Status: **v0.0 in progress.** Spikes #1 and #2 done; spike #3 (disk rendering) to come.

---

## Spike #1 — Play, Hot-swap and Attach

**Question:** can the Studio own the running game (`flutter run --machine`), Hot-swap saved
scenes into it, and still let the developer attach an IDE for breakpoints and code hot reload?
This was the deciding test for [ADR 0001](adr/0001-studio-runs-the-game-ide-attaches.md).

**Answer:** yes, with two workarounds for how flutter_tools handles a second client
([*Q74*](decisions.md)), plus `--disable-service-auth-codes` for a stable attach URL (*Q75*).

Code and step-by-step instructions: [`spikes/01_play_hotswap/`](../spikes/01_play_hotswap/README.md).
A Flame game with a minimal content-hashed `StudioScene`, and a Dart driver that plays the
Studio's part: it spawns `flutter run --machine`, edits files and reloads through the daemon.

Tested with Flutter 3.44.2, Flame 1.38.2, macOS 26.2, 2026-10-16.

### Results

| Check | macOS desktop | iOS simulator | Android emulator | Android phone (CPH2737, USB) |
|---|---|---|---|---|
| (a) Scene save → `app.restart` → `onHotReload` rebuilds | ✅ ~58 ms | ✅ ~70 ms | ✅ ~250 ms | ✅ ~156 ms |
| (b) Dart-only reload doesn't rebuild the scene | ✅ | ✅ | ✅ | ✅ |
| (c) IDE attaches via the fixed DDS port | ✅ `flutter attach` | ✅ VS Code | — | ✅ VS Code |
| (c) IDE breakpoints hit | — | ✅ | — | — |
| (c) IDE hot reload while the Studio is connected | ✅ | ✅ | — | ✅ |
| (c) Studio saves still apply after the IDE attaches and reloads | ✅ with both workarounds | ✅ with re-point | — | ✅ with both workarounds |
| (c) Studio hot restart while the IDE is attached | ✅ with `--project-root` | — | — | ✅ with `--project-root` (❌ without) |

Times are the daemon's hot reload duration for a scene save. iOS physical devices weren't
available; they use the same DevFS path as Android phones (see finding 3), so they're expected to
behave the same. Re-test before the developer preview.

### Findings

**1. The planned Hot-swap mechanism works as designed (*Q66, Q67*).** A hot reload through
`flutter run`'s daemon syncs changed asset files to the device and evicts them from `rootBundle`
before `reassemble`. Flame then calls `onHotReload()` on mounted components, so
`StudioScene` can re-read its file with a plain `rootBundle.loadString` and compare hashes. No
custom service extension is needed. A Dart-only reload re-reads the same bytes and leaves the
scene alone.

**2. Each flutter_tools client has its own DevFS; that breaks Hot-swap with an IDE attached.**
`flutter run` and `flutter attach` (which IDEs use) each sync files into a DevFS: a folder on the
device, named after the project folder (`basename(projectRootPath)`), plus an asset folder at
`<DevFS>/build/flutter_assets`. Two consequences:

- **Name clash.** When the IDE attaches, it finds the name taken, deletes the Studio's DevFS and
  creates its own (`DevFS: Creating failed. Destroying and trying again`). The engine is still
  pointed at the deleted folder, so the next read falls back to the original scene in the app
  bundle.
- **Asset shadowing.** Each client calls `_flutter.setAssetBundlePath` only once, on its first
  reload that syncs an asset. After the IDE's first such reload, the engine serves scenes from the
  IDE's copy, which only changes when the IDE reloads. Studio saves are then ignored, and the
  scene jumps to the latest version on the IDE's next reload.

**3. On physical devices the name clash is permanent.** Desktop and simulators use a local DevFS
writer that writes straight to the folder path, so the Studio's next sync recreates it. Physical
Android and iOS devices write through the VM service *by DevFS name*, which now belongs to the
IDE, so the Studio's folder never comes back. Its hot restart and reloads still use its old
DevFS URI, and restart fails:

```
E/flutter: [ERROR:flutter/runtime/dart_isolate.cc(146)] Could not prepare isolate.
hot restart failed to complete: _flutter.runInView: (-32000) Could not run configuration in engine.
```

**4. Workarounds adopted (*Q74*).**

- **Distinct DevFS name.** `flutter run` has a hidden `--project-root` option. The Studio passes a
  symlink to the project with a different folder name, so its DevFS no longer clashes with the
  IDE's:

  ```
  <app support>/run/<project-id>/<name>-studio  →  <user's project>
  flutter run --machine -d <device> --dds-port <port> --disable-service-auth-codes \
              --project-root <that link>          (working directory: the real project)
  ```

- **Re-point before every reload.** Before each `app.restart`, the Studio calls
  `_flutter.setAssetBundlePath` on the VM service (`viewId` from `_flutter.listViews`,
  `assetDirectory` = `<DevFS base URI from app.debugPort>/build/flutter_assets`), taking the engine
  back from the IDE's copy. The engine rejects it when the folder doesn't exist yet (before the
  Studio's first asset sync). The Studio then reloads anyway (which creates the folder),
  re-points, evicts the saved scene files with `ext.flutter.evict`, and reloads once more.

With both in place, every save rebuilt the scene and every no-op reload left it alone, with the
IDE reloading and hot-restarting in between (macOS with `flutter attach`; Android phone with
VS Code). The fallback reload ran only on the first save after launch.

How the engine handles the re-point
(`engine/src/flutter/shell/common/shell.cc`, `OnServiceProtocolSetAssetBundlePath`): it opens
the folder as a new `DirectoryAssetBundle` and puts it first, then keeps only old resolvers that
are valid after an asset-manager change, which DevFS folders aren't. So the last caller wins
outright; there's no fallback to the other client's copy. A folder that can't be opened fails
with `Could not update asset directory.` and changes nothing.

**5. Without `--disable-service-auth-codes`, the attach URL changes every run** (for example
`ws://127.0.0.1:8282/EMWbRKFTAe4=/ws`, then `/rY9Oy8-nQ1I=/ws`), which breaks a saved
`launch.json`. With it and a fixed `--dds-port`, `app.debugPort` reports `ws://127.0.0.1:<port>/ws`
every time (*Q75*).

**6. VS Code shows a stale "paused" after any hot restart while both are connected.** The
nonsense top frames (`List.add`, `int.&`) come from sampling a running isolate. A debug adapter
sets `pause_isolates_on_start` and asks DDS for `requirePermissionToResume(onPauseStart)`, so a
hot restart's new isolate (`IsolateExit` → `IsolateStart` → `PauseStart`) waits for the IDE.
VS Code resumes it and the game runs, but its UI keeps the paused state. A client that never
resumes would leave the game stuck at startup. Without such a client, the Studio's restart emits
no pause events at all. Cosmetic for VS Code; the Attach guide should say to press Continue.
Worth checking against the Dart-Code issue tracker.

**7. Smaller findings for the Studio.**

- **Console:** on desktop targets, the game's `print` output arrives as raw stdout lines rather
  than `app.log` events. The Console must take both.
- **Devices:** `flutter run --machine` emits `device.added` / `device.removed` mid-run for paired
  but unreachable devices (`"isConnected": false`). The device list should ignore them.
- **Two compilers:** each client has its own frontend server, so after an IDE code edit both
  recompile the changed library. That's harmless, but the Studio's next reload reports
  "Reloaded N libraries" even for a scene save.
- **Testing pitfall:** a save that writes the bytes already on disk doesn't change the hash, so
  nothing rebuilds. That's correct, but it looks exactly like a broken Hot-swap; the spike driver
  makes every test edit unique.

### What this depends on

| Dependency | Kind | If it changes |
|---|---|---|
| `flutter run --project-root` names the DevFS after its basename | Hidden flutter_tools option | Re-point still fixes shadowing on desktop/simulators; on physical devices fall back to "Studio stops reloading while an IDE is attached" |
| `_flutter.setAssetBundlePath` | Private engine service extension (used by flutter_tools itself) | Fall back as above |
| `ext.flutter.evict` | Framework debug service extension | Same fallback |
| Daemon `app.restart` syncs + evicts changed assets before `reassemble` | flutter_tools behavior | Core Hot-swap breaks; would need the Live bridge (v0.4) |
| Flame calls `onHotReload` from `GameWidget.reassemble` | Flame ≥ 1.36 API | Runtime floor in §12 |

The Studio re-checks these on every Flutter stable release with the manual end-to-end test
(`project-plan.md` §13). Running the spike driver against the new SDK is the quickest check:
`--ci` for (a)+(b), and the VS Code steps in the spike README for (c).

### Open items

- Physical iOS device, and Android Studio as the attaching IDE: not yet tested.
- On Windows (v0.3), the run link needs a directory junction or Developer Mode symlinks. ◇
  proposed
- First save after launch costs an extra reload. The Studio could avoid it by re-pointing only
  after it has synced an asset once. ◇ proposed

---

## Spike #2 — Generator shape and latency

**Question:** can one source_gen `$lib$` aggregator write both the runtime Registry and the
Manifest into `lib/` (*Q38, Q68*), fast enough in `build_runner watch` for the Studio's edit
loop, and can the Studio tell whether a `build_runner` is already running (*Q48*)?

**Answer:** yes. Every save landed in **~0.9–1.0 s** on 300- and 1000-file Flame projects.
The one exception is the first save after a watcher starts (~2.8 s). The lock probe is reliable
and harmless. Two plan details need changing: **`--only-check` isn't available to Flutter 3.44
projects** (Flutter's `meta` pin caps build_runner at 2.15.1), and the Studio's watcher policy
must handle `build_runner build` and `stop`, not just a second `watch`.

Code and step-by-step instructions: [`spikes/02_generator/`](../spikes/02_generator/README.md).
Stand-in annotation and generator packages, a small Flame game with its committed outputs, a
synthetic-project generator, a watch latency harness and a lock probe with a Studio-policy
simulator.

Tested with Flutter 3.44.2 / Dart 3.12.2, build_runner 2.15.1 (Flutter projects) and 2.17.1
(pure-Dart projects), Flame 1.38.2, flame_behaviors 1.4.0, macOS 26.2 on an Apple M4,
2026-10-16.

### Results

| Check | Result |
|---|---|
| One `$lib$` builder writes `lib/flame_studio.g.dart` **and** `lib/flame_studio.manifest.json` | ✅ |
| Registry compiles; factories and setters work; Registry and Manifest list the same Type IDs | ✅ |
| Watch updates both files ≤ ~3 s, 300 files / 42 annotated | ✅ median 0.9 s; first save after start 2.8 s |
| Same, 1000 files / 142 annotated | ✅ median 0.9–1.0 s; first save 2.8–2.9 s |
| Unannotated edits skipped via `triggers` | ✅ but only 0.05–0.2 s saved (finding 3) |
| Lock probe detects a running `build_runner` without disturbing it | ✅ ~1–4 ms |
| Studio follows another process taking over | ✅ with the policy change in finding 5 |
| `build --only-check` in CI | ✅ on 2.17.1 · ❌ on Flutter 3.44.2 (finding 1) |
| Outputs byte-identical across clean rebuilds | ✅ |
| build_runner ≥ 2.14 lock (Q48) | ✅ identical on 2.15.1 and 2.17.1 |

Watch latency, Flutter + Flame, 300 files, triggers on (median of 5, from the moment the save's
write returns until build_runner reports the build done):

| Save | Manifest | Registry | Done |
|---|---|---|---|
| First save after watch start | 2.8 s | unchanged | 2.8 s |
| Annotated: tooltip edit | 0.95 s | unchanged | 0.95 s |
| Annotated: add an `@Editable` field | 0.92 s | 0.92 s | 0.92 s |
| Annotated: method body | unchanged | unchanged | 0.89 s |
| Unannotated leaf file | unchanged | unchanged | 0.43 s |
| Unannotated file every annotated file imports | unchanged | unchanged | 0.90 s |
| New annotated file | 0.90 s | 0.90 s | 0.90 s |

Other configurations (1000 files, triggers off, pure Dart) are in the spike README.

### Findings

**1. Flutter 3.44 caps build_runner at 2.15.1, so no `--only-check` there.** Flutter 3.44.2
pins `meta: 1.18.0`; `analyzer` ≥ 13.1.0 needs `meta ^1.18.3`; build_runner ≥ 2.15.2 needs
`analyzer` ≥ 13.3.0. In a Flutter project, `build_runner: ^2.16.0` doesn't resolve, and an open
constraint picks 2.15.1 (with analyzer 13.0, build 4.0, source_gen 4.2). Flutter 3.47.0 relaxed
the pin to `meta: ^1.18.3` (read from the 3.47.x tags, not tested). Two consequences:

- The generator must accept a **wide dependency range** (`analyzer >=12 <15`, `build >=4 <6`,
  `source_gen >=4 <5`, `dart_style >=3 <4`) or it won't resolve in the user's project at all.
  The spike's generator builds unchanged at both ends.
- The plan's CI recommendation (*Q68*, §7.3: `--only-check`, build_runner ≥ 2.16) needs
  **Flutter ≥ 3.47**. Below that, CI can run `dart run build_runner build` and then
  `git diff --exit-code lib/flame_studio.g.dart lib/flame_studio.manifest.json`. Decided as
  *Q76*; the `git diff` variant wasn't run in the spike

**2. Latency is a fixed cost, not a project-size cost.** Each save pays ~0.4–0.5 s before any
builder runs: build_runner's 250 ms debounce (`commands/watch/watcher.dart`) plus FSEvents. A
pure-Dart project shows only that (0.5 s total, builds of 0.01–0.06 s). With Flutter + Flame,
each changed library the scanner must re-resolve adds ~0.4 s of analyzer resolution, whether
the project has 300 or 1000 files. The first build after a watcher starts takes ~2.4 s of
analyzer warm-up for the Flutter SDK. That is the only save near the 3 s budget, and it comes
right after the Studio starts its watcher (or after a takeover). Cold costs: the first build in a
fresh checkout takes ~14–16 s, ~10 s of which is AOT-compiling the builders; that repeats
whenever the generator's dependencies change.

**3. `triggers` work but aren't what keeps it fast.** `run_only_if_triggered` with
`annotation StudioBehavior` / `annotation StudioComponent` skips unannotated libraries ("259 not
triggered"), saving up to ~0.1 s per save and ~0.1–0.2 s per full build. Resolution of annotated
libraries dominates, and an edit to a file all of them import re-runs the scanner on all of
them either way. Keep triggers (free, and they scale with unannotated code). Annotation triggers
match by name, so re-exported or renamed annotations need their own trigger.

**4. The `$lib$` shape works as planned (*Q68*).** A per-library scanner writes a JSON fragment
to the build cache only for libraries with annotated classes. A `$lib$` aggregator
(`required_inputs: [".studio.json"]`, `findAssets(Glob('lib/**.studio.json'))`,
`build_to: source`) writes both files. Properties the Studio relies on:

- **Outputs are written only when their content changes** (build_runner ≥ 2.14 doesn't
  rewrite identical outputs). Body edits and unannotated edits touch neither file; a tooltip
  edit changes only the Manifest. The Studio can re-parse on every Manifest file event.
- **Errors reach the Manifest even when the build fails.** The aggregator writes both outputs,
  then `log.severe`s: the build fails (exit 1), the Manifest's `errors` is filled in, the watch
  keeps running and recovers on the next good save, and a no-change rebuild reports the error
  again. Types with errors are left out of both files. With duplicate Type IDs, *every* class
  sharing the ID is dropped (an earlier version kept the first by path and the Registry built
  the wrong class).
- **Deterministic:** clean rebuilds are byte-identical; `--only-check` (2.17.1) passes on a
  fresh clone with no build cache and fails, listing the file, on a stale, hand-edited or
  missing output. It prints no diff.
- §7.3 calls this "the pattern source_gen's own combining builder uses". Not quite:
  `CombiningBuilder` combines fragments **per library** into `<file>.g.dart`; the `$lib$` scope
  is ours.

**5. The lock probe works; the watcher policy needs one more rule.** build_runner ≥ 2.14 holds
an exclusive lock on `.dart_tool/build/lock/build_runner.lock` in the `dart run build_runner`
process (not its AOT builder child) for the whole run of **any** command, including a one-off
`build`. The probe opens it with `FileMode.append` (no truncate or create), tries
`lockSync(FileLock.exclusive)` and unlocks at once. It takes ~1–4 ms, and 50 probes against a
running watch neither stopped it nor wrote `.requested`. `kill -9` of the holder frees the lock.
When another command starts, the running watch finishes its build, prints
`Exiting as requested by another build_runner process.` and exits **0**. That is the same for a
second `watch`, a one-off `build` and `build_runner stop`:

| User runs… | After the Studio's watcher exits | Studio should |
|---|---|---|
| `build_runner watch` | lock held for as long as it runs | show "External build_runner"; when the lock is released, start its own watcher again |
| `build_runner build` | lock held for a few seconds, then free; nobody watching | same: external, then restart |
| `build_runner stop` | lock already free at the re-probe | **not** restart: show "Generator stopped" with a Start button |

§9.2 currently covers only the first row. The rule, verified with the spike's `--studio`
simulator: **after a takeover exit, re-probe; held → external, then restart on release; free →
stopped.** Decided as *Q77* (§9.2). Also, `--only-check` and any other build_runner command run locally take
the lock and stop the Studio's watcher.

**6. Smaller findings for the generator.**

- **Imports:** importing each field type's declaring library gives
  `package:flame/src/sprite_animation.dart` and `package:vector_math/vector_math.dart`, a
  package the game doesn't depend on directly. It compiles, but the real generator should import
  types through the public libraries the user's file imports.
- **Defaults:** literals and enum constants are evaluated; `const Color(0xFFFFFFFF)` and
  `Vector2(1, 0)` keep their source text in `defaultSource`. The analyzer could evaluate const
  initializers if the inspector needs real values.
- **`supertypes`** from `allSupertypes` includes every Flame interface (14 entries for a
  `PositionedEntity`). The Studio likely needs the class chain plus `EntityMixin`; trim it in
  the generator.
- **Registry setters** only cast (`(v as num).toDouble()`, `values.byName`, `v as Vector2`);
  JSON → `Vector2` / `Color` / asset / entity-reference conversion stays in the Runtime.

### What this depends on

| Dependency | Kind | If it changes |
|---|---|---|
| Lock file path and `FileLock.exclusive` held for the whole command | build_runner implementation detail (`bootstrap/build_process_lock.dart`), not documented API | Probe reports `none`/`free` wrongly; the Studio would start a watcher that waits on the lock (`Waiting for already-running build_runner.`), so detect that line too |
| Exit message `Exiting as requested by another build_runner process.` | Log text | Fall back to "exit code 0 while the Studio didn't stop it" |
| Unchanged outputs aren't rewritten | build_runner ≥ 2.14 behavior | Studio would need to compare Manifest content before re-parsing |
| `run_only_if_triggered` / `triggers` | build_config ≥ 1.2 feature | Latency barely changes (finding 3) |
| Outputs written before `log.severe` stay on disk | build_runner behavior | Errors only reach the Studio via the Console |
| Flutter's `meta` pin | Flutter SDK | Decides whether `--only-check` is available (finding 1) |

### Open items

- Flutter ≥ 3.47 with build_runner 2.17: re-run the latency matrix and `--only-check` in a real
  Flutter project.
- Pub workspaces: the probe also takes a shared lock on `build_runner.workspace.lock` at the
  workspace root; not exercised.
- Windows (v0.3): `lockSync` uses `LockFileEx` there; probe behavior untested.
- Could the Studio warm the analyzer right after starting its watcher, to move the 2.4 s
  first-build cost off the user's first save? ◇ proposed

## Spike #3 — Disk rendering

*Not started.* See `project-plan.md` §14 v0.0 #3 and §15.3.

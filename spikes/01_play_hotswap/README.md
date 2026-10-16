# Spike #1 — Play, Hot-swap and Attach

Throwaway code for the v0.0 de-risking spike (`docs/project-plan.md` §14, §9.3, §15.3).
Findings go into `ARCHITECTURE.md`; nothing here ships.

| Folder | What it is |
|---|---|
| `game/` | A Flame game with a minimal `StudioScene` (`lib/studio_scene.dart`) that loads `assets/scenes/level1.scene.json` and, on Flame's `onHotReload()`, rebuilds the scene only if the file's content hash changed. The HUD shows the rebuild count, the hash and a Dart-code marker. |
| `driver/` | A Dart CLI that plays the Studio's part: spawns `flutter run --machine` with a fixed DDS port, edits files, hot-reloads through the daemon (`app.restart`), and reads the game's `[studio_scene]` log lines to decide pass/fail. |

## What is being checked

- **(a)** Scene edit → `app.restart` (hot reload) → `StudioScene.onHotReload` rebuilds the scene.
- **(b)** A Dart-only hot reload does **not** rebuild the scene.
- **(c)** VS Code attaches through the fixed DDS port: breakpoints hit, and IDE hot reload works
  while the driver's `flutter run` is still connected (the deciding test for ADR 0001).

Run (a) and (b) on the iOS simulator, an Android emulator **and one physical phone**.

## Quick start

Prerequisites: Flutter stable (tested with 3.44.2) on your `PATH`, Xcode and/or Android SDK.

```bash
cd spikes/01_play_hotswap/game && flutter pub get && cd ../driver && dart pub get
```

Find a device id:

```bash
flutter devices
```

### 1. Automatic checks (a) + (b)

From `spikes/01_play_hotswap/driver`:

```bash
dart run bin/studio_driver.dart -d <device-id> --ci
```

It launches the game, runs both checks, prints `AUTO CHECKS (a)+(b): PASS` or `FAIL`, stops
the game, restores the files it edited and exits with code 0 (pass) or 1 (fail). Repeat for the
iOS simulator, an Android emulator and a physical phone.

### 2. Interactive run and check (c)

```bash
dart run bin/studio_driver.dart -d <device-id> --auto
```

For check (c), run it once without `--repoint-assets` (to see the problem) and once with it
(to confirm the workaround):

```bash
dart run bin/studio_driver.dart -d <device-id> --auto --repoint-assets
```

On a **physical device**, also run the game under a differently named project root so the IDE
doesn't delete the driver's DevFS (see "DevFS name clash" below):

```bash
ln -sfn "$(cd ../game && pwd)" /tmp/game-studio
```

```bash
dart run bin/studio_driver.dart -d <device-id> --auto --repoint-assets --project-root /tmp/game-studio
```

Same checks, but the game keeps running afterwards. Type a command and press Enter:

| Key | Action |
|---|---|
| `s` | Edit the scene (moves the player, recolors the coin, retitles) and hot reload. The scene should rebuild. |
| `d` | Bump `dartMarker` in `lib/dart_marker.dart` and hot reload. The HUD's `code:` changes; the scene must not rebuild. |
| `t` | Touch the scene file (same bytes) and hot reload. The scene must not rebuild. |
| `r` / `R` | Hot reload / hot restart |
| `u` | Print the VM service URL to attach to |
| `q` | Stop the game and restore the edited files |

Always quit with `q` (or Ctrl-C) so the driver restores `level1.scene.json` and
`dart_marker.dart`. If a run is killed hard, restore them with
`git checkout -- spikes/01_play_hotswap/game`.

Then, with the driver still running:

1. Open `spikes/01_play_hotswap/game` in VS Code (Dart + Flutter extensions installed).
2. Run and Debug → **Attach to Studio game (DDS 8181)** (from `game/.vscode/launch.json`).
   If that fails, try **Attach to Studio game (pick URI)** and paste the URL from `u`.
3. Set a breakpoint in `SpikeGame.update` (`lib/spike_game.dart`). It should hit; continue.
4. Edit the `dartMarker` string in VS Code and save (or press the hot reload button). The HUD
   should update, from the IDE's reload.
5. Back in the driver, type `s`, then `t`. `s` should rebuild the scene; `t` must log
   "scene unchanged". Without `--repoint-assets`, expect them to go wrong once VS Code has
   attached and reloaded (see "Asset shadowing" below). With it, they should stay correct; the
   first `s` after attaching logs one extra reload.
6. Type `q`. VS Code's debug session should end with "Application finished" or similar.

No VS Code? `flutter attach` exercises the same coexistence path from a second terminal:

```bash
flutter attach -d <device-id> --debug-url http://127.0.0.1:8181/
```

Press `r` in that terminal for an IDE-style reload, then `s` in the driver.

### Options

| Flag | Default | Meaning |
|---|---|---|
| `-d <id>` | (required) | Device to run on |
| `--auto` | off | Run checks (a)+(b), then stay interactive |
| `--ci` | off | Run checks (a)+(b), then quit with an exit code |
| `--dds-port <n>` | 8181 | Fixed DDS port (the attach URL) |
| `--no-disable-auth-codes` | off | Keep auth codes in the VM service URL, to test whether `--disable-service-auth-codes` is needed for a stable URL |
| `--repoint-assets` | off | Before each reload, point the engine back at the driver's DevFS assets (`_flutter.setAssetBundlePath`); if that folder is gone, reload, re-point, evict the scene and reload again. Workaround for asset shadowing by an attached IDE |
| `--project-root <dir>` | (none) | Pass flutter's hidden `--project-root`. Its folder name names the DevFS; use a symlink to the game with another name to avoid clashing with an attached IDE |
| `-v` | off | Pass `-v` to `flutter run` (shows DevFS sync and asset eviction) |
| `--project <dir>` | `../game` | Game project to run |

## Results

Fill in as you go. Record the Flutter version and device for each row.

| Check | macOS desktop | iOS simulator (iPhone 17) | Android emulator (Pixel 9 Pro XL) | Physical phone (Android CPH2737) |
|---|---|---|---|---|
| (a) scene edit rebuilds | ✅ ~58 ms | ✅ ~70 ms | ✅ ~250 ms | ✅ ~156 ms (USB) |
| (b) Dart-only reload doesn't rebuild | ✅ | ✅ | ✅ | ✅ ~217 ms |
| (c) second client (`flutter attach`) reloads while driver connected | ✅ | ✅ | | |
| (c) VS Code attach | | ✅ | | ✅ |
| (c) VS Code breakpoint hits | | ✅ (`SpikeGame.update`) | | |
| (c) VS Code hot reload while driver connected | | ✅ | | ✅ |
| (c) driver hot restart while an IDE is attached | ✅ (`flutter attach`, `--project-root`) | | | ❌ without / ✅ with `--project-root` (VS Code shows a stale "paused" afterwards, see notes) |
| (c) driver scene edits still apply after an IDE attaches/reloads | ❌ without / ✅ with `--repoint-assets` (✅ cleaner with `--project-root` too) | ❌ without / ✅ with `--repoint-assets` (VS Code) | | ❌ with `--repoint-assets` alone (driver hot restart breaks) / ✅ with `--repoint-assets --project-root` (VS Code) |
| (c) `--disable-service-auth-codes` needed for a stable URL? | Yes: with auth codes the URL changes every run (`/EMWbRKFTAe4=/ws`, `/rY9Oy8-nQ1I=/ws`) | | | |

Flutter 3.44.2 / Flame 1.38.2, macOS 26.2. macOS desktop isn't a v0.1 Play target, but it's
the quickest loop for iterating on the spike.

## Notes so far

- On desktop targets, `flutter run --machine` passes the game's `print` output through as
  raw stdout lines, not `app.log` events. The Studio's Console must handle both.
- With `--dds-port 8181 --disable-service-auth-codes`, `app.debugPort` reports
  `ws://127.0.0.1:8181/ws`, a stable URL across runs.
- Hot reload already syncs changed assets and evicts them from `rootBundle` before `reassemble`,
  so `rootBundle.loadString` with its default cache sees the new scene. No custom service
  extension is needed, as Q66 assumed.
- Two flutter_tools clients coexist for **code**. With the driver's `flutter run` connected,
  `flutter attach --debug-url http://127.0.0.1:8181/` (or VS Code) can hot-reload, and both
  clients keep working. Each client has its own compiler, so both recompile the changed library;
  harmless. Stopping the game from the driver ends the attach session ("Lost connection to
  device").
- **Asset shadowing (breaks Hot-swap while an IDE is attached).** Two flutter_tools behaviors
  combine (reproduced on macOS with `flutter attach`; seen on the iOS simulator with VS Code):
  1. The DevFS is named after the project folder (`game`). When the IDE attaches, its
     flutter_tools finds that name taken and **destroys the driver's DevFS** before creating
     its own (`DevFS: Creating failed. Destroying and trying again`). The engine is still
     pointed at the deleted folder, so the driver's next scene edit reads the **original**
     scene from the app bundle. The driver's next sync recreates its folder.
  2. Each client calls `_flutter.setAssetBundlePath` only once, on its first reload that syncs
     an asset. After the IDE's first such reload, the engine serves the scene from the IDE's
     copy, which only updates when the IDE reloads. Driver edits are then ignored ("scene
     unchanged" though the file changed) until the IDE reloads again.

  Either way the game reads a different copy than the one the driver just wrote, and a `t`
  (same bytes) can log "REBUILT" when the game switches back to the up-to-date copy.

  ```
  after s: disk=425f75a1  game: scene REBUILT #2 …->425f75a1
  after A (attach reload): game: scene unchanged hash=425f75a1
  after s: disk=f1a41103  game: scene unchanged hash=425f75a1   ← ignored
  after s: disk=34fe81c1  game: scene unchanged hash=425f75a1   ← ignored
  after A (attach reload): game: scene REBUILT #3 …->34fe81c1   ← jumps to latest
  ```

  **Workaround (`--repoint-assets`):** before each reload, the driver calls
  `_flutter.setAssetBundlePath` itself over the VM service, pointing the engine back at
  `<its DevFS base>/build/flutter_assets`. If that fails because the folder was deleted (or
  doesn't exist yet), it reloads (which recreates the folder), re-points, evicts the scene
  (`ext.flutter.evict`) and reloads again. With it, the game matched the file on disk after
  every step of `s ATTACH s t A s t A t s`, and on the iOS simulator with VS Code attached and
  hot-reloading between driver edits. Remaining wart: on the first edit after an IDE attaches,
  the first of the two reloads reads a stale copy (the original scene from the app bundle, or
  the IDE's copy if the IDE has already reloaded), so the scene can flash for ~50 ms and
  `onReloaded` can fire twice.

  **On physical devices the re-point isn't enough.** Simulators and desktop use a local DevFS
  writer that recreates the driver's folder on its next sync. Physical Android and iOS devices
  write through the VM service under the DevFS *name*, which the IDE now owns, so the driver's
  folder never comes back. Every re-point then fails, and the driver's hot restart breaks
  because it launches from its old `baseUri` (seen on Android CPH2737 with VS Code):

  ```
  E/flutter: [ERROR:flutter/runtime/dart_isolate.cc(146)] Could not prepare isolate.
  hot restart → code=1 "hot restart failed to complete: _flutter.runInView: (-32000) Could not run configuration in engine."
  ```

  **DevFS name clash fix (`--project-root`):** flutter_tools names the DevFS after
  `basename(projectRootPath)`, and `flutter run` has a hidden `--project-root` option. Running
  with `--project-root` pointing at a symlink to the game named `game-studio` gives the driver
  its own DevFS name, so the attaching IDE creates `game…` without destroying anything. On
  macOS with `flutter attach`, `--project-root` plus `--repoint-assets` was correct at every
  step of `s ATTACH s t A s t R s d A s t`: hot restart worked, and no fallback reload was
  needed after attaching. Verified on the Android phone (CPH2737) with VS Code: every re-point
  after attaching succeeded, every `s` rebuilt, `t` and VS Code reloads stayed unchanged
  (apart from one `t` after a manual scene edit, which correctly rebuilt), and both driver hot
  restarts returned `code=0`. For the Studio, the symlink
  would live in its own support folder, e.g. `<app support>/run/<project>-studio`. `--project-root`
  is hidden and undocumented, so this is a second private-API dependency.

  Caveats for the Studio: `_flutter.setAssetBundlePath` is a private engine extension (the
  one flutter_tools uses), so it may change between Flutter releases. Running the game from a
  folder whose name differs from the IDE's would avoid the DevFS name clash, but the Studio
  runs from the user's project folder, so that isn't an option. **Decision needed for §9.3 /
  ADR 0001:** adopt the re-point plus fallback reload (the Studio needs a VM-service
  connection anyway), or fall back to "the Studio stops reloading while an IDE is attached".
- **VS Code shows "paused" after any hot restart while both are connected** (driver `R` or
  VS Code's own restart), with no breakpoints set and a nonsense top frame (`List.add`,
  `int.&`, `rotl32` called from `List.add`). The game keeps running and `s`/`t` still work.
  Mechanism, reproduced on macOS with a stand-in client: a debug adapter turns on
  `pause_isolates_on_start` and asks DDS for `requirePermissionToResume(onPauseStart)`. Hot
  restart replaces the isolate (`IsolateExit` → `IsolateStart` → `PauseStart`), and the new
  isolate waits until that client resumes it. A stand-in client that never resumed left the
  game stuck at startup; VS Code does resume, but its UI keeps the "paused" state and fetches
  the stack of the running isolate, hence the random frames. Without an IDE-style client, the
  driver's restart emits no pause events at all. For the Studio: after its own hot restart
  with an IDE attached, the game depends on the IDE resuming the new isolate. Pressing
  Continue in VS Code clears the stale state. Worth re-checking against the Dart-Code issue
  tracker before relying on it.
- `flutter run --machine` emits `device.added` / `device.removed` for paired but unreachable
  devices (here two wireless iPhones with `"isConnected": false`) while it runs. The Studio's
  device dropdown should ignore devices that aren't connected.
- Testing pitfall: if an edit writes the same bytes the file already has, the hash doesn't
  change and nothing rebuilds. That's correct behavior, but it looks like a failed Hot-swap.
  The driver now makes every edit unique.

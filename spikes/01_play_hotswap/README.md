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
5. Back in the driver, type `s`. The scene should still rebuild through the driver's reload.
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
| `-v` | off | Pass `-v` to `flutter run` (shows DevFS sync and asset eviction) |
| `--project <dir>` | `../game` | Game project to run |

## Results

Fill in as you go. Record the Flutter version and device for each row.

| Check | macOS desktop | iOS simulator (iPhone 17) | Android emulator (Pixel 9 Pro XL) | Physical phone |
|---|---|---|---|---|
| (a) scene edit rebuilds | ✅ ~58 ms | ✅ ~70 ms | ✅ ~250 ms | |
| (b) Dart-only reload doesn't rebuild | ✅ | ✅ | ✅ | |
| (c) second client (`flutter attach`) reloads while driver connected | | ✅ | | |
| (c) VS Code attach + breakpoint | | | | |
| (c) VS Code reload while driver connected | | | | |
| (c) needs `--disable-service-auth-codes`? | | | | |

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
- Two flutter_tools clients coexist (iOS simulator): with the driver's `flutter run` connected,
  `flutter attach --debug-url http://127.0.0.1:8181/` hot-reloaded a Dart change (scene
  correctly not rebuilt), the driver's next scene edit still rebuilt the scene, and the attach
  client reloaded again afterwards. Each client has its own compiler, so both recompile the
  changed library; harmless. Stopping the game from the driver ends the attach session
  ("Lost connection to device"). The VS Code breakpoint and reload checks are still to do by hand.
- Testing pitfall: if an edit writes the same bytes the file already has, the hash doesn't
  change and nothing rebuilds. That's correct behavior, but it looks like a failed Hot-swap.
  The driver now makes every edit unique.

# Flame Studio — Architecture

How Flame Studio is built and why. This document starts from the v0.0 de-risking spikes
([`project-plan.md`](project-plan.md) §14) and grows with the code. The plan describes the
intended design; this file records what was verified, what had to change, and what depends on
behavior we don't control.

Status: **v0.0 in progress.** Spike #1 done; spikes #2 (generator) and #3 (disk rendering) to
come.

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

*Not started.* See `project-plan.md` §14 v0.0 #2 and §15.3.

## Spike #3 — Disk rendering

*Not started.* See `project-plan.md` §14 v0.0 #3 and §15.3.

# Contract: Generator supervisor

`GeneratorSupervisor` (`apps/editor/lib/process/src/generator_supervisor.dart`, no Flutter import)
runs and follows `build_runner` for the open project. It implements project-plan §9.2, *Q48* and
*Q77*. States and the Console contract are in [../data-model.md](../data-model.md).

## Surface

```dart
final class GeneratorSupervisor {
  GeneratorState get state;
  Stream<GeneratorState> get states;
  Stream<String> get lines;                   // raw generator output, for the Console
  Future<void> start();                       // on project open, and the Start button
  Future<void> dispose();                     // stops Pyro's own run only, never an external one
}
```

## Starting

1. If the project's pubspec has no `build_runner`, its `pubspec.lock` resolves `build_runner` below
   2.14 (the version found goes in the reason), or the Runtime compatibility check failed: state
   `notSetUp`, nothing else. The version read is `BuildRunnerVersion.of(projectPath)`
   (`lib/project/build_runner_version.dart`).
2. Probe the lock ([BuildLockProbe](#buildlockprobe)). `held` → `external`. `free` or `absent` →
   spawn `<flutter root>/bin/dart run build_runner watch` in the project (state `starting`).

## Takeover table (*Q77*)

When Pyro's own run exits with code 0 and Pyro did not ask it to stop (the exit line is
`Exiting as requested by another build_runner process.`, or the code-0 fallback), the supervisor
**re-probes** and does not report an error:

| Lock after the exit | What the user did | State | Next |
|---|---|---|---|
| held | ran `build_runner watch`, `build` or `--only-check` | `external` | re-probe every 1 s; when free, start Pyro's own run again |
| free (or absent) | ran `build_runner stop` | `stopped` | nothing; the *Start* button calls `start()` |

Any other exit (non-zero, a crash) → `error` with the last severe line, and the supervisor does not
restart by itself (a loop would hide the cause); *Start* is offered.

The "waiting" case: if Pyro's own spawn prints `Waiting for already-running build_runner.`, another
run took the lock between the probe and the spawn. The supervisor stops its own process, re-probes,
and goes to `external`.

## Output classes (`generator_output.dart`)

A table of patterns to events, tested on recorded output (`test/fixtures/transcripts/`):

| Class | Effect |
|---|---|
| `building` | state `generating` |
| `succeeded` | state `upToDate`, `generation` + 1 |
| `failed` / a severe line | state `error` carrying the line; the Manifest's own `errors` give the file and message when present |
| `takeover` | triggers the table above |
| `waiting` | the waiting case above |
| anything else | Console only |

The exact strings of `building` and `succeeded` come from a real run before the table is written
(research R9). The two strings quoted above are from spike #2.

## BuildLockProbe

```dart
enum LockProbeResult { held, free, absent }

final class BuildLockProbe {
  Future<LockProbeResult> check(String projectPath);
}
```

- Path: `<project>/.dart_tool/build/lock/build_runner.lock`.
- `absent` if the file does not exist. The probe never creates the file or `.requested`.
- Otherwise open with `FileMode.append`, `lock(FileLock.exclusive)` (non-blocking: a held lock throws),
  then `unlock()` and `close()` in a `finally`. A lock error is `held`.
- Async, so it never blocks the UI isolate.
- Tested against a real lock held by a separate `dart` helper process (held, then free after it exits,
  then absent).

## Idle rule used by code reload

| State | Idle for code reload |
|---|---|
| `upToDate`, `stopped`, `notSetUp`, `error` | yes, at once |
| `starting`, `generating` | no; wait for the next `upToDate` or `error` |
| `external` | after `lib/pyro.g.dart` and `lib/pyro.manifest.json` have not changed for 2 s following the save, or 2 s after the save if they never change |

## Ownership

`dispose()` kills Pyro's own `build_runner` child (SIGTERM, then SIGKILL after the stop timeout) and
cancels the re-probe timer. It does nothing to an external run (FR-022). The child and the timer are
released when the project closes, and tests assert none remain.

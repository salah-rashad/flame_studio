# Recorded transcripts (spec 007)

Real output recorded on the reference Mac for Phase 5's tests. The older daemon recordings of spec
005 stay in `../daemon/`.

**Auth codes.** `dart run bin/play.dart <project> --record <file>` masks every VM service auth code
as `<auth-code>` before it writes a line. `build_runner` prints no address. Before committing a
transcript, this must print nothing:

```bash
grep -rE '[A-Za-z0-9_-]{6,}=/' test/fixtures/transcripts
```

| File | Recorded with | Flutter | Date | Read by |
|---|---|---|---|---|
| `run-scene-save.txt` | `dart run bin/play.dart ../../example --record …` (start, one scene save, stop) | 3.44.2 | — | `play_controller_test.dart` |
| `build-failure.txt` | the same, on a scratch copy of `example/` with a compile error in `lib/` | 3.44.2 | — | `play_controller_test.dart` |
| `exit-without-stop.txt` | the same; the game's window closed by hand | 3.44.2 | — | `play_controller_test.dart` |
| `ide-attached.txt` | the same, plus `flutter attach -d macos --debug-uri <address>` in another terminal | 3.44.2 | — | `play_session_test.dart`, `play_controller_test.dart` |
| `build-runner-watch.txt` | `dart run build_runner watch` in `example/` (start, a build, a save) | 3.44.2 | — | `generator_output_test.dart` |
| `build-runner-takeover.txt` | a second `dart run build_runner build` while the watcher runs | 3.44.2 | — | `generator_output_test.dart` |
| `build-runner-stop.txt` | `dart run build_runner stop` while it runs | 3.44.2 | — | `generator_output_test.dart` |
| `build-runner-error.txt` | a syntax error in an annotated class, then the fix | 3.44.2 | — | `generator_output_test.dart` |

A dash in the date column means the file is not recorded yet.

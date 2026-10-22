# Daemon transcripts

What `flutter run --machine` writes to stdout, one line per line, replayed by
`test/process/fake_process.dart` (spec 005, research R6). Auth codes are the
known fake `AbCdEf123456=`, so tests can assert it never leaks.

These are **hand-written** from spike #1's driver and the flutter_tools daemon
protocol, then checked against a real Flutter 3.44.2 recording on Linux
(2026-10-22): the message shapes matched, and the recording added
`app.devTools` and `app.dtd` (both carry addresses, which the client drops)
and the success message `Reloaded 0 libraries`. Quickstart §5.10 replaces them with recordings from the reference
Mac (`dart run bin/play.dart <project> --record <file>`, which masks auth
codes) and notes any difference here.

| File | What it holds |
|---|---|
| `start.txt` | build progress, a raw VM service line, `app.start`, `app.debugPort`, `app.started`, the game's first line |
| `reload_ok.txt` | a hot reload's progress and its `code: 0` response (request id 1) |
| `reload_failed.txt` | a hot reload that fails to compile (`code: 1`) |
| `stop.txt` | the `app.stop` response (request id 2) and event |
| `crash.txt` | the tool losing the app; the test then ends the process |
| `no_macos_target.txt` | a project without a macOS runner; the test then exits with 1 |

# Daemon transcripts

What `flutter run --machine` writes to stdout, one line per line, replayed by
`test/process/fake_process.dart` (spec 005, research R6). Auth codes are the
known fake `AbCdEf123456=`, so tests can assert it never leaks.

These are **real recordings** from the reference Mac (quickstart §5.10, 2026-10-22: macOS 26.2,
Flutter 3.44.9, `dart run bin/play.dart ../../example --record <file>`, which masks auth codes as
`<auth-code>`). Each is cut from a recording and has its app id replaced by the one in
`start.txt` (`00808424-…`), so the tests share one. Nothing else was edited.

Differences from the hand-written files they replaced, and what the tests do about them:
- `start.txt` begins with `pub get` output, and its `app.debugPort` etc. carry masked codes. The
  desktop target writes no raw "Dart VM service is listening" line, so the tests no longer
  expect one (`redact_test.dart` covers redaction of such a line).
- `reload_failed.txt`: the response message is `DevFS synchronization failed`. The compile error
  itself goes to stderr, which the file does not hold.
- `crash.txt` ("Lost connection to device." from closing the window) is followed by `app.stop`.
- `no_macos_target.txt` is from a project with `lib/main.dart` but no `macos/`; the message
  starts with `Error:` and there is no `daemon.logMessage`, only `app.stop`.
- `stop.txt` has request id 1 (the stop was the session's first request), and "Application
  finished." precedes the response.

| File | What it holds |
|---|---|
| `start.txt` | build progress, a raw VM service line, `app.start`, `app.debugPort`, `app.started`, the game's first line |
| `reload_ok.txt` | a hot reload's progress and its `code: 0` response (request id 1) |
| `reload_failed.txt` | a hot reload that fails to compile (`code: 1`) |
| `stop.txt` | the `app.stop` response (request id 1) and event |
| `crash.txt` | the tool losing the app; the test then ends the process |
| `no_macos_target.txt` | a project without a macOS runner; the test then exits with 1 |

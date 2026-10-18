# Quickstart: Validating the Document Model

How to check that the feature works. The behavior is in [spec.md](spec.md), the types in
[data-model.md](data-model.md) and the API in [contracts/document-api.md](contracts/document-api.md).
Everything is headless: there is no editor UI to click yet.

## Prerequisites

- Flutter 3.44.2 (`/Users/salah/Library/flutter/bin` on `PATH`), and `flutter pub get` run once
  at the repository root.
- Generated files up to date: `dart run build_runner build -d` in `apps/pyro` after changing a
  freezed class (the generated files are committed, so a fresh checkout doesn't need it).

## 1. Run the tests

```bash
cd apps/pyro && flutter test test/document
```

| Test file | Covers |
|---|---|
| `scene_document_test.dart` | `fromScene`/`toScene`; each edit and each refusal in data-model.md; untouched Nodes stay `identical` (US1 #8, FR-003); invariants hold after random edit sequences |
| `history_test.dart` | apply, undo, redo, redo tail dropped, no-op edits, coalescing runs and what ends them, first label kept, the 200-entry cap, dirty by identity, `saved` null for repaired and restored (US1, FR-009 to FR-016) |
| `round_trip_test.dart` | every canonical fixture in `packages/pyro_runtime/test/fixtures/scenes/canonical/` opens and saves byte for byte (US2 #1, SC-001); a non-canonical file opens clean and saves canonical (US2 #6); edit, undo to saved, save is byte-identical |
| `scene_files_test.dart` | open errors (US2 #8); a repaired Scene opens dirty with its report (US2 #7); the gate's three cases (US4); changed on disk, deleted on disk, identical bytes, forced overwrite (US2 #10); "Save as" onto an existing file; new Scene needs a path (US2 #9); a missing folder |
| `atomic_write_test.dart` | a failing file system that throws at each step of a save: the target is always the whole old or the whole new file, and no temporary file remains (US2 #3, SC-003); one test on the real file system in a temporary folder, run on all three CI OSes (rename replaces on Windows) |
| `recovery_store_test.dart` | file names and metadata (contracts/recovery-copies.md); find, discard, the 30-day prune, each unreadable case kept and reported (US3 #4, #7, FR-025a) |
| `document_session_test.dart` | with `fake_async`: a copy every 30 s only while dirty and changed (US3 #1, #2); save and discard remove it (US3 #3); restore opens dirty with empty history and saves to the Scene's path (US3 #5); declining removes it (US3 #6); a simulated crash loses at most 30 s (SC-004); edits during a save stay unsaved (FR-020); saves are queued; `close` refuses a dirty session |

## 2. Round-trip a Scene by hand

Open any canonical fixture as a document, save it to a copy, and compare:

```bash
cd apps/pyro && flutter test test/document/round_trip_test.dart --plain-name all_kinds
```

The test writes nothing outside its in-memory file system; on a mismatch it prints a line diff
of the expected and saved text.

## 3. Interrupt a save

`atomic_write_test.dart` runs a save once for every operation the file system performs during
it, failing at that operation (open, write, flush, close, rename). After each run, the target
must read back as exactly the old bytes or exactly the new ones, and the folder must contain no
`*.pyro-tmp` file.

## 4. Measure the budgets (SC-005, SC-006)

```bash
cd apps/pyro && flutter test benchmark/document_benchmark_test.dart
```

Prints, for a generated 1,000-Node Scene: the median time of a one-Node transaction, an undo
and a redo (SC-005: < 1 ms; JIT numbers, so an upper bound for the release build), the time to
open and to save it, and the time spent on the calling isolate during each (must stay under a
frame). For memory (SC-006), the benchmark builds a 200-step history and prints the RSS change;
confirm in profile mode with the DevTools memory view: retained size of the history against
the Scene alone, < 10% more.

## 5. Recover after a crash

`document_session_test.dart`'s crash test does this with a fake clock: open a fixture, edit,
advance 31 s, drop the session without closing it, then `RecoveryStore.find` returns
`RecoveryAvailable` and `DocumentSession.restore` gives back the edited state, dirty, with an
empty history, while the Scene file still holds the original bytes.

## 6. Refuse an unreadable version

`scene_files_test.dart`'s gate tests save with `runtimeReadsUpTo` set to `null`, `0` and `1`:
only `1` writes; the others throw `RuntimeVersionUnknown` and `RuntimeTooOld(reads: 0,
writes: 1)` and leave the file's bytes unchanged.

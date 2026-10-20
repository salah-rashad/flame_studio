# Research: Document Model

Phase 0 of [plan.md](plan.md). Each entry is a decision the plan relies on, why it was made, and
what else was considered. Spike #4 (`spike/04-riverpod`, `spikes/04_riverpod/README.md`)
prototyped the document, history and providers on 2026-10-16; its findings are cited as
"spike #4" and reused where they hold.

## R1. Toolchain: stay on Flutter 3.44.2, analyzer 12, prerelease freezed

**Decision:** keep the repository on Flutter 3.44.2 (the author's choice, 2026-10-19) and add:

| Package | Version | Kind |
|---|---|---|
| `freezed_annotation` | ^3.1.0 | dependency |
| `fast_immutable_collections` | ^12.0.0 | dependency |
| `uuid` | ^4.6.0 | dependency |
| `file` | ^7.0.1 | dependency |
| `clock` | ^1.1.2 | dependency |
| `crypto` | ^3.0.6 | dependency |
| `flutter_riverpod` | ^3.3.2 (resolves 3.3.2) | dependency |
| `riverpod_annotation` | 4.0.3 | dependency |
| `freezed` | 3.2.6-dev.1 | dev dependency |
| `riverpod_generator` | 4.0.4 | dev dependency |
| `build_runner` | ^2.15.1 | dev dependency |
| `fake_async` | ^1.3.3 | dev dependency |

`path_provider` is added by #1, which decides where the recovery folder lives (R11).

**Rationale:** checked in a throwaway worktree of this repository on 2026-10-19.

- The workspace has one lock. `pyro_annotations` and `pyro_generator` depend on `test`
  (^1.25.0), and the `test` versions that match `flutter_test`'s pinned `test_api` 0.7.11 on
  Flutter 3.44.2 cap `analyzer` below 13. The lock holds analyzer 12.1.0.
- So spike #4's combination (freezed 4.0.0-dev.3, riverpod_generator 4.0.9, both analyzer ≥ 13)
  **fails to resolve here**: the spike was a standalone project with no `test` dependency.
- The newest analyzer-12 line resolves: freezed 3.2.6-dev.1 (analyzer ≥ 12 < 13),
  riverpod_generator 4.0.4 (analyzer ^12), which pins riverpod_annotation 4.0.3 and allows
  flutter_riverpod 3.3.2. build_runner resolves to 2.15.1 (as Q76 predicted).
- A probe with a `@Freezed(equal: false)` class holding an `IMap`, a `@riverpod` Notifier family
  and a two-argument derived provider using `.select` generated in 12 s and passed
  `flutter analyze` with the repo's rules.
- Stable freezed (4.0.3) needs Dart 3.13 (Flutter 3.47.x). Moving the pin is a separate
  decision, recorded as an open follow-up (plan.md, Risks).

**Riverpod in this feature:** the packages are added now, as the feature description asks, so
the lock is proven with both code generators before #1 depends on them. No provider is written
here: the provider layout (§8.5) is #1's (phases.md #1), and this feature's API is plain Dart
that a Notifier can wrap (R13).

**Alternatives considered:** move to Flutter 3.47.7 first (stable freezed 4.0.3,
riverpod_lint, `--only-check`; declined for now by the author); hand-written immutable classes
without freezed, as the Runtime does (allowed by constitution I, but the technology constraints
name freezed for app models, Q26); drop `test` from the pure-Dart packages (they need it,
`flutter_test` isn't available to them).

## R2. The Document holds its own maps; it doesn't build a `Scene` per edit

**Decision:** `SceneDocument` holds `rootId`, `IMap<NodeId, Node> nodes`,
`IMap<NodeId, NodeId> parents` (every non-root Node's parent), and the Scene's unknown top-level
keys. It is built from a `Scene` when a file is opened and turned back into one when it is
saved. The Node classes are `pyro_runtime`'s, unchanged.

**Rationale:**

- `Scene`'s constructor copies its map and checks the whole tree (O(n)) so that a Scene is
  always valid (spec 001). Building one per keystroke would cost a full copy and walk per edit
  and break structural sharing.
- The edit operations (R6) keep the tree valid by construction, so the full check runs once per
  save, inside `Scene`'s constructor, as a safety net: if it ever throws, the save fails with a
  bug report and nothing is written.
- `parentId` in memory (§8.1, *Q23*) is kept as a separate index rather than inside each Node,
  because the Runtime's Nodes don't have one (only `childIds` is persisted, *Q47*). A move
  changes two `childIds` lists and one index entry.

**Alternatives considered:** a `Scene` per state (O(n) per edit, no sharing); wrapping each Node
in a document Node with a `parentId` (doubles the objects, and every consumer unwraps).

## R3. `fast_immutable_collections` for structural sharing

**Decision:** `IMap` (and `IList` for history), as §8.1 proposes and spike #4 used.

**Rationale:** checked in the package source (12.0.0, `lib/src/imap/`):

- `IMap.add` is O(1): the new map is an `MAdd` link pointing at the previous one, so a history
  of edits shares everything before it.
- Reads walk the chain; after `IMap.flushFactor` counted operations (50 by default, reads
  included) the map flushes into one flat `LinkedHashMap` (O(n), about 20–50 µs at 1,000
  entries), so reads stay O(1). The history entry holding that state keeps the flat copy.
- Measured (2026-10-19, heap snapshot, tasks.md T038): a 200-step history on a 1,000-Node Scene
  holds 909 KB beyond the Scene (525 KB) and its opening state, about a dozen flat copies plus
  the new Nodes. With flushing off it is 130 KB: the floor, since each step keeps one new Node
  (about 0.6 KB here). Plain `Map` copies would hold about 32 KB per step (≈ 6 MB).
- SC-006 was first written as "under 10% of the Scene", which no snapshot history can meet (the
  floor alone is about 25%); it is now "under 2 MB", which the defaults meet without a
  process-wide flush setting (spec Clarifications, 2026-10-19). Diff-based undo, which would
  hold far less, is a possible later enhancement that would revisit *Q22*.

**Alternatives considered:** plain `Map` copies (fast enough, too much memory); a hand-written
HAMT (best asymptotics, ~300 lines to maintain, no second caller); `built_collection` (copy on
write, no sharing).

## R4. Equality rules

**Decision (spike #4, finding 3):**

- `SceneDocument`: identity (`@Freezed(equal: false)`). "Not identical" means "changed", and an
  edit that changes nothing returns the same object.
- `DocumentHistory`, `OpenDocument`: no `==` override (identity), hand-written.
- Nodes: the Runtime's classes, compared by identity (spec 001, R4), so untouched Nodes cost one
  pointer compare in `select` and in the reconciler.
- Small value types this feature adds (`SaveResult`, `RecoveryInfo`): freezed value equality.

**Rationale:** Riverpod 3 filters every notification and `select` with `==`; a deep `==` on the
document cost ≈ 2 ms at 5,000 Nodes in the spike and ran on every edit.

## R5. History rules

**Decision:** `DocumentHistory` is a pure value: `IList<HistoryEntry> entries`, `int index`, a
`SceneDocument? saved` and the `Object? openCoalesceKey` of the run in progress.

- **Apply:** an edit returning the identical document is dropped (no entry, FR-009). Otherwise
  the redo tail is discarded (FR-012) and the new state is appended, or, when the coalescing key
  equals `openCoalesceKey`, it replaces the top entry, keeping the **first** label (FR-011).
- **Ending a run:** `openCoalesceKey` is set by a keyed transaction and cleared by an unkeyed
  one, by undo, redo and by marking a save. This implements "any other transaction, an undo, a
  redo or a save ends the run" without comparing entries, and means a save never rewrites the
  saved entry (spike #4, finding 4).
- **Dirty:** `!identical(current, saved)`. `saved` is null for repaired and restored documents
  (FR-015, FR-016), so they stay dirty until saved; a new document's root-only state is `saved`.
- **Mark saved:** takes the state that was written (R8), not the current one, so edits made
  while a save runs stay dirty (FR-020). If that state is no longer in history, `saved` still
  points at it, and the document is dirty, which is correct.
- **Cap:** at most 200 entries after the initial one (FR-014); the oldest is dropped first. If
  it was the saved one, `saved` still holds it, so the document stays dirty until the next save.
- **Labels:** `undoLabel` is the current entry's label, `redoLabel` the next one's (FR-013).

**Alternatives considered:** spike #4's rule (coalesce while the top entry's key matches and
isn't the saved one; label of the latest step). It coalesced across an undo-then-redo and
relabelled runs; the spec fixes both.

## R6. Edit operations and transactions

**Decision:** four basic operations on `SceneDocument`, each pure and each keeping the tree
valid (FR-007):

| Operation | Refuses (with `DocumentEditError`) |
|---|---|
| `addNode(node, parentId:, index:)` | duplicate Node ID, unknown parent, a second root, a Node with children of its own, index out of range |
| `removeNode(id)` (whole subtree) | unknown ID, the root |
| `moveNode(id, parentId:, index:)` | unknown IDs, the root, a target inside the moved subtree, index out of range |
| `replaceNode(node)` | unknown ID, a changed kind from root or to root, changed `childIds` |

- A transaction is `transact(label, SceneDocument Function(SceneDocument) edit, {coalesceKey})`
  (§8.2, spike #4 finding 4). The edit chains operations; because states are immutable, a
  failure part-way leaves nothing to undo.
- A `DocumentEditError` from the edit is rethrown as `TransactionFailed(label, cause)`, naming
  the label and the Nodes (FR-008, FR-030). Other errors are bugs and propagate unchanged; the
  document is unchanged either way.
- Structure changes go only through add, remove and move; `replaceNode` refuses changed
  `childIds`, so a panel can't corrupt the tree through a data edit.
- Setting a Node's `childIds` needs a switch over the sealed Node kinds, because the base class
  has no `copyWith`. It lives in the app (`node_children.dart`), so a new Node kind breaks the
  build there instead of silently losing children.
- No kind rules (which kinds may parent which) are enforced: the Scene format has none, and the
  hierarchy (#3) decides what it offers.
- New Node IDs come from a `NodeIdSource` (default UUID v4, *Q14*); tests pass a counter.

**Alternatives considered:** a mutable builder inside `edit` (spike #4's suggestion; chaining
pure operations is enough at this scale and keeps one code path); a command pattern with
hand-written reverts (rejected by *Q22*).

## R7. Atomic save

**Decision:** write the bytes to a temporary file in the target's directory, flush it to disk,
then rename it onto the target.

- Temporary name: `.<target name>.<random>.pyro-tmp`. It starts with a dot and doesn't end in
  `.scene.json`, so tools that match Scene files ignore it.
- `File.writeAsBytes(bytes, flush: true)` flushes the data before the rename, so a power loss
  can't leave a renamed but empty file.
- `rename` replaces the target in one step: POSIX `rename(2)` on macOS and Linux, and on Windows
  the Dart VM's rename uses `MoveFileExW` with `MOVEFILE_REPLACE_EXISTING` (CI checks it on all
  three OSes).
- On any failure the temporary file is deleted (best effort, logged if that fails too) and the
  target is untouched (FR-019).
- Saves of one document run one at a time; a second save waits for the first.
- A missing directory isn't created: the save fails naming the path (spec edge case).

**Limits:** the directory itself isn't flushed (Dart has no API for it), so after a power loss
the rename could be undone, leaving the complete old file, which is still safe.

**Alternatives considered:** writing in place (a running game could Hot-swap a half-written
file, §8.2); a temporary file in the system temp folder (rename across volumes isn't atomic).

## R8. The changed-on-disk check

**Decision:** keep the SHA-256 digest of the bytes last read or written as the document's
baseline. Before writing, read the target, hash it, and refuse with `SceneChangedOnDisk` if it
differs or the file is gone, unless the save is forced (FR-019a). "Save as" onto an existing
file other than the document's own refuses with `SaveTargetExists` unless forced.

**Rationale:** content, not timestamps: a checkout of identical bytes isn't a change (spec edge
case), and timestamps are unreliable across git operations. A digest keeps 32 bytes per document
instead of a copy of the file. `crypto` is a Dart team package with no dependencies.

**Limit:** a write by another tool between the check and the rename isn't caught (a window of
milliseconds). File watching (#1 or later) narrows it; nothing in this feature can close it.

## R9. Keeping the UI isolate free

**Decision:** all file access is async. `SceneCodec.decode` and `SceneCodec.encode` run off the
UI isolate (spec 001, R9): decoding a 1,000-Node Scene takes tens of milliseconds, more than a
frame. Hashing runs in the same call as encoding or decoding. Edits, undo and redo stay on the
calling isolate (they're microseconds, SC-005).

The work goes through an injected runner, `typedef Offload = Future<R> Function<R>(FutureOr<R>
Function() work);`, whose default is `Isolate.run`. `SceneFiles`, `RecoveryStore` and
`SessionServices` each take one. Tests that use `fake_async` pass a runner that does the work in
place, because an `Isolate.run` reply arrives on the real event loop, which `fake_async` never
runs, so those futures would never complete. One test in `scene_files_test.dart` keeps the
default, so the real isolate path (sending a Scene, getting one back) is covered.

**Rationale:** `Isolate.run` returns its result with `Isolate.exit`, so the decoded Scene comes
back without a copy; sending a Scene to be encoded copies it, which the benchmark measures. The
runner is a documented seam with a test double (constitution I), not a speculative
abstraction.

## R10. Injected file system and time

**Decision:** every class that touches files takes a `FileSystem` from `package:file`
(`LocalFileSystem` in the app, `MemoryFileSystem` in tests, and a forwarding file system that can
fail at a chosen operation or hold a write until the test releases it). Time comes from
`package:clock`; the recovery timer uses `Timer.periodic`, driven by `fake_async` in tests, with
the inline runner of R9.

Constitution V asks for the file system and time to be injected or faked. Two places use real
files on purpose: the fixtures are read from the repository, and one atomic-write test runs on an
injected `LocalFileSystem` in a temporary folder, so CI checks on each OS that rename replaces the
target (R7). No test waits on wall-clock time.

## R11. Recovery copies on disk

**Decision:** a recovery folder chosen by the caller (in the app, `recovery/` under the
application support folder from `path_provider`, wired by #1). Each copy is two files named by
the hex SHA-256 of `<project root>\n<Scene path>` (absolute, normalized):

- `<key>.scene.json`: the document's state, written with `SceneCodec.encode`, so it is a normal
  Scene file.
- `<key>.recovery.json`: `{"projectRoot", "scenePath", "writtenAt", "formatVersion": 1}`.

Both are written atomically (R7), the Scene first. A copy is complete when both files exist and
read; anything else is reported as unreadable and kept (FR-029). On each check, copies whose
`writtenAt` (or, if unreadable, file modification time) is older than 30 days are deleted
(FR-025a). Format details: [contracts/recovery-copies.md](contracts/recovery-copies.md).

**Rationale:** a hashed name fits any path length and has no characters to escape; the metadata
holds the real paths so a copy can be listed and checked; two files keep the Scene readable by
the normal codec.

**Alternatives considered:** one JSON envelope with the Scene as a string (unreadable by the
codec and by a person); names built from escaped paths (length limits on Windows).

## R12. When recovery copies are written

**Decision:** a `RecoveryTimer` per open document fires every 30 seconds (FR-024). On each tick
it writes a copy if the document is dirty and its current state isn't the one it last wrote (no
point rewriting an identical copy). A save, or a discard-and-close, stops the pending write and
removes the copy (FR-027). Restoring opens the copy as a document with no saved state and an
empty history, whose baseline is the digest of the Scene file at that moment (FR-028).

A new Scene that has never been saved has no file path, so there is nothing to key its copy by
and nothing the developer would open to be offered *Restore*; it gets recovery copies from its
first save on. #1 can ask for the file name when a Scene is created if that gap matters.

**Alternatives considered:** writing a few seconds after edits stop (bounds loss better during
long edits but doesn't match *Q85*'s "interval" setting); writing after every transaction (disk
churn during a drag).

## R13. The API shape: pure values plus one session class

**Decision:**

- Pure values: `SceneDocument` (state and edits), `DocumentHistory` (undo rules) and
  `OpenDocument` (history, path, baseline digest, repair report).
- Services: `SceneFiles` (open, save, save as, the gate and the change check) and
  `RecoveryStore` (find, write, restore, discard, prune).
- `DocumentSession`: one open Scene. It holds the current `OpenDocument`, runs transactions,
  undo and redo, serializes saves, owns the `RecoveryTimer`, removes the recovery copy after a
  save or discard, and publishes each new state on a synchronous broadcast stream.

**Rationale:** the rules are testable without Riverpod or a widget tree (spike #4, finding 4),
and #1's `documentProvider(sceneId)` stays thin: it holds a session and mirrors its state, and
keeps it synchronous because loading happens before the provider is built (spike #4, finding 7).
`DocumentSession` is the deep module: a few methods hide history, files, digests and the
recovery timer.

**Alternatives considered:** writing `documentProvider` here (the provider layout is #1's, and
it would pull Riverpod lifecycles into a headless feature); having #1 orchestrate save plus
recovery removal (FR-027 would then be untested here).

## R14. The `schemaVersion` gate

**Decision:** every save takes `int? runtimeReadsUpTo`, the newest Scene version the project's
Runtime reads, from #1's compatibility check (*Q49*). Null refuses with
`RuntimeVersionUnknown`; a value below `Scene.currentSchemaVersion` refuses with
`RuntimeTooOld(reads:, writes:)`. Both are checked before anything is read or written (FR-022).
Recovery copies aren't gated: the Runtime never reads them.

## R15. Fixtures

**Decision:** the round-trip tests read `pyro_runtime`'s canonical fixtures in place
(`../../packages/pyro_runtime/test/fixtures/scenes/canonical/`), so there is one set of
fixtures for the format; the app adds only document-specific fixtures (a repaired Scene, a
recovery folder).

**Alternatives considered:** copying the fixtures into the app (two copies drift apart).

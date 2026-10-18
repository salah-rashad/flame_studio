# Research: Scene Format

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-18

Each section records one decision the plan depends on. Measurements were taken on the author's
Mac with Dart 3.12 (Flutter 3.44.2), JIT, using a throwaway script in the session scratchpad.

---

## R1. Parsing: a strict reader instead of `jsonDecode`

**Decision:** read Scene text with a small strict JSON reader in `pyro_runtime`
(`lib/src/scene/json/`), not `dart:convert`'s `jsonDecode`.

**Rationale:**

- `jsonDecode('{"a":1,"a":2}')` returns `{a: 2}`: duplicate keys are silently dropped. A bad
  merge can produce duplicate keys, and the spec requires refusing them by name (edge cases,
  FR-026). Data Integrity (Principle IV) rules out silently keeping one value.
- `jsonDecode` reports a byte offset only (`Unexpected character @ 12`). The spec wants errors
  that say where; the reader reports line and column too.
- The reader builds unmodifiable maps and lists directly, so the model needs no second copy to
  freeze values (Principle I, immutability).

**Cost:** about 250 lines plus tests. `jsonDecode` parsed a 540 KB, 1,000-Node scene in ~1.7 ms;
a straightforward Dart reader over code units is expected to be 5–20× slower, which is still
~10–35 ms, inside SC-006's 100 ms. The benchmark (quickstart §4) checks this.

**Alternatives considered:**

- *`jsonDecode` plus a separate duplicate-key scan:* the scan is a tokenizer anyway, so it costs
  the same code and parses twice.
- *A `reviver` callback:* it sees key/value pairs but not object boundaries reliably enough to
  detect duplicates.
- *A pub package:* adds a dependency to a package that ships in every game, for ~250 lines.

## R2. Writing: a canonical writer

**Decision:** write Scenes with a hand-written canonical writer; the rules are in
[contracts/scene-file-v1.md](contracts/scene-file-v1.md#canonical-form).

**Rationale:** `JsonEncoder.withIndent` can't express what the spec requires:

- a fixed top-level order (`schemaVersion`, `rootId`, `nodes`) with every other key sorted
  (FR-015);
- number arrays inline (`[320, 128]`) so a vector is one line, while `childIds` and `tags` keep
  one entry per line, so two branches adding different children merge cleanly;
- one canonical number form across platforms (R3).

**Alternatives considered:** post-processing `jsonEncode` output (fragile), or sorting a
`SplayTreeMap` before encoding (handles key order only).

## R3. Numbers have one written form on every platform

**Decision:** a finite integral value with magnitude below 10²¹ is written as plain digits
(`80`, never `80.0`); any other finite value uses Dart's shortest round-trip `toString`
(`0.1`, `1e-7`, `1.23e-18`, `1e+21`); `-0.0` is written `0`; NaN and infinities can't be
written and raise an error naming the Node and key.

**Rationale:**

- On the Dart VM, `80.0.toString()` is `80.0` and `1e20.toString()` is
  `100000000000000000000.0`; compiled to JavaScript (games run on the web), the same values are
  `80` and `100000000000000000000`. The rule above matches JavaScript's `Number.toString`, so
  a Scene saved anywhere is byte-identical.
- The format layer doesn't know Field types (they come from the Manifest or the Registry), so it
  can't decide between `int` and `double` by itself. Consumers coerce: a `double` field accepts
  any JSON number. This rule is part of the contract.

**Alternatives considered:** always writing doubles with a fraction (`80.0`), which can't be
reproduced on the web, where `80.0` and `80` are the same value.

## R4. Plain immutable classes, no freezed, in the Runtime

**Decision:** the scene model is hand-written `final` classes with `final` fields, unmodifiable
collections and `copyWith`. Value equality only on small value types (`Vec2`, `NodeTransform`,
`SpriteRegion`, `NodeAnchor`, `EntityRef`, `AssetRef`); `Node` and `Scene` compare by identity.

**Rationale:**

- `pyro_runtime` ships in every game and should stay small (§5); freezed would add
  `freezed_annotation` as a runtime dependency and a build_runner step to a published package.
- The reconciler and the Document's dirty flag work on `identical` (§8.2, §8.3), so deep
  equality on Nodes has no caller. Tests compare canonical bytes, plus targeted assertions.
- The Document model (#2) uses freezed for its own types (phases.md) and wraps this model.

**Alternatives considered:** freezed in the Runtime (dependency and codegen cost); keeping each
Node as its raw JSON map with typed getters (loses validation at read time and makes every
consumer re-parse).

## R5. The format code is pure Dart

**Decision:** everything under `packages/pyro_runtime/lib/src/scene/` imports only `dart:`
libraries, with its own `Vec2` rather than Flame's `Vector2`. A test fails if any file there
imports `package:flutter` or `package:flame`. The debug-only repair warning (FR-024a) needs
`kDebugMode`, so it lives in `lib/src/loader/`.

**Rationale:** the format must never depend on a Flame version (§12); Pyro, the Runtime and
tests share it; and pure Dart keeps the benchmark runnable with `dart run` and
`dart compile exe` (AOT), which SC-006 is checked against.

## R6. Field type written forms

**Decision** (full table in the contract):

| Field type | Written form |
|---|---|
| `int`, `double` | JSON number (R3) |
| `bool` | `true` / `false` |
| `String` | JSON string |
| enum | the value's name as a string |
| `Vector2` | `[x, y]` |
| `Color` | `"#AARRGGBB"`, upper-case hex |
| asset reference | `{"asset": "assets/images/goblin.png"}` |
| entity reference | `{"ref": "<Node ID>"}` |

**Rationale:**

- **Colour as `#AARRGGBB`:** the same digit order as Flutter's `Color(0xAARRGGBB)` and Tiled's
  colour attributes, so developers can copy values across. Alpha is always present, so there is
  one form per colour.
- **Tagged asset references:** a bare string would be indistinguishable from a `String` field
  without the Manifest. Pyro rewrites asset paths across Scenes on rename (*Q27*), including
  inside Missing behaviors whose fields it no longer knows, so references must be recognisable
  from the file alone. This mirrors the `{"ref": …}` form already in §7.1.

**Alternatives considered:** `#RRGGBBAA` (CSS order, unfamiliar in Flutter); integer colours
(unreadable in diffs); bare-string asset paths (above).

## R7. Built-in Node properties

**Decision:** match Flame's components so no early `schemaVersion` bump (FR-020a) is needed
for basics:

- **transform** (entity, sprite, custom): `position`, `size`, `scale` (all `[x, y]`), `angle`
  (radians, as Flame stores it) and `anchor`.
- **anchor:** one of Flame's nine named anchors as a string (`"topLeft"`, `"center"`, …) or a
  custom `[x, y]`.
- **sprite `props`:** `image` (asset path) and an optional source region, `srcPosition` and
  `srcSize`, which are both present or both absent (absent means the whole image).
- **rectangle hitbox `props`:** `position`, `size`, `angle`, `anchor`, `collisionType`,
  `isSolid`.
- **circle hitbox `props`:** `position`, `radius`, `anchor`, `collisionType`, `isSolid`.
- **`collisionType`:** `"active"`, `"passive"` or `"inactive"`, Flame's `NodeCollisionType` names.

`angle`, `anchor` and `isSolid` on hitboxes go beyond the spec's minimum (FR-006). Adding them
later would be a new required key and therefore a version bump, and Flame's hitboxes already
have them.

## R8. Deterministic tree repair

**Decision:** repair in four passes, all in a fixed order so the same input always gives the
same tree (FR-022):

1. **Clean each list.** For every Node's `childIds`, in file order: drop IDs with no Node
   (*missing child*), the Node's own ID (*self child*), the root's ID (*root as child*) and
   repeats within the list (*duplicate child*).
2. **Walk from the root.** A depth-first, pre-order walk visits children in list order. A child
   already visited is removed from its current list (*multiple parents*; it stays with the
   first parent visited). This also breaks any cycle reachable from the root, which is
   therefore reported as *multiple parents*.
3. **Attach orphans.** Among unvisited Nodes, the *heads* are those that no other unvisited
   Node lists. Heads are appended to the root's `childIds` in ascending Node ID order (*orphan
   attached*), and each is walked as in step 2.
4. **Break cycles.** While Nodes remain unvisited, every one of them is listed by another, so
   they form cycles, possibly with Nodes hanging off them. Starting from the smallest
   remaining ID, follow listing parents (smallest first) until a Node repeats: that loop is a
   cycle. Its smallest ID is appended under the root, the walk from it removes the
   back-reference, and one *cycle broken* issue lists every Node the walk reached. (Attaching
   the smallest remaining ID directly fails when that Node only hangs off a cycle; found while
   implementing, fixture `damaged/cycle_with_tail`.)
   Removing the back-reference is part of that *cycle broken* issue (its
   `removedFromParentId`); no separate *multiple parents* issue is reported.

The walk is iterative (an explicit stack) so deep trees can't overflow the stack.

## R9. Where the work happens

**Decision:** decoding is synchronous and pure. Pyro calls it from `Isolate.run` when a file is
large (the Document model's choice, #2); the Runtime calls it during `PyroScene.load`, outside
any frame. Neither caller is part of this feature.

**Rationale:** 1,000 Nodes is budgeted at 100 ms, and that would drop frames if run on Pyro's UI
isolate (Principle III), so the API stays isolate-friendly: plain data in and out, no
callbacks.

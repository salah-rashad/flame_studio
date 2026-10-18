# Feature Specification: Scene Format

**Feature Branch**: `001-scene-format`

**Created**: 2026-10-18

**Status**: Draft

**Input**: User description: "Scene format in pyro_runtime: the Node model for the preview's Node
kinds (root, entity, sprite, rectangle and circle hitboxes, custom), JSON with sorted keys,
Overrides only (ADR 0003), childIds-only persistence with orphan and double-parent repair (Q47),
and schemaVersion with refusal of newer files"

## Overview

A Scene file is the contract between Pyro (which edits it) and the developer's game (which loads
it through the Runtime). This feature defines that contract for the early preview: what a Scene
holds, how it is written so that diffs and merges stay readable, how it survives damage from a
merge, and how a reader protects itself from files it is too old to understand.

It is the first piece of Phase 2 (project-plan §7.1, §7.4; phases.md "Scene format"). The
Document model (#2) and the Runtime loader (#8) both build on it, and neither is part of this
feature.

**Who uses it**

- **Game developer**: commits Scene files to git, reviews their diffs, resolves merge conflicts in
  them, and ships them inside the game.
- **Pyro** (the editor): reads a Scene to edit it and writes it on save.
- **The Runtime in a game**: reads a Scene to build it in Flame.

## Clarifications

### Session 2026-10-18

- Q: Should built-in Node properties always be written in full, or only when changed from their
  default like Behavior fields? → A: Always in full; Behavior and Custom component fields stay
  Overrides-only.
- Q: When a game loads a Scene whose Node tree was damaged by a merge, should it repair and keep
  running or stop with an error? → A: Repair in every build; debug builds also print a prominent
  warning listing every repair and suggesting the Scene be opened in Pyro and saved.
- Q: When a later release adds a new Node kind or Field type, should `schemaVersion` go up?
  → A: Yes; any new Node kind, Field type or required key bumps it, so older readers refuse the
  file.
- Q: Where should an orphan Node (listed by no parent) go when a Scene is read? → A: Appended
  under the root, after its existing children, in ascending Node ID order.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save and reopen a Scene without any change (Priority: P1)

A developer builds a Scene with every early-preview Node kind: the root, Entities with
Behaviors, sprites, rectangle and circle hitboxes, and Custom components. They save it, close
it, reopen it and save again. The file on disk is byte-for-byte the same, and `git diff` shows
nothing. When they change one value, the diff touches only the lines of that value.

**Why this priority**: every other part of Pyro (editing, Play, Hot-swap, the contract test)
depends on reading and writing Scenes faithfully. Without it there is no product.

**Independent Test**: read each fixture Scene, write it back, and compare bytes; change one field
and check the diff is confined to that Node's block.

**Acceptance Scenarios**:

1. **Given** a Scene file in canonical form containing every early-preview Node kind, **When** it
   is read and written back, **Then** the output is byte-identical to the input.
2. **Given** a valid Scene file that is not in canonical form (keys out of order, different
   indentation, a missing trailing newline), **When** it is read and written, **Then** the output
   is in canonical form, and reading and writing that output again changes nothing.
3. **Given** a Scene, **When** the position of one Node changes and the Scene is written, **Then**
   only lines inside that Node's block differ from the previous file.
4. **Given** a Scene with a Node holding a Field type or key this version doesn't recognise,
   **When** it is read and written, **Then** that data is written back unchanged.

---

### User Story 2 - Code defaults reach every Node without an Override (Priority: P1)

A developer has twenty enemies using a `Patrol` Behavior. Three of them have `speed` set in the
inspector; the rest use the default from code. The developer changes the default in code from 50
to 80. The seventeen enemies without an Override now patrol at 80; the three with an Override
keep their values, including one whose Override happens to be 50.

**Why this priority**: this is the decided storage rule (ADR 0003, *Q46*). Getting it wrong
silently changes game behavior, and it cannot be fixed later without migrating every Scene.

**Independent Test**: write a Scene with some fields set and some not; check the file contains
exactly the set fields, including one set to its default value.

**Acceptance Scenarios**:

1. **Given** a Behavior or Custom component with five Editable fields of which two have
   Overrides, **When** the Scene is written, **Then** the file holds exactly those two field
   values and nothing for the other three.
2. **Given** a field whose Override equals the current code default, **When** the Scene is
   written and read, **Then** the Override is still present.
3. **Given** a Node with an Override removed (*Reset to default*), **When** the Scene is written,
   **Then** the field no longer appears in the file.
4. **Given** an Override for a field that no longer exists in code, **When** the Scene is read
   and written, **Then** the value is kept in the file.

---

### User Story 3 - Refuse a Scene from a newer Pyro (Priority: P2)

A teammate on a newer Pyro saves a Scene with a newer `schemaVersion`. A developer on an older
Pyro, or a game built with an older Runtime, tries to open it. Instead of misreading it or
overwriting it with data loss, the reader refuses it with a message that names the file's version
and the newest version it supports.

**Why this priority**: required by the Data Integrity principle and *Q35/Q49*; less frequent than
stories 1 and 2, but the consequence of getting it wrong is lost work.

**Independent Test**: feed readers files with a newer, equal, missing and malformed
`schemaVersion` and check each outcome.

**Acceptance Scenarios**:

1. **Given** a file whose `schemaVersion` is newer than the reader supports, **When** it is read,
   **Then** reading fails with an error naming the file's version and the supported version, and
   no Scene is produced.
2. **Given** a file whose `schemaVersion` equals the current version, **When** it is read,
   **Then** it loads normally.
3. **Given** a file with no `schemaVersion`, or one that is not a positive whole number, **When**
   it is read, **Then** reading fails with an error saying the version is missing or invalid.
4. **Given** any Scene, **When** it is written, **Then** the file carries the current
   `schemaVersion` as its first key.

---

### User Story 4 - Open a Scene damaged by a git merge (Priority: P2)

Two developers edit the same Scene on different branches: one moves a Node under a new parent,
the other deletes that parent. After the merge, git reports no conflict, but the file now lists a
Node under two parents, lists a child that no longer exists, and contains a Node no parent lists.
The developer opens it. The Scene loads, every Node and its data is still there, and a report says
exactly what was repaired and where each affected Node ended up.

**Why this priority**: persisting only `childIds` (*Q47*) was chosen to make merges safe;
without repair, a clean merge could still produce an unloadable Scene. It is P2 because it only
affects damaged files.

**Independent Test**: load hand-made fixtures, one per inconsistency, and compare the repaired
tree and the report with expected results.

**Acceptance Scenarios**:

1. **Given** a Node that exists in the file but is listed by no parent (an orphan), **When** the
   Scene is read, **Then** the Node is placed under the root, after the root's existing children
   (several orphans in ascending Node ID order), and the report names it.
2. **Given** a Node listed under two parents, **When** the Scene is read, **Then** it stays under
   the first parent reached in a depth-first walk from the root, is removed from the other, and
   the report names both parents.
3. **Given** a parent that lists a child ID with no matching Node, **When** the Scene is read,
   **Then** that ID is dropped from the list and reported.
4. **Given** a parent that lists the same child twice, **When** the Scene is read, **Then** the
   first occurrence is kept and the duplicate reported.
5. **Given** a group of Nodes that list each other in a cycle and are unreachable from the root,
   **When** the Scene is read, **Then** the cycle is broken, the group is placed under the root
   as for orphans, and the report names the Nodes involved.
6. **Given** a file with no inconsistencies, **When** it is read, **Then** the report is empty.
7. **Given** any repair, **When** the repaired Scene is compared with the file, **Then** no Node
   and no Node data has been removed; only `childIds` lists have changed.
8. **Given** a damaged Scene loaded by a game in a debug build, **When** it loads, **Then** the
   game keeps running and prints one warning listing every repair and advising the developer to
   open and save the Scene in Pyro; in a release build it loads with no output.

---

### Edge Cases

- **Root only:** a Scene holding just the root Node reads and writes correctly.
- **Missing or wrong root:** `rootId` names no Node, or names a Node whose kind isn't root, or a
  second Node has kind root. Reading fails with an error naming the problem; Pyro never invents a
  root.
- **Root listed as a child:** it is removed from that list and reported.
- **A Node listing itself as a child:** the entry is dropped and reported.
- **Malformed JSON:** reading fails with an error that gives the position of the problem.
- **Duplicate keys in a JSON object** (possible after a bad merge): reading fails with an error
  naming the key, rather than silently keeping one value.
- **Unknown Node kind at a supported `schemaVersion`** (only possible through a hand edit or a
  tool bug, FR-020a): the Node is kept with all its data, written back unchanged; what a
  game does with a Node it can't build is decided by the Runtime loader (#8). A real new kind, such as prefab instances
  in v0.2, arrives with a higher `schemaVersion` and is refused by older readers.
- **Custom component Node without a Type ID:** reading fails, naming the Node.
- **Entity reference to a Node that doesn't exist:** the reference is kept as written; resolving
  it is the loader's and the inspector's job (§11 "missing reference").
- **Numbers:** a whole number written as `80` and as `80.0` must have one canonical written form,
  so re-saving never flips between them.
- **Text:** Node names and string fields containing quotes, emoji, non-Latin scripts and line
  breaks round-trip exactly.
- **Line endings:** a file checked out with CRLF line endings reads correctly; written files use
  LF.

## Requirements *(mandatory)*

### Functional Requirements

**Scene and Node model**

- **FR-001**: A Scene MUST consist of a `schemaVersion`, a `rootId` and a map of Nodes keyed by a
  stable, unique Node ID that does not change when a Node is renamed, moved or edited.
- **FR-002**: The model MUST support these Node kinds: **root**, **entity**, **sprite**,
  **rectangle hitbox**, **circle hitbox** and **custom** (a Custom component named by its Type
  ID).
- **FR-003**: Every Node except the root MAY carry a Node name (not required to be unique) and a
  list of tags.
- **FR-004**: Entity, sprite and custom Nodes MUST carry a transform: position, size, scale,
  angle and anchor.
- **FR-005**: Sprite Nodes MUST reference their image by asset path (project-root-relative, the
  same key the game declares) and MAY name a source region of that image.
- **FR-006**: Hitbox Nodes MUST carry their shape's geometry relative to their parent (rectangle:
  position, size, angle and anchor; circle: position, radius and anchor), a collision type
  (active, passive or inactive), and whether the hitbox is solid.
- **FR-007**: Entity and custom Nodes MUST be able to carry an ordered list of attached
  Behaviors, each named by its Type ID with its own Overrides.
- **FR-008**: Each Node's children MUST be an ordered list of Node IDs; the parent of a Node MUST
  be derived from these lists and MUST NOT be stored.

**Overrides (ADR 0003)**

- **FR-009**: For Behaviors and Custom components, the Scene MUST store a field value only when
  it is an Override, and MUST store it even when it equals the current code default.
- **FR-010**: Removing an Override MUST remove the field from the written Scene.
- **FR-011**: Override values MUST be stored by field name and MUST be kept even when the reader
  has no knowledge of that field or its type.
- **FR-012**: Each Field type supported in v1 MUST have exactly one written form: whole and
  decimal numbers, booleans, text, enum values (by name), vectors (two numbers), colours,
  asset references (asset path) and entity references (the target's Node ID).
- **FR-013**: Built-in Node properties (transform, sprite and hitbox properties) MUST always be
  written in full, including values equal to their defaults, because those defaults come from
  Pyro and Flame rather than from the developer's code; a change to a Flame or Pyro default MUST
  NOT change any existing Scene.

**Writing**

- **FR-014**: Written Scenes MUST be deterministic: the same Scene always produces the same
  bytes, with no timestamps or other varying content.
- **FR-015**: Written Scenes MUST be pretty-printed with LF line endings and a trailing newline.
  The top level MUST be written in the fixed order `schemaVersion`, `rootId`, `nodes` (*Q14*
  puts the version at the top); every other object's keys, including the Node IDs in `nodes`,
  MUST be sorted. Each Node is one block, so a one-value edit produces a one-line diff where the
  value fits on one line.
- **FR-016**: Reading and then writing a Scene in canonical form MUST reproduce it byte for byte;
  for any valid Scene, writing is idempotent (write → read → write produces the same bytes).
- **FR-017**: Any key, value or Node kind the reader doesn't recognise at a supported
  `schemaVersion` MUST be preserved and written back unchanged.

**Versioning**

- **FR-018**: Every written Scene MUST carry the current `schemaVersion` (1 for this feature).
- **FR-019**: A reader MUST refuse a Scene whose `schemaVersion` is newer than it supports, with
  an error naming the file's version and the supported version, and MUST produce no Scene.
- **FR-020**: A reader MUST refuse a Scene whose `schemaVersion` is missing or not a positive
  whole number.
- **FR-020a**: Any later change that adds a Node kind, a Field type or a required key, or changes
  the meaning of existing data, MUST increase `schemaVersion`. Readers therefore meet unknown
  Node kinds or keys at a supported version only through hand edits or tool bugs, and FR-017's
  preservation is a safety net, not a compatibility mechanism.

**Tree repair (*Q47*)**

- **FR-021**: Reading MUST detect and repair these inconsistencies: orphan Nodes, Nodes listed
  under more than one parent, child IDs with no matching Node, duplicate child IDs in one list,
  Nodes listing themselves, the root listed as a child, and cycles unreachable from the root.
- **FR-022**: Repairs MUST follow the deterministic rules in User Story 4, so the same damaged
  file always repairs to the same tree.
- **FR-023**: Repairs MUST change only `childIds` lists; no Node and no Node data may be
  removed.
- **FR-024**: Reading MUST return a report listing every repair with the affected Node IDs, so
  Pyro can show it to the developer.
- **FR-024a**: A game MUST load a repaired Scene in every build rather than stop. In debug
  builds the Runtime MUST print one prominent warning per Scene listing every repair and telling
  the developer to open the Scene in Pyro and save it; release builds MUST repair without
  output.
- **FR-025**: A repaired Scene MUST NOT be written back to disk by the reading step itself;
  writing happens only when a consumer (for example the developer saving in Pyro) chooses to.

**Errors**

- **FR-026**: Every error MUST name what failed and where: the Node ID and, when known, the Node
  name, Type ID or key involved.

### Key Entities

- **Scene**: one file; its `schemaVersion`, its root's Node ID and all of its Nodes.
- **Node**: one element of the tree; its ID, Node kind, optional name and tags, ordered child
  IDs and kind-specific data.
- **Node kind**: root, entity, sprite, rectangle hitbox, circle hitbox or custom; unknown kinds
  are kept as opaque Nodes.
- **Transform**: position, size, scale, angle and anchor of a positioned Node.
- **Behavior attachment**: a Type ID plus its Overrides, attached to an entity or custom Node.
- **Override**: a field name and a value in one of the Field type written forms.
- **Entity reference**: a value pointing at another Node of the same Scene by Node ID.
- **Asset reference**: a project-root-relative asset path.
- **Repair report**: the list of inconsistencies found and fixed while reading, each with the
  Node IDs involved.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of canonical fixture Scenes (at least one per Node kind and one per Field
  type) are byte-identical after being read and written.
- **SC-002**: Re-saving an unchanged Scene produces a `git diff` of zero lines, every time.
- **SC-003**: Changing one value of one Node changes only lines inside that Node's block.
- **SC-004**: 100% of files with a newer, missing or invalid `schemaVersion` are refused, and no
  refused file is ever overwritten by the reader.
- **SC-005**: Every damage fixture (at least one per inconsistency in FR-021) loads with all of
  its Nodes present, the expected tree and a report naming every affected Node.
- **SC-006**: The median time to read, and separately to write, a 1,000-Node Scene is under
  100 ms on the reference Mac, so opening and saving feel instant and a Hot-swap stays well inside its one-second budget.

## Assumptions

- **Scope** is the early preview's Node kinds only. Prefab instances (v0.2), the polygon hitbox,
  animated sprites (v0.1.1) and Tiled maps (v0.2) are out of scope; they will arrive with a
  higher `schemaVersion` (FR-020a).
- **Only `schemaVersion` 1 exists.** The migrations framework is deferred (phases.md, #2), so
  this feature only refuses newer versions and doesn't migrate older ones.
- **Repair is automatic in both Pyro and games** (FR-024a). Pyro shows the report and saves the
  repair only when the developer saves (the Document model's job, #2).
- **Node IDs** are UUIDs (*Q14*); the reader accepts any non-empty string as an ID so
  hand-written test fixtures stay readable.
- **Colours** are written as an 8-digit hexadecimal string including alpha; the exact
  spelling of every Field type's written form is settled in the plan.
- **Out of this feature:** reading and writing files on disk (atomic save belongs to the Document
  model, #2), building Scenes in Flame, resolving entity and asset references, Type ID checks
  against the Registry (all the Runtime loader, #8), and the Document model's undo and history.
- **Dependencies:** none beyond what `pyro_runtime` already depends on; the format is shared by
  Pyro and games through that package (project-plan §5).

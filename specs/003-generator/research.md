# Research: Generator

Phase 0 of [plan.md](plan.md). Each entry is a decision the plan relies on, why it was made, and
what else was considered. Spike #2 (`spikes/02_generator/`, ARCHITECTURE.md "Spike #2") proved
the builder shape on 2026-10-16; its findings are cited as "spike #2" and reused where they hold.
Facts marked *verified* were checked on 2026-10-20 in this repository with Flutter 3.44.2 /
Dart 3.12.2 (resolution with `dart pub add --dry-run`, a throwaway `build_test` probe in
`packages/pyro_generator/test/`, removed afterwards).

## R1. Toolchain and dependencies

**Decision:** stay on the repository's Flutter 3.44.2 pin (Q94). The workspace lock holds
analyzer 12.1.0, build 4.0.7, source_gen 4.2.4, dart_style 3.1.8, build_config 1.3.3 and
build_runner 2.15.1; `pyro_generator` keeps its wide ranges (spike #2 finding 1).

| Package | Where | Version | Kind |
|---|---|---|---|
| `glob` | `pyro_generator` | ^2.1.0 (resolves 2.2.0) | dependency (already transitive through `build`; imported directly by the aggregator) |
| `build_test` | `pyro_generator` | ^3.5.0 (resolves 3.5.16) | dev dependency |
| `pyro_runtime`, `flame`, `flame_behaviors` | `fixture_game` | workspace / lock | dependencies |
| `pyro_generator`, `build_runner` ^2.15.1, `flutter_test` | `fixture_game` | workspace / lock | dev dependencies |

`pyro_annotations` keeps no dependencies; `pyro_runtime` gains none.

**Rationale:** *verified*: `build_test` 3.5.16 is the newest that resolves next to analyzer 12
and build 4.0.7; it adds only `html` and `csslib` (test-only). Nothing here needs analyzer ≥ 13.

**Alternatives considered:** `code_builder` for the Registry (another dependency in every
user's project for one small file; string templates plus `dart_style` are what spike #2 used and
are easy to golden-test); moving to Flutter 3.47 first (a separate chore, Q94).

## R2. Builder shape: a per-library scan and a `$lib$` aggregator

**Decision:** two builders in `packages/pyro_generator/build.yaml`, both
`auto_apply: dependents`, so a game that depends on `pyro_generator` needs no `build.yaml`
(FR-027):

| Builder | Input → output | `build_to` | Notes |
|---|---|---|---|
| `pyro_generator:pyro_scan` | `.dart` → `.pyro.json` (one fragment per library, written only when the library holds something to report) | cache | `run_only_if_triggered: true`; triggers `annotation PyroBehavior`, `annotation PyroComponent`, `annotation Editable` |
| `pyro_generator:pyro_aggregate` | `$lib$` → `lib/pyro.g.dart`, `lib/pyro.manifest.json` | source | `required_inputs: [".pyro.json"]`; reads `findAssets(Glob('lib/**.pyro.json'))` |

The scan does everything that needs the analyzer (classification, rules, defaults, imports) and
writes plain JSON; the aggregator only merges, applies the cross-library rules (Type ID
collisions, `@Editable` holders no annotated type uses), sorts and writes. The `Editable`
trigger is new compared with spike #2: a library whose only Pyro annotation is `@Editable` must
still be scanned so FR-014a can see it.

**Rationale:** spike #2 measured this shape at ~0.9 s per save on 300- and 1000-file Flame
projects, with both outputs written only when their content changes (findings 2–4). Keeping the
analyzer out of the aggregator keeps it cheap and its output a pure function of the fragments.

**Alternatives considered:** one `$lib$` builder that resolves every library itself (no
incremental reuse per file; every save would re-analyze the package); source_gen's
`SharedPartBuilder` + `CombiningBuilder` (writes per-library `.g.dart` parts, not one Registry
and one Manifest, Q68).

## R3. Recognising Pyro's and Flame's types without depending on Flame

**Decision:** `source_gen` `TypeChecker`s, matched by declaration, never by spelling in the
user's file (FR-005):

| Type | Checker |
|---|---|
| `PyroBehavior`, `PyroComponent`, `Editable`, `ImagePath` | `TypeChecker.typeNamed(X, inPackage: 'pyro_annotations')` (the generator imports the annotations, so a rename is a compile error) |
| `Component`, `PositionComponent`, `Sprite`, `SpriteAnimation` | `TypeChecker.typeNamedLiterally(name, inPackage: 'flame')` |
| `Behavior`, `EntityMixin` | `TypeChecker.typeNamedLiterally(name, inPackage: 'flame_behaviors')` |
| `Vector2` | `TypeChecker.fromUrl('package:vector_math/vector_math.dart#Vector2')` (the class is a `part` of that library) |
| `Color` | `TypeChecker.fromUrl('dart:ui#Color')` |

**Rationale:**

- `pyro_generator` must not depend on Flame or Flutter (constitution II), so Flame's types are
  matched by package and name. *Verified:* `Component` (`lib/src/components/core/component.dart`),
  `PositionComponent`, `Sprite`, `SpriteAnimation` are declared in `flame` 1.38.2; `Behavior<Parent
  extends EntityMixin>` and `mixin EntityMixin on Component` in `flame_behaviors` 1.4.0.
- `vector_math` declares **two** `Vector2` classes, in part files of `vector_math.dart` and
  `vector_math_64.dart` (*verified* while implementing: matching the part file's path matched
  nothing, since an element's library is the library, not the part); Flame imports `package:vector_math/vector_math.dart` everywhere
  (*verified*), i.e. the 32-bit one. Matching by name would accept a `vector_math_64` field the
  Runtime can't assign a Flame `Vector2` to, so `Vector2` is matched by URL and a
  `vector_math_64` field is an unsupported Field type with a hint.
- Annotations re-exported through `pyro_runtime` (Q44) or imported with a prefix are still
  their `pyro_annotations` declarations, so they match. Triggers match the annotation's name
  only (spike #2 finding 3); a renamed re-export loses the cheap skip, not correctness.

**Alternatives considered:** `fromUrl` for every Flame type (breaks whenever Flame moves a file
inside `src/`; package + name is stable across Flame 1.x); `isAssignableFrom` on a type loaded
from Flame (needs Flame resolved in the generator's own tests and on the plain VM).

## R4. Class-level rules and what each records

**Decision:** for each class annotated `@PyroBehavior` or `@PyroComponent` in a library under
`lib/` (FR-005 to FR-009):

| Check | Error code (contracts/manifest-v1.md) |
|---|---|
| Both annotations on one class | `bothAnnotations` |
| Private class | `privateClass` |
| Abstract or `sealed` class | `abstractClass` |
| Generic class (any type parameter) | `genericClass` |
| No unnamed constructor, or one with a required parameter (optional ones allowed) | `badConstructor` |
| `@PyroComponent` not a `PositionComponent` | `notPositionComponent` |
| `@PyroBehavior` not a `Behavior` | `notBehavior` |
| Explicit `id:` empty or containing whitespace | `badTypeId` |
| Behavior's parent type is a mixin or interface-only type, not a class | `parentTypeNotClass` |
| `pyro_runtime`'s library can't be read from the package (`BuildStep.canRead`; checked once, by the aggregator) | `missingRuntime` |

Recorded per type: Type ID, role, label (class name by default), category, doc comment (`///`
markers stripped, lines joined with `\n`, trimmed), `source` (package-relative path of the
declaring file, `/`-separated), supertypes, `acceptsBehaviors` and `preview` for components,
`parentType` for Behaviors, fields.

- **Supertypes (FR-017):** the superclass chain from the nearest superclass to `Component`
  (components) or `Behavior` (Behaviors), skipping mixin applications; annotated classes by
  Type ID, others by class name. `acceptsBehaviors` is "the class is an `EntityMixin`".
- **Parent type:** the type argument of the `Behavior<T>` supertype. When it is `EntityMixin`
  (the bound, also what a raw `Behavior` instantiates to) the key is omitted: any Node that
  accepts Behaviors. A mixin or interface as `T` can't be matched against Pyro's class-chain
  supertypes, so it is an error rather than a Behavior Pyro would never offer.

**Rationale:** spike #2 checked only public/abstract/constructor and recorded `allSupertypes`
(14 entries for a `PositionedEntity`, finding 6). Every rule a scene can't survive without is an
error, so the Registry can always build what the Manifest lists.

**Alternatives considered:** listing every interface and mixin in `supertypes` (decided against
in the spec, FR-017); a warning for mixin parent types (the Behavior would exist in the
Registry but never be offered, which looks like a Pyro bug).

## R5. Field types, their checks and their values

**Decision:** an `@Editable` declaration is classified by its declared type (type aliases
resolved). Each Field type has one Manifest name, one Scene written form (Q91) and one Dart value
the Runtime passes to the Registry:

| Dart type | Manifest `type` | Scene written form | Value given to the setter |
|---|---|---|---|
| `int` | `int` | number | `int` |
| `double` | `double` | number | `double` |
| `bool` | `bool` | boolean | `bool` |
| `String` | `string` | string | `String` |
| an `enum` with ≥ 1 value | `enum` | value name | the enum value |
| `Vector2` (Flame's) | `vector2` | `[x, y]` | `Vector2` |
| `Color` | `color` | `"#AARRGGBB"` | `Color` |
| `ImagePath` | `imagePath` | `{"asset": path}` | `ImagePath` |
| `Sprite` | `sprite` | `{"asset": path}` | `Sprite` |
| `SpriteAnimation` | `spriteAnimation` | `{"asset": path}` | `SpriteAnimation` |
| `Component` or a subtype that isn't a `Behavior` | `entityRef` | `{"ref": Node ID}` | the Component |

Errors, all naming the class, the field and the declaring file (FR-010, FR-011, FR-011a):
`unsupportedFieldType` (anything else: `num`, `dynamic`, `Object`, records, functions,
collections, a type parameter, a Behavior type, `vector_math_64`'s `Vector2`, an enum with no
values), `fieldNotPublic`, `fieldFinal` (final or const), `fieldStatic`, `fieldNoDefault`
(non-nullable without an initializer, `late` included), `fieldMustBeNullable` (non-nullable
entity reference, `Sprite` or `SpriteAnimation`), `editableOnAccessor` (getter or setter),
`editableNotConcrete` (`abstract` or `external` field), `rangeOnNonNumeric`, `minAboveMax`.
Warning: `defaultOutOfRange`.

**Inherited fields (FR-013):** walk the class's linearization from the top: each superclass,
then the mixins applied to it in order, then the class itself; a field redeclared lower down
replaces the earlier entry in place of the subclass's declaration. Mixins are included because
in Dart they are part of the superclass chain, and Flame code puts shared state in mixins.

**Rationale:** the table is §6.1's v1 list (Q12) with the written forms already fixed by the
Scene format (Q91), so the Runtime (#8) converts written forms in one place and the Registry
never parses JSON. A Behavior is a `Component` but never a Node, so a reference to one could
never resolve.

**Alternatives considered:** substituting generic superclass fields' type parameters (rare, and
the setter would need the substituted type; unsupported for now); "late without initializer is
fine" (it throws on first read when a Scene has no Override).

## R6. Defaults

**Decision:** a field's default comes from its initializer's syntax (spike #2 approach,
extended):

| Initializer | Manifest `default` | `defaultSource` |
|---|---|---|
| none (nullable field) | `null` | absent |
| `null` | `null` | absent |
| integer, double, boolean or simple string literal, or `-` before a number literal | the value | absent |
| `Enum.value` (prefixed or not) of the field's enum | the value's name | absent |
| `ImagePath('…')` or `const ImagePath('…')` with a simple string literal | `{"asset": "…"}` | absent |
| anything else (`Vector2(1, 0)`, `const Color(0xFFFFFFFF)`, a constant's name, an expression) | `null` | the initializer's source text (`toSource()`) |

Defaults are given in the Scene written form (R5), so Pyro can compare an Override with its
default without knowing the Field type. Numbers follow the Scene format's canonical rule (Q92):
whole numbers without `.0`, others in their shortest round-trip form. `defaultOutOfRange` is
checked only against an evaluated numeric default.

**Rationale:** the analyzer can't compute a constant value for a non-`const` field, and the
inspector only needs real values for the editors it has (spike #2 finding 6). Writing defaults
in the written form keeps one representation of values across the Manifest and Scenes.

**Alternatives considered:** evaluating `const` constructor calls and references to `const`
variables through the analyzer (more cases, little gain before the inspector edits `Color`;
can come later without changing `manifestVersion`, since `defaultSource` stays); emitting Dart
default values in the Registry (the Runtime never needs defaults: no Override means the code
default stands).

## R7. Manifest file format

**Decision:** `lib/pyro.manifest.json`, specified in
[contracts/manifest-v1.md](contracts/manifest-v1.md): UTF-8, LF line endings, two-space
indentation, keys sorted at every level, a trailing newline; types sorted by Type ID, fields in
linearization order, enum values in declaration order, errors and warnings sorted by file, line,
code, Type ID and field. `manifestVersion` is `1` and changes only under FR-015a's rule.

**Rationale:** sorted keys make byte-identical output trivial to guarantee (FR-029) and match
the Scene format's habit; the order of arrays is the only order that carries meaning.

**Alternatives considered:** §7.3's example key order (`id` first) — readable, but it needs a
hand-maintained order per object and gains nothing for a generated file.

## R8. Errors and warnings

**Decision:** every diagnostic has a stable `code`, a `message` that says what is wrong and how
to fix it, the `file` (package-relative path, or a `package:` URI for a field inherited from
another package), the 1-based `line` of the declaration's name, and `typeId`, `className` and
`field` where they apply. The aggregator writes both outputs first, then logs each error with
`log.severe` (the build fails, spike #2 finding 4) and each warning with `log.warning`.

- A class with any error is left out of both outputs; all its errors are reported (FR-014).
- **Collisions** count every annotated class, valid or not: if `Patrol` in `a.dart` has an
  error and `Patrol` in `b.dart` is valid, both are left out and the collision is reported, so
  fixing the first error can never silently change which class a Scene's Type ID means.
- **Unused `@Editable` holders (FR-014a):** the scan lists every class or mixin with `@Editable`
  fields that isn't annotated, and every annotated class lists its linearization; the aggregator
  warns for holders that appear in no annotated class's linearization in the package.

**Rationale:** codes let tests and Pyro (#6) match diagnostics without parsing English, and the
fixed sort keeps error-carrying Manifests deterministic.

**Alternatives considered:** plain strings (spike #2; untestable without string matching and
can't be placed next to a type in Pyro).

## R9. The Registry contract lives in `pyro_runtime`

**Decision:** `pyro_runtime` gains `lib/src/loader/registry.dart`, exported from its library
([contracts/registry-api.md](contracts/registry-api.md)): `PyroRegistry` (types by Type ID),
`RegistryType` (Type ID, role, `create`), `RegistryField` (name, Field type, nullability, enum
values, `accepts`, `set`), and the enums `TypeRole` and `FieldType`. The generated
`lib/pyro.g.dart` declares one top-level `final pyroRegistry = PyroRegistry([...])`.

`accepts(value)` is generated as `value is T` (or `value == null || value is T`), so the Runtime
can report a wrong value with the Scene, Node and field instead of a bare `TypeError`. Enum
fields carry `values` (the enum's `values` list) so the Runtime can look a name up and report
an unknown one.

**Rationale:** the generated code has to implement something the game can compile against, and
#8 builds the loader on it; defining it here keeps the generator's output testable now. It uses
only `Object`, `Component` and Dart core types, so it adds no dependency.

**Alternatives considered:** generating the classes into `pyro.g.dart` itself (spike #2; every
game gets its own copy of the types and the Runtime can't name them); a `Map<String, Function>`
(untyped, and no room for the field descriptions FR-023 needs).

## R10. How the Registry names types

**Decision:** the Registry imports, with a prefix each (`i0`, `i1`, … in URI order):

1. `package:pyro_runtime/pyro_runtime.dart`;
2. the library declaring each annotated class (the user's own `lib/` file);
3. for each field type that isn't from `dart:core`, a library **the declaring class's own
   library imports** that exports the type: its imports are searched in source order through
   their export namespaces, and the first public one (no `/src/` segment in another package)
   wins. For a field inherited from a superclass, the superclass's library is searched.
   `dart:ui` is used for `Color` when it is imported directly.

If no import exports the type (only possible through an implicit `part` setup or a typedef
re-export the analyzer resolves differently), the scan reports `unreachableFieldType` on the
field instead of emitting an implementation import.

**Rationale:** spike #2 imported each type's declaring library, which produced
`package:flame/src/sprite_animation.dart` and `package:vector_math/vector_math.dart` (a package
the game doesn't depend on directly) and needed `ignore_for_file: implementation_imports`
(finding 6). The developer's file already compiles with its own imports, so one of them names
the type. Prefixing every import makes clashes between user types with the same name impossible
(FR-025).

**Alternatives considered:** assigning through `dynamic` to avoid naming field types (loses
`accepts` and enum `values`); always importing `package:flame/components.dart` and friends
(guesses at Flame's public surface and breaks when a game uses a different export).

## R11. Registry file layout and analysis

**Decision:** the file starts with `// GENERATED CODE - DO NOT MODIFY BY HAND.`, a line naming
`pyro_generator`, and `// ignore_for_file: type=lint` (lints only; analyzer warnings and errors
still apply). It is formatted with `dart_style`'s `DartFormatter` at
`DartFormatter.latestLanguageVersion` and the default page width. Types appear in Type ID order,
fields in Manifest order. With no types it holds only the runtime import and an empty registry,
so a game that calls the Runtime compiles (US1 #9).

The repository's `analysis_options.yaml` excludes `**/*.g.dart`, and an including file can't
undo that: *verified*, included `exclude` lists merge, so a fixture options file with its own
`exclude` still skips `pyro.g.dart`. A file named on the command line is analyzed even when
excluded (*verified*), so CI runs `flutter analyze --fatal-infos lib/pyro.g.dart` in the
fixture game (SC-005), and the fixture keeps the root's rules for parity.

**Rationale:** the format with `dart_style` is what spike #2 did and keeps the committed file
readable; `type=lint` is what freezed and json_serializable emit.

**Alternatives considered:** unformatted output (unreadable diffs in the developer's repository);
formatting at the package's language version (the `$lib$` step has no library to read it from;
the latest version formats older code the same way for this file's constructs).

## R12. Tests

**Decision:** three layers.

1. **`pyro_generator` unit and golden tests** with `build_test`'s `testBuilders` running both
   builders on in-memory packages: the fixture sources, stand-in `flame`, `flame_behaviors` and
   `vector_math` libraries that declare the matched classes at their real paths, and
   `pyro_annotations` read from its real `lib/` files. Each case under
   `test/goldens/<case>/` holds its sources in `input/lib/` and the expected
   `pyro.g.dart.golden`, `pyro.manifest.json.golden` and `log.golden` (the `.golden` suffix keeps
   them out of `dart format` and the analyzer), compared byte for byte; `PYRO_UPDATE_GOLDENS=1 dart test` rewrites them. Cases: the full success fixture, one
   per error and warning code, collisions (same class name, same explicit ID, erroneous plus
   valid), an empty package, inherited and mixin fields, and output stability (an unannotated
   edit and a body edit leave outputs unchanged; a tooltip edit changes only the Manifest).
2. **`fixture_game`** (a Flutter workspace member) with real Flame: one Custom component and
   Behavior per role and every Field type including `Color`, which can't be stubbed (`dart:ui`);
   its `lib/pyro.g.dart` and `lib/pyro.manifest.json` are committed. CI regenerates them on all
   three OSes and runs `git diff --exit-code` (US3, SC-003); `flutter analyze` checks the
   Registry (SC-005); `flutter test` creates every type by Type ID, sets every field through
   `accepts` and `set`, and checks the Manifest and the Registry list the same Type IDs and
   fields (SC-005, SC-006).
3. **`pyro_annotations`** tests: the annotations are `const`, `ImagePath` compares by path.

**Rationale:** *verified*: `testBuilder` resolves in-memory packages that aren't in the test's
package config (a stand-in `package:flame` class hierarchy and `package:vector_math` were
resolved and classified in under a second), so the generator's tests stay on the plain VM with
no Flame dependency (constitution II). `dart:ui` can't be supplied that way, which is why the
fixture game exists; it also proves the Registry compiles in a real game.

**Alternatives considered:** `loadIsolateSources()` (*verified*: in this workspace it loads the
whole workspace, real Flame included, ~20 s per test; and it would make the tests depend on
Flutter being resolvable); one real fixture package per error case (each `build_runner build`
costs ~15 s to compile builders).

## R13. Measuring watch latency (SC-004)

**Decision:** measured by hand once on the reference Mac with spike #2's harness: generate the
300-file / 42-annotated project with `bench/bin/gen_project.dart` changed to emit the real
`pyro_annotations` and `pyro_generator` (spikes are throwaway and may be edited), then
`bench/bin/measure.dart`. The result goes into ARCHITECTURE.md next to spike #2's table.

**Rationale:** the Generator's work per save is a little larger than the spike's (inherited
fields, import search, more rules), so the budget is re-checked rather than assumed; the
harness already exists and measures exactly the spec's scenario.

**Alternatives considered:** a CI benchmark (noisy shared runners, and the budget is defined on
the reference Mac).

## R14. Spec additions found while planning

The design makes five rules explicit that the spec implied but didn't state; they are added to
spec.md in the same change: a Behavior's parent type must be a class (R4, `parentTypeNotClass`);
a Behavior type is not an entity reference (R5); mixins' `@Editable` fields are inherited like
superclasses' (R5); a package that doesn't depend on `pyro_runtime` gets `missingRuntime` (R4),
since the Registry couldn't compile; and a field type no import of the declaring library
exports gets `unreachableFieldType` (R10) rather than an implementation import.

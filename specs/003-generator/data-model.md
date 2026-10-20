# Data Model: Generator

Phase 1 of [plan.md](plan.md). The Generator has no persistent state of its own: its inputs are
the developer's Dart libraries, its intermediate data is one JSON fragment per library in
build_runner's cache, and its outputs are the two committed files. This file describes those
shapes and the rules between them; the file formats are in [contracts/](contracts/).

## Inputs

### Annotated class

A class in a library under `lib/` carrying `@PyroBehavior` or `@PyroComponent`
([contracts/annotations-api.md](contracts/annotations-api.md)).

| Attribute | From | Rule |
|---|---|---|
| Type ID | annotation `id`, else class name | non-empty, no whitespace (`badTypeId`); unique per package (`duplicateTypeId`) |
| Role | which annotation | not both (`bothAnnotations`) |
| Instantiable | class declaration | public, not abstract or sealed, no type parameters, unnamed constructor callable with no arguments (`privateClass`, `abstractClass`, `genericClass`, `badConstructor`) |
| Base type | supertypes | component → `PositionComponent` (`notPositionComponent`); Behavior → `Behavior` (`notBehavior`) |
| Parent type | `T` of `Behavior<T>` | a class; `EntityMixin` means none (`parentTypeNotClass`) |
| Linearization | superclasses and their mixins, top-down, then the class | source of inherited fields and of "used" `@Editable` holders |

### Editable field

A field annotated `@Editable` in an annotated class or anywhere in its linearization.

| Attribute | Rule |
|---|---|
| Declaration | public, instance, non-final, non-const, concrete, not a getter or setter (`fieldNotPublic`, `fieldStatic`, `fieldFinal`, `editableNotConcrete`, `editableOnAccessor`) |
| Field type | one of the v1 Field types (research R5; `unsupportedFieldType`), with a public name (`privateFieldType`), importable through the declaring library's imports (`unreachableFieldType`) |
| Nullability | entity reference, `Sprite`, `SpriteAnimation` must be nullable (`fieldMustBeNullable`); any non-nullable field needs an initializer (`fieldNoDefault`) |
| Range | `min`/`max` only on `int`/`double` (`rangeOnNonNumeric`); `min ≤ max` (`minAboveMax`); evaluated default within range, else a warning (`defaultOutOfRange`) |
| Default | evaluated or source text (research R6) |
| Shadowing | a redeclaration lower in the linearization replaces the earlier one |

### `@Editable` holder

A class or mixin in the package with `@Editable` fields and no Pyro annotation. If no annotated
class's linearization contains it, it produces `unusedEditable` (FR-014a).

## Intermediate: scan fragment (`lib/**.pyro.json`, build cache only)

One per library that has an annotated class or an `@Editable` holder; none otherwise. Internal
to `pyro_generator` (its format can change in any release, since the cache is rebuilt when the
generator changes).

```text
ScanFragment
├── types: [TypeRecord]          # every annotated class in the library, valid or not
├── holders: [ClassKey]          # @Editable holders declared in this library
└── diagnostics: [Diagnostic]    # errors and warnings found by the scan

TypeRecord
├── key: ClassKey                # library URI + class name
├── typeId: String
├── valid: bool                  # false if any error names this class
├── linearization: [ClassKey]    # for FR-014a
├── manifest: ManifestType       # the Manifest entry (contracts/manifest-v1.md), if valid
└── registry: RegistryEntry      # what the Registry emitter needs, if valid

RegistryEntry
├── classImport: String          # URI of the declaring library
├── className: String
├── role: behavior | component
└── fields: [RegistryFieldEntry]

RegistryFieldEntry
├── name, fieldType, nullable
├── typeImport: String?          # URI that exports the field's type (research R10); null for dart:core
├── typeName: String             # e.g. Vector2, PatrolMode, Player
└── ownerImport, ownerName       # class whose instance the setter casts to (the annotated class)
```

`ClassKey` identifies a class across libraries without its Type ID, so collisions and holder use
can be decided before Type IDs are known to be unique.

## Aggregation

The aggregator reads every fragment (sorted by path) and:

1. Groups `TypeRecord`s by Type ID. Any group of two or more → one `duplicateTypeId` error
   listing every class in `related`; all of them are dropped.
2. Drops every record with `valid: false` (its errors are already in the fragment).
3. Collects every `ClassKey` in any record's linearization; each holder not in that set →
   `unusedEditable` warning.
4. Checks `package:pyro_runtime/pyro_runtime.dart` can be read → else `missingRuntime`.
5. Sorts types by Type ID and diagnostics by `file`, `line`, `code`, `typeId`, `field`.
6. Writes `lib/pyro.manifest.json` and `lib/pyro.g.dart` (build_runner skips the write when the
   bytes are unchanged), then logs errors (`log.severe`) and warnings (`log.warning`).

## State over a watch session

```text
            save with errors                     save fixing them
  [clean] ───────────────────────▶ [failing] ───────────────────────▶ [clean]
     ▲  │                            │   ▲
     │  │ save with only warnings    │   │ save, still broken / no-op rebuild:
     │  ▼                            └───┘ same errors written and logged again
  [warned]
```

- **clean:** `errors` and `warnings` empty; build succeeds.
- **warned:** `warnings` non-empty; build succeeds; every type still in both outputs.
- **failing:** `errors` non-empty; both files written with the valid types; build_runner reports
  failure and the watch keeps running (spike #2 finding 4).

## Outputs

| File | Contract | Consumer |
|---|---|---|
| `lib/pyro.manifest.json` | [contracts/manifest-v1.md](contracts/manifest-v1.md) | Pyro (#6, #9, #11) |
| `lib/pyro.g.dart` | [contracts/registry-api.md](contracts/registry-api.md) | the game, through `PyroScene.load` (#8) |

Invariant across both (SC-006): the same Type IDs, and for each type the same field names in the
same order.

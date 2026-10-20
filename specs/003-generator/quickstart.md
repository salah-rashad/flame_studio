# Quickstart: Validating the Generator

How to check that the feature works. The behavior is in [spec.md](spec.md), the shapes in
[data-model.md](data-model.md) and the formats in [contracts/](contracts/).

## Prerequisites

- Flutter 3.44.2 on `PATH` (the repository's pin, Q94), and `flutter pub get` run once at the
  repository root.

## 1. Run the generator's tests

```bash
cd packages/pyro_generator && dart test
```

| Test file | Covers |
|---|---|
| `test/golden_test.dart` | Each case under `test/goldens/<case>/` runs both builders on its in-memory sources (`input/lib/`) and compares `pyro.g.dart.golden`, `pyro.manifest.json.golden` and `log.golden` byte for byte (SC-001): the full fixture (US1), one case per error and warning code (US2, SC-002), collisions (same name, same explicit ID, erroneous plus valid), an empty package (US1 #9) |
| `test/classify_test.dart` | Field type classification for every Dart type in research R5, including `vector_math_64` and Behavior types rejected |
| `test/defaults_test.dart` | Every initializer form in research R6, number formatting, `defaultOutOfRange` |
| `test/linearization_test.dart` | Inherited and mixin fields, shadowing, `unusedEditable` (FR-013, FR-014a) |
| `test/imports_test.dart` | Field types imported through the declaring library's own imports; same-named types in two libraries; `unreachableFieldType` (FR-025) |
| `test/manifest_json_test.dart`, `test/diagnostics_test.dart` | Canonical JSON (sorted keys, number form) and diagnostic codes, fields and sort order |
| `test/failure_test.dart` | Outputs written before a failing build reports failure; the same errors on a rebuild; recovery after a fix (US2 #7, #9) |
| `test/triggers_test.dart` | `build.yaml` builders, auto-apply and triggers; no fragment for unannotated libraries (FR-027, FR-028) |
| `test/stability_test.dart` | Unannotated edit and body edit leave both outputs unchanged; tooltip edit changes only the Manifest; outputs independent of file order (US3 #3–#5) |

After an intended output change, regenerate the goldens and review the diff:

```bash
cd packages/pyro_generator && PYRO_UPDATE_GOLDENS=1 dart test test/golden_test.dart && git diff test/goldens
```

## 2. Run the generator on a real game

`packages/pyro_generator/fixture_game` is a small Flutter package with every Field type,
including `Color`, and real Flame.

```bash
cd packages/pyro_generator/fixture_game
dart run build_runner build -d
git diff --exit-code lib/pyro.g.dart lib/pyro.manifest.json   # nothing changed (US3 #1, #6)
flutter analyze --fatal-infos lib/pyro.g.dart                   # Registry analyzes clean (SC-005; named, since **/*.g.dart is excluded)
flutter test                                                    # every type created, every field set; Registry and Manifest agree (SC-005, SC-006)
```

CI runs the same four commands on macOS, Windows and Linux (SC-003).

## 3. See an error the way a developer would

In `fixture_game`, give a field an unsupported type and build:

```bash
cd packages/pyro_generator/fixture_game
# e.g. add `@Editable() Map<String, int> loot = {};` to lib/behaviors/patrol.dart
dart run build_runner build -d   # fails; the log names the file, class, field and type
jq '.errors' lib/pyro.manifest.json   # the same error, with code "unsupportedFieldType"
git checkout lib                 # undo
```

Expected: the build fails, `Patrol` is missing from both files, and every other type is still
there (US2 #3, #7). Building again after the revert restores both files byte for byte (US2 #9).

## 4. Watch latency (SC-004, by hand on the reference Mac)

With spike #2's harness, changed to emit the real annotations (research R13):

```bash
cd spikes/02_generator/bench
dart run bin/gen_project.dart --out ../sample --files 300 --annotated 42
cd ../sample && flutter pub get && dart run build_runner build && cd ../bench
dart run bin/measure.dart --project ../sample --runs 5
```

Pass: the median "Manifest updated" time for an annotated save is under 3 s (spike #2 measured
~0.9 s). Record the table in ARCHITECTURE.md.

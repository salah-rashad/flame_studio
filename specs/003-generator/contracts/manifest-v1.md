# Contract: Manifest, `manifestVersion` 1

The file `lib/pyro.manifest.json` that `pyro_generator` writes into the game and Pyro reads
(#6). It is committed, so its bytes are part of the contract (FR-015 to FR-020, FR-029, FR-030).

## File form

- UTF-8, LF line endings, two-space indentation, a trailing newline.
- Object keys sorted (code-unit order) at every level; absent optional keys are omitted, not
  written as `null`, except `default`, which is always present.
- Numbers as in Scene files (Q92): whole numbers without `.0`, others in their shortest
  round-trip form.
- No timestamps, absolute paths, user names or machine-dependent content. Paths use `/`.

## Top level

| Key | Type | Meaning |
|---|---|---|
| `manifestVersion` | integer | `1`. Goes up only for a change an older reader would misread (FR-015a). |
| `types` | array of Type | Every valid annotated type, sorted by `id`. |
| `errors` | array of Diagnostic | Every error, sorted (below). Non-empty means the build failed. |
| `warnings` | array of Diagnostic | Every warning, sorted (below). The build still succeeded. |

Readers MUST ignore keys they don't know.

## Type

| Key | Type | Presence | Meaning |
|---|---|---|---|
| `id` | string | always | Type ID: the explicit `id:` or the class name. |
| `role` | `"behavior"` \| `"component"` | always | |
| `label` | string | always | The annotation's `label`, or the class name. |
| `category` | string | if given | |
| `doc` | string | if the class has a doc comment | `///` markers stripped, lines joined with `\n`, trimmed. |
| `source` | string | always | Package-relative path of the declaring file, e.g. `lib/behaviors/patrol.dart`. |
| `supertypes` | array of string | always | Superclass chain, nearest first, to `Component` or `Behavior`; annotated classes by Type ID, others by class name. |
| `parentType` | string | Behaviors, unless any entity will do | Type ID or class name of `T` in `Behavior<T>`. |
| `acceptsBehaviors` | boolean | components | Whether the class is an `EntityMixin`. |
| `preview` | string | components, if given | Project-root-relative image path. |
| `fields` | array of Field | always | Superclass and mixin fields first, then the class's, in declaration order. |

## Field

| Key | Type | Presence | Meaning |
|---|---|---|---|
| `name` | string | always | |
| `type` | string | always | One of `int`, `double`, `bool`, `string`, `enum`, `vector2`, `color`, `imagePath`, `sprite`, `spriteAnimation`, `entityRef`. |
| `nullable` | boolean | always | |
| `default` | JSON value | always | The evaluated default in its Scene written form (Q91), or `null` (research R6). |
| `defaultSource` | string | when the default isn't evaluated | The initializer's source text. |
| `label` | string | if given | |
| `tooltip` | string | if given | |
| `min`, `max` | number | if given (numeric fields only) | |
| `values` | array of string | `enum` | Value names in declaration order. |
| `refType` | string | `entityRef` | The referenced type: Type ID if annotated, class name otherwise. |
| `declaredIn` | string | inherited fields | Class name of the superclass or mixin that declares it. |

## Diagnostic (errors and warnings)

| Key | Type | Presence | Meaning |
|---|---|---|---|
| `code` | string | always | Stable code (table below). |
| `message` | string | always | What is wrong and how to fix it; names the class and field. |
| `file` | string | always | Package-relative path, or a `package:` URI for a declaration in another package. |
| `line` | integer | always | 1-based line of the declaration's name. |
| `typeId` | string | when a type is concerned | |
| `className` | string | when a class is concerned | |
| `field` | string | when a field is concerned | |
| `related` | array of `{file, line, className}` | `duplicateTypeId` | Every class sharing the Type ID. |

Sorted by `file`, `line`, `code`, `typeId`, `field`.

### Codes

| Code | Kind | When |
|---|---|---|
| `duplicateTypeId` | error | Two or more annotated classes share a Type ID; all are left out (FR-009). |
| `bothAnnotations` | error | A class has `@PyroBehavior` and `@PyroComponent`. |
| `privateClass` | error | Annotated class is private. |
| `abstractClass` | error | Annotated class is abstract or sealed. |
| `genericClass` | error | Annotated class has type parameters. |
| `badConstructor` | error | No unnamed constructor callable with no arguments. |
| `notPositionComponent` | error | `@PyroComponent` class doesn't extend `PositionComponent`. |
| `notBehavior` | error | `@PyroBehavior` class doesn't extend `Behavior`. |
| `badTypeId` | error | Explicit `id:` is empty or contains whitespace. |
| `parentTypeNotClass` | error | A Behavior's parent type is a mixin or interface-only type. |
| `missingRuntime` | error | The package doesn't depend on `pyro_runtime`. |
| `unsupportedFieldType` | error | `@Editable` field of a type outside the v1 Field types. |
| `privateFieldType` | error | `@Editable` field whose type has a private name, which the Registry can't write. |
| `unreachableFieldType` | error | No import of the declaring library exports the field's type. |
| `fieldNotPublic` | error | Private `@Editable` field. |
| `fieldFinal` | error | Final or const `@Editable` field. |
| `fieldStatic` | error | Static `@Editable` field. |
| `fieldNoDefault` | error | Non-nullable `@Editable` field with no initializer. |
| `fieldMustBeNullable` | error | Non-nullable entity reference, `Sprite` or `SpriteAnimation` field. |
| `editableOnAccessor` | error | `@Editable` on a getter or setter. |
| `editableNotConcrete` | error | `@Editable` on an abstract or external field. |
| `rangeOnNonNumeric` | error | `min` or `max` on a non-numeric field. |
| `minAboveMax` | error | `min` greater than `max`. |
| `defaultOutOfRange` | warning | Evaluated default outside `[min, max]`. |
| `unusedEditable` | warning | `@Editable` in a class or mixin no annotated class uses (FR-014a). |

## Example

```json
{
  "errors": [],
  "manifestVersion": 1,
  "types": [
    {
      "category": "Movement",
      "doc": "Walks between two points.",
      "fields": [
        {
          "default": 50,
          "max": 400,
          "min": 0,
          "name": "speed",
          "nullable": false,
          "tooltip": "Pixels per second",
          "type": "double"
        },
        {
          "default": null,
          "defaultSource": "Vector2(1, 0)",
          "name": "direction",
          "nullable": false,
          "type": "vector2"
        },
        {
          "default": "pingPong",
          "name": "mode",
          "nullable": false,
          "type": "enum",
          "values": [
            "pingPong",
            "loop"
          ]
        },
        {
          "default": null,
          "name": "target",
          "nullable": true,
          "refType": "Player",
          "type": "entityRef"
        }
      ],
      "id": "Patrol",
      "label": "Patrol",
      "parentType": "PositionedEntity",
      "role": "behavior",
      "source": "lib/behaviors/patrol.dart",
      "supertypes": [
        "Behavior"
      ]
    }
  ],
  "warnings": []
}
```

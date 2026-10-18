# Contract: Scene File, `schemaVersion` 1

The file format shared by Pyro and games (`*.scene.json`). Field-level meaning is in
[data-model.md](../data-model.md); the reasons for each rule are in
[research.md](../research.md). Once this ships, changing anything here that an older reader
would misread needs a new `schemaVersion` (FR-020a).

## Example

```json
{
  "schemaVersion": 1,
  "rootId": "0b5e",
  "nodes": {
    "0b5e": {
      "childIds": [
        "3f1c",
        "9b2e"
      ],
      "kind": "root"
    },
    "3f1c": {
      "behaviors": [
        {
          "fields": {
            "mode": "pingPong",
            "speed": 80,
            "target": {
              "ref": "9b2e"
            }
          },
          "type": "Patrol"
        }
      ],
      "childIds": [
        "a71d",
        "d220"
      ],
      "kind": "entity",
      "name": "goblin_1",
      "tags": [
        "enemy"
      ],
      "transform": {
        "anchor": "center",
        "angle": 0,
        "position": [320, 128],
        "scale": [1, 1],
        "size": [32, 32]
      }
    },
    "9b2e": {
      "fields": {
        "maxHealth": 5,
        "tint": "#FFFF8800"
      },
      "kind": "custom",
      "name": "player",
      "transform": {
        "anchor": "center",
        "angle": 0,
        "position": [64, 128],
        "scale": [1, 1],
        "size": [32, 48]
      },
      "type": "Player"
    },
    "a71d": {
      "kind": "rectangleHitbox",
      "name": "body",
      "props": {
        "anchor": "topLeft",
        "angle": 0,
        "collisionType": "active",
        "isSolid": false,
        "position": [4, 2],
        "size": [24, 30]
      }
    },
    "d220": {
      "kind": "sprite",
      "name": "sprite",
      "props": {
        "image": "assets/images/goblin_sheet.png",
        "srcPosition": [0, 0],
        "srcSize": [32, 32]
      },
      "transform": {
        "anchor": "topLeft",
        "angle": 0,
        "position": [0, 0],
        "scale": [1, 1],
        "size": [32, 32]
      }
    }
  }
}
```

Node IDs are shortened here; real ones are UUIDs.

## Top level

| Key | Type | Required |
|---|---|---|
| `schemaVersion` | positive integer | yes; `1` |
| `rootId` | Node ID | yes |
| `nodes` | object: Node ID → Node | yes |

Other top-level keys are preserved and written after these three, sorted.

## Nodes

Keys every Node may have:

| Key | Type | Notes |
|---|---|---|
| `kind` | string | required |
| `childIds` | array of Node IDs | omitted when empty |
| `name` | string | not on the root; omitted when absent |
| `tags` | array of strings | not on the root; omitted when empty |

Keys per kind (all required unless noted):

| `kind` | Keys |
|---|---|
| `root` | none |
| `entity` | `transform`; `behaviors` (omitted when empty) |
| `sprite` | `transform`; `props`: `image` (asset path), `srcPosition` + `srcSize` (both or neither) |
| `rectangleHitbox` | `props`: `position`, `size`, `angle`, `anchor`, `collisionType`, `isSolid` |
| `circleHitbox` | `props`: `position`, `radius`, `anchor`, `collisionType`, `isSolid` |
| `custom` | `type` (Type ID), `transform`; `fields`, `behaviors` (each omitted when empty) |

**`transform`:** `position`, `size`, `scale` (`[x, y]`), `angle` (radians), `anchor`. All
five are always written, defaults included (FR-013).

**`anchor`:** `"topLeft"`, `"topCenter"`, `"topRight"`, `"centerLeft"`, `"center"`,
`"centerRight"`, `"bottomLeft"`, `"bottomCenter"`, `"bottomRight"`, or `[x, y]`.

**`collisionType`:** `"active"`, `"passive"` or `"inactive"`.

**Behavior** (an element of `behaviors`): `type` (Type ID), `fields` (omitted when empty).

Unknown keys anywhere in a Node, a transform, `props` or a Behavior are preserved. A Node with
an unknown `kind` is preserved whole.

## Overrides (`fields`)

Only Overrides are written (ADR 0003): a field with no Override is absent, and an Override equal
to the code default is still written. Values by Field type:

| Field type | Written form | Example |
|---|---|---|
| `int`, `double` | number | `80`, `0.25` |
| `bool` | boolean | `true` |
| `String` | string | `"Hello"` |
| enum | value name | `"pingPong"` |
| `Vector2` | `[x, y]` | `[1, 0]` |
| `Color` | `"#AARRGGBB"`, upper-case hex | `"#FFFF8800"` |
| asset reference | `{"asset": path}` | `{"asset": "assets/images/fx.png"}` |
| entity reference | `{"ref": Node ID}` | `{"ref": "9b2e"}` |

A reader that knows the Field type coerces numbers: a `double` field accepts `80`.

## Canonical form

Pyro writes, and the round-trip tests check, exactly this form:

1. UTF-8 without a byte-order mark, LF line endings, one trailing newline.
2. Two-space indentation.
3. Top-level keys in the order `schemaVersion`, `rootId`, `nodes`, then any others sorted. Every
   other object's keys, Node IDs included, are sorted by `String.compareTo` (UTF-16 code
   units).
4. Empty objects and arrays are written `{}` and `[]`. Other objects are written one member per
   line, as `"key": value`.
5. Arrays whose elements are all numbers are written on one line: `[320, 128]`. All other arrays
   are written one element per line.
6. **Numbers:** a finite integral value with magnitude below 10²¹ is written as digits only
   (`80`, `-3`). Any other finite value uses the shortest form that reads back as the same
   double (`0.1`, `1e-7`, `1.23e-18`, `1e+21`). `-0.0` is written `0`. NaN and infinities are
   errors.
7. **Strings** escape `"`, `\` and characters below U+0020 (`\b \f \n \r \t`, others as
   `\u00XX` in lower-case hex). Nothing else is escaped: non-ASCII text, emoji and `/` are
   written as they are.
8. Optional keys with no value, and the empty collections listed above as omitted, are not
   written.

## Reading rules

- Accepted, then normalised on the next write: any key order or whitespace, CRLF line endings, a
  leading byte-order mark, `80.0` for `80`, and empty collections written out.
- Refused (an error, no Scene): malformed JSON (with line and column), duplicate keys in any
  object, `schemaVersion` missing, not a positive integer or newer than 1, an invalid root
  (missing, not kind `root`, or more than one), and a known key with the wrong type.
- Repaired and reported, never refused: inconsistent `childIds` (research R8).

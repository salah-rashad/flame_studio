# Contract: animation file v1 (`*.anim.json`)

What the Runtime reads (research R7). The format is project-plan §7.2. This contract adds the
reading rules. Pyro's writer (the grid slicer, v0.1.1) will write the Scene format's canonical
form (spec 001: sorted keys, two-space indent, LF), with `schemaVersion` first.

## Example

```json
{
  "schemaVersion": 1,
  "animations": {
    "idle": {
      "frames": [0, 1],
      "loop": true,
      "stepTimes": [0.4, 0.2]
    },
    "walk": {
      "frames": [4, 5, 6, 7],
      "loop": true,
      "stepTime": 0.1
    }
  },
  "grid": {
    "cellSize": [32, 32],
    "offset": [0, 0],
    "spacing": [0, 0]
  },
  "image": "assets/images/goblin_sheet.png"
}
```

## Keys

| Key | Type | Required | Rule |
|---|---|---|---|
| `schemaVersion` | integer | yes | positive; newer than 1 is refused with the required version |
| `image` | string | yes | project-relative asset path of the spritesheet |
| `grid.cellSize` | `[w, h]` | yes | both > 0 |
| `grid.offset` | `[x, y]` | no, default `[0, 0]` | both ≥ 0; the top-left of cell 0 |
| `grid.spacing` | `[x, y]` | no, default `[0, 0]` | both ≥ 0; gap between cells |
| `animations` | object | yes | at least one entry; keys are animation names, non-empty |
| `….frames` | array of integers | yes | non-empty, each ≥ 0; cell indexes, row by row |
| `….stepTime` | number | one of the two | > 0 seconds, every frame |
| `….stepTimes` | array of numbers | one of the two | each > 0, same length as `frames` |
| `….loop` | boolean | no, default `true` | |

Unknown keys are ignored by the Runtime. A writer must preserve them (constitution IV).

## Frames

`columns = floor((imageWidth − offset.x + spacing.x) / (cellSize.x + spacing.x))`, and likewise
`rows` for the height. Frame `i` is the cell at column `i % columns` and row `i ~/ columns`. Its
source rectangle starts at `offset + (column, row) × (cellSize + spacing)` and has size
`cellSize`. A frame with `i ≥ columns × rows` is an error naming the file, the animation and the
frame.

## Reading rules

- Refused, with line and column where the reader has them: malformed JSON, duplicate keys,
  `schemaVersion` missing, invalid or newer, any required key missing, a known key with the wrong
  type, or a broken rule from the table.
- In a Scene load, every refusal is wrapped in a `SceneLoadException` naming the Scene, the Node,
  the field and the animation file.

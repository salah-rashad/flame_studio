# Contract: Recovery Copies

The files Pyro keeps so unsaved work survives a crash (FR-024 to FR-029, research R11, R12).
Only Pyro reads them; neither games nor the developer's project ever see them.

## Folder

One folder per user, outside every project. #1 sets it to `recovery/` under the application
support folder (`path_provider`'s `getApplicationSupportDirectory()`, for example
`~/Library/Application Support/<bundle id>/recovery/` on macOS). Tests pass a folder in a
`MemoryFileSystem`.

## Files per copy

`<key>` is the lowercase hex SHA-256 of the UTF-8 string `<projectRoot>\n<scenePath>`, both
absolute and normalized with `package:path`'s `normalize` (no trailing separator).

| File | Contents |
|---|---|
| `<key>.scene.json` | The document's state, exactly as `SceneCodec.encode` writes it, so the normal reader opens it (including its `schemaVersion` check and repair) |
| `<key>.recovery.json` | Metadata, below |

```json
{
  "formatVersion": 1,
  "projectRoot": "/Users/dev/games/platformer",
  "scenePath": "/Users/dev/games/platformer/assets/scenes/level1.scene.json",
  "writtenAt": "2026-10-19T18:42:07.512Z"
}
```

- `writtenAt` is UTC, ISO 8601, from the injected clock.
- A newer `formatVersion` than Pyro knows makes the copy unreadable (reported and kept).

## Writing

1. `<key>.scene.json` atomically (temporary file + flush + rename in the recovery folder).
2. Then `<key>.recovery.json` the same way.

A crash between the two leaves a new Scene copy with older metadata; the copy is still complete
and readable, and its `writtenAt` is conservative.

## Reading (`RecoveryStore.find`)

1. Prune: delete both files of every copy whose `writtenAt` (or, when the metadata can't be
   read, the newer file's modification time) is more than 30 days before now.
2. Look up `<key>` for the requested project and Scene.
3. Neither file → `NoRecovery`.
4. Both files, metadata readable and matching the requested paths, Scene file decodes →
   `RecoveryAvailable(info)`, with the Scene file's own modification time (or null if it's
   gone).
5. Anything else (one file missing, bad JSON, mismatched paths, a `SceneFormatException`) →
   `RecoveryUnreadable(location, problem)`; nothing is deleted until step 1 prunes it after
   30 days.

Only Scenes with a file path have copies: a never-saved Scene has nothing to key one by
(spec FR-024).

## Removing

`discard` deletes both files; a missing file is not an error. `DocumentSession` calls it after
a successful save and in `discardAndClose`; #1 calls it when the developer declines *Restore*.

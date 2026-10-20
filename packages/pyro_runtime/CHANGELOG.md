## Unreleased

- The Registry contract the generated `lib/pyro.g.dart` implements: `PyroRegistry`,
  `RegistryType`, `RegistryField`, `TypeRole` and `FieldType`.
- Scene format, `schemaVersion` 1: `SceneCodec.decode` and `SceneCodec.encode`, the immutable
  `Scene` and Node model (root, entity, sprite, rectangle and circle hitboxes, Custom
  components, unknown kinds kept whole), Overrides and Behavior attachments, `EntityRef` and
  `AssetRef`.
- Reading refuses malformed JSON, duplicate keys and newer or invalid `schemaVersion`s, naming
  what failed and where.
- Damaged `childIds` lists are repaired deterministically and reported in a `RepairReport`;
  `warnAboutRepairs` prints it in debug builds.
- Writing produces one canonical form, byte-identical on every platform.

## 0.0.1

- Initial workspace skeleton; not published.

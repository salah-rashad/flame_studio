## Unreleased

- `PyroScene.load`: builds a Scene in four passes (construct, configure, resolve references,
  attach) through the Registry, with every built-in Node kind (`PyroEntity`, sprites, hitboxes),
  Behaviors and all v1 Field types, including `.anim.json` animations; fails with a
  `SceneLoadException` naming the Scene, Node, Type ID, field and asset; `UnknownType.skip`.
- Lookups: `find` and `findAll` by name, path, tag and type.
- Hot-swap in debug builds: a hot reload rebuilds a changed Scene and calls `onReloaded`;
  stale references to removed Nodes warn on first use.
- `AssetSource`, with `AssetSource.bundle()` reading the game's bundle without Flame's globals.
- `AssetRef.animation`: `{"asset": path, "animation": name}` for `SpriteAnimation` Overrides.
- `RegistryType.acceptsParent`. A `pyro.g.dart` generated before this version fails at startup
  with an `ArgumentError` naming the Behavior until `dart run build_runner build` regenerates
  it.
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

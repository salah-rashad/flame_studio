# Contract: the Runtime API

What `package:pyro_runtime/pyro_runtime.dart` adds for games in this item, plus the two amended
shapes it shares with the Scene format and the Generator. Declarations are signatures with their
documented behavior. Bodies are the implementation's.

## Loading

```dart
/// What a load does with a Type ID or Node kind it doesn't know (Q58).
enum UnknownType {
  /// Fail the load (the default).
  error,

  /// Leave it out: an unknown Behavior alone, an unknown Node with its
  /// subtree. A debug warning lists what was left out.
  skip,
}

/// Called after a Hot-swap rebuilt [scene]; re-run lookups here (Q71).
///
/// The new Nodes are in [scene] and lookups return them, but their own
/// `onLoad`s haven't run yet, just as after [PyroScene.load] returns. Read
/// their Editable fields and transforms here, not state they set up in
/// `onLoad`.
typedef SceneReloaded = void Function(PyroScene scene);

/// A loaded Scene: the Flame component standing for its root Node.
final class PyroScene extends Component {
  /// Loads the Scene at [path], a project-relative asset path such as
  /// `assets/scenes/level1.scene.json`.
  ///
  /// Completes once every Node is built and every asset loaded, with the
  /// Scene's Nodes queued as children; their `onLoad`s run when the
  /// returned component is added to a game. Throws a [SceneLoadException]
  /// and returns nothing on any failure.
  static Future<PyroScene> load(
    String path, {
    required PyroRegistry registry,
    UnknownType onUnknownType = UnknownType.error,
    SceneReloaded? onReloaded,
    AssetSource? assets, // default: AssetSource.bundle(), one per Scene
  });

  /// The Scene's asset path.
  AssetPath get path;

  /// The one Node component matching [nameOrPath] (FR-019, FR-020).
  ///
  /// Throws a [StateError] if none or several match (listing their paths),
  /// or if the match isn't a [T] (naming its type).
  T find<T extends Component>(String nameOrPath);

  /// Every Node component matching all the given filters, in tree order.
  /// [name] takes a Node name or a path, as [find] does.
  List<T> findAll<T extends Component>({String? name, String? tag});
}
```

Paths: `boss` (any Node named `boss`), `arena/boss` (a `boss` whose parent is `arena`, at any
depth), `/arena/boss` (the same, with `arena` a child of the root). Unnamed Nodes match only
`tag` and `T` filters.

`PyroScene` overrides `onHotReload` (calling `super`) and `onRemove`. It overrides no `update` or
`render`.

## Built-in Node components

```dart
/// The component of an `entity` Node: a positioned entity that holds
/// Behaviors, with no behavior of its own.
class PyroEntity extends PositionedEntity {
  PyroEntity({super.position, super.size, super.scale, super.angle, super.anchor});
}
```

`sprite` → `SpriteComponent`, `rectangleHitbox` → `RectangleHitbox`, `circleHitbox` →
`CircleHitbox` (research R3). These are Flame's own classes, so `find<SpriteComponent>('sprite')`
works.

## Assets

```dart
/// Where a load reads its files from, by project-relative path (Q31, Q79).
abstract interface class AssetSource {
  /// Reads the game's asset bundle ([rootBundle] by default), with its own
  /// image cache and no path prefix.
  factory AssetSource.bundle([AssetBundle? bundle]);

  /// The text of the file at [path], read fresh, never from a cache.
  Future<String> loadText(AssetPath path);

  /// The decoded image at [path]. Repeated calls may return the same
  /// [Image]; the source owns and disposes its images.
  Future<Image> loadImage(AssetPath path);
}
```

## Errors

```dart
/// A Scene that couldn't be loaded, with everything that names the cause.
final class SceneLoadException implements Exception {
  /// The Scene's asset path.
  final AssetPath scene;

  /// The Node involved, if any.
  final NodeId? nodeId;
  final String? nodeName;

  /// The Type ID, field and asset involved, where they apply.
  final TypeId? typeId;
  final String? field;
  final AssetPath? asset;

  /// What went wrong and how to fix it, in one or two sentences.
  final String message;

  /// The underlying error (a SceneFormatException, an error from user
  /// code, an asset bundle error) and its stack trace, if any.
  final Object? cause;
  final StackTrace? causeStackTrace;

  /// One line naming the Scene, Node, Type ID, field and asset, then
  /// [message], then the cause.
  @override
  String toString();
}
```

Example messages:

```text
assets/scenes/level1.scene.json: Node "goblin_1" (3f1c) uses the Behavior "Patrol", which isn't in
the Registry. Was the class renamed or deleted? Keep its old name as an explicit id:, or pass
onUnknownType: UnknownType.skip to load without it.

assets/scenes/level1.scene.json: Node "player" (9b2e), Player.maxHealth: the Override "lots"
isn't an int.

assets/scenes/level1.scene.json: Node "goblin_1" (3f1c), Patrol.hitEffect: the animation "run"
isn't in assets/anims/goblin.anim.json, which holds "idle", "walk".
```

## Amended: `RegistryType` (spec 003 contract)

```dart
final class RegistryType {
  const RegistryType({
    required this.id,
    required this.role,
    required this.create,
    required this.fields,
    this.acceptsParent, // new
  });

  /// For a Behavior, whether it can be attached to [parent]: the type
  /// argument of its `Behavior<T>` (FR-013a of spec 003). Null for Custom
  /// components.
  final bool Function(Component parent)? acceptsParent;
  // id, role, create, fields unchanged
}
```

The Generator emits `acceptsParent: (parent) => parent is <T>` for every Behavior, where `<T>` is
the Behavior's type argument, imported like field types, or `EntityMixin` when there is none.
`PyroRegistry` throws an `ArgumentError` for a Behavior without `acceptsParent` or a Custom
component with one, so a hand-written Registry can't get it wrong.

## Amended: `AssetRef` (spec 001 contract)

```dart
final class AssetRef {
  const AssetRef(this.path, {this.animation}); // animation is new

  final AssetPath path;

  /// For a SpriteAnimation Override, the animation's name in the
  /// `.anim.json` file at [path]; null otherwise.
  final String? animation;

  /// `{"asset": path}` or `{"asset": path, "animation": name}`, both
  /// non-empty strings; null for any other value.
  static AssetRef? fromJson(Object? value);

  Map<String, Object?> toJson();
}
```

Written form, Scene format `schemaVersion` 1:

| Field type | Written form | Example |
|---|---|---|
| asset reference (`ImagePath`, `Sprite`) | `{"asset": path}` | `{"asset": "assets/images/fx.png"}` |
| `SpriteAnimation` | `{"asset": path, "animation": name}` | `{"animation": "walk", "asset": "assets/anims/goblin.anim.json"}` |

## Exports

`pyro_runtime.dart` adds `PyroScene`, `UnknownType`, `SceneReloaded`, `PyroEntity`, `AssetSource`
and `SceneLoadException`. It also re-exports `flame_behaviors`' `EntityMixin` and `Behavior`,
since game code that loads Scenes already uses them. Everything else stays in `lib/src/`.

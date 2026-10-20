# pyro_runtime

Loads Scenes made in Pyro into your Flame game, and Hot-swaps them while
you develop.

Add it as a regular dependency, with `pyro_generator` and `build_runner` as
dev dependencies; it re-exports `pyro_annotations`, and `Behavior` and
`EntityMixin` from `flame_behaviors`. Requires Flame ≥ 1.36. Declare your
Scene, image and animation folders under `flutter: assets:` in
`pubspec.yaml`.

## Load a Scene

```dart
import 'package:flame/game.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'pyro.g.dart'; // the Registry pyro_generator writes

class MyGame extends FlameGame {
  late Player player;

  @override
  Future<void> onLoad() async {
    final scene = await PyroScene.load(
      'assets/scenes/level1.scene.json',
      registry: pyroRegistry,
      onReloaded: _lookUpNodes, // re-run lookups after a Hot-swap
    );
    world.add(scene);
    _lookUpNodes(scene);
  }

  void _lookUpNodes(PyroScene scene) {
    player = scene.find<Player>('player');        // by Node name
    final enemies = scene.findAll(tag: 'enemy');  // by tag
    final boss = scene.find<Boss>('arena/boss');  // by path when names repeat
  }
}
```

- Every Node becomes a Flame component: entities are `PyroEntity`s, sprites
  `SpriteComponent`s, hitboxes Flame's `RectangleHitbox` and `CircleHitbox`,
  and Custom components and Behaviors your own classes. Each `onLoad` runs
  with its Overrides, assets and entity references already set.
- `find` throws when no Node or several match; `findAll` filters by name or
  path, tag and type. Both work as soon as `load` returns.
- A Scene that doesn't fit the code fails with a `SceneLoadException`
  naming the Scene, the Node, the Type ID, the field and the asset involved.
  While you rename or delete classes, `onUnknownType: UnknownType.skip`
  loads without the unknown ones.

## Hot-swap

In a debug build, a hot reload through `flutter run` (Pyro's Play button,
or `r` in a terminal) rebuilds a Scene whose file or animation files
changed, then calls `onReloaded`. A Dart-only reload leaves it alone, and a
file that no longer loads keeps the old Scene running with a debug error.
References your code kept from before point at removed components: re-run
lookups in `onReloaded`; a debug warning names any removed Node that is
still moved or added back. Release builds contain none of this.

Games run without Pyro too: from the IDE, CI or a release build, Scenes
load the same way.

## Upgrading

Regenerate `lib/pyro.g.dart` (`dart run build_runner build`) after
upgrading: a Registry generated before `RegistryType.acceptsParent` existed
fails at startup with an `ArgumentError` naming the Behavior.

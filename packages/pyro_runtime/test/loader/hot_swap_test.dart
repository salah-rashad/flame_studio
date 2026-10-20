import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../support/loader_fixtures.dart';
import '../support/memory_asset_source.dart';
import '../support/scene_text.dart';
import '../support/test_registry.dart';

/// Root → `player` at ([x], 0), holding an `AllFields` whose `effect` is
/// [animation] of [fxAnim].
String _scene(double x, {String animation = 'walk'}) => sceneJson([
  RootNode(id: const NodeId('root'), childIds: const [NodeId('p')]),
  CustomNode(
    id: const NodeId('p'),
    name: 'player',
    type: const TypeId('Player'),
    transform: at(x, 0),
    behaviors: [
      BehaviorAttachment(
        type: const TypeId('AllFields'),
        fields: Overrides({
          'effect': {'asset': fxAnim, 'animation': animation},
        }),
      ),
    ],
  ),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> printed;
  late DebugPrintCallback original;
  late MemoryAssetSource source;
  late List<PyroScene> reloads;

  setUp(() async {
    printed = [];
    reloads = [];
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    source = await sourceFor(_scene(0));
  });

  tearDown(() => debugPrint = original);

  Future<PyroScene> mount(FlameGame game) async {
    final scene = await PyroScene.load(
      scenePath,
      registry: testRegistry,
      assets: source,
      onReloaded: reloads.add,
    );
    await game.ensureAdd(scene);
    await game.ready();
    return scene;
  }

  Future<void> hotReload(FlameGame game, PyroScene scene) async {
    game.onHotReload();
    await scene.pendingCheck;
    await game.ready();
  }

  testWithFlameGame('#1, #6 a changed Scene rebuilds into the same '
      'PyroScene and calls onReloaded', (game) async {
    final scene = await mount(game);
    final before = scene.find<Player>('player');

    source.texts[scenePath] = _scene(100);
    await hotReload(game, scene);

    final after = scene.find<Player>('player');
    expect(after, isNot(same(before)));
    expect(after.position.x, 100);
    expect(after.isMounted, isTrue);
    expect(before.isMounted, isFalse);
    expect(scene.parent, same(game));
    expect(game.children.whereType<PyroScene>().single, same(scene));
    expect(reloads, [same(scene)]);
  });

  testWithFlameGame('#2 an unchanged Scene is left alone, reading each file '
      'once', (game) async {
    final scene = await mount(game);
    final before = scene.find<Player>('player')..position.x = 42;
    final reads = Map.of(source.textReads);

    await hotReload(game, scene);

    expect(scene.find<Player>('player'), same(before));
    expect(before.position.x, 42, reason: 'runtime state is kept');
    expect(reloads, isEmpty);
    expect(source.textReads[scenePath], reads[scenePath]! + 1);
    expect(source.textReads[fxAnim], reads[fxAnim]! + 1);
  });

  testWithFlameGame('#3 a changed animation file alone rebuilds', (game) async {
    final scene = await mount(game);
    source.texts[fxAnim] = fxAnimText.replaceFirst(
      '"stepTime": 0.1',
      '"stepTime": 0.3',
    );
    await hotReload(game, scene);

    final effect = scene
        .find<Player>('player')
        .findBehavior<AllFields>()
        .effect!;
    expect(effect.frames.first.stepTime, 0.3);
    expect(reloads, hasLength(1));
  });

  testWithFlameGame('#4 a changed image alone doesn\'t rebuild', (game) async {
    final scene = await mount(game);
    final before = scene.find<Player>('player');
    source.images[sheet] = source.images[sheet]!.clone();
    await hotReload(game, scene);
    expect(scene.find<Player>('player'), same(before));
    expect(reloads, isEmpty);
  });

  testWithFlameGame('#5 a broken file keeps the old Scene; a fixed one '
      'rebuilds', (game) async {
    final scene = await mount(game);
    final before = scene.find<Player>('player');

    source.texts[scenePath] = '{"schemaVersion": 1,';
    await hotReload(game, scene);
    source.texts[scenePath] = _scene(5).replaceFirst('"Player"', '"Ghost"');
    await hotReload(game, scene);

    expect(scene.find<Player>('player'), same(before));
    expect(before.isMounted, isTrue);
    expect(reloads, isEmpty);
    final errors = printed.where((p) => p.contains("couldn't Hot-swap"));
    expect(errors, hasLength(2));
    expect(errors, everyElement(contains(scenePath)));

    source.texts[scenePath] = _scene(7);
    await hotReload(game, scene);
    expect(scene.find<Player>('player').position.x, 7);
    expect(reloads, hasLength(1));
  });

  testWithFlameGame('checks never overlap; the Scene ends on the latest '
      'text', (game) async {
    final scene = await mount(game);
    final gate = Completer<void>();
    source
      ..texts[scenePath] = _scene(1)
      ..textGate = gate.future;
    game.onHotReload();
    source.texts[scenePath] = _scene(2);
    game.onHotReload();
    gate.complete();
    await scene.pendingCheck;
    await game.ready();

    expect(scene.find<Player>('player').position.x, 2);
    expect(reloads, isNotEmpty);
  });

  testWithFlameGame('a Scene never added to the game reads nothing', (
    game,
  ) async {
    final scene = await PyroScene.load(
      scenePath,
      registry: testRegistry,
      assets: source,
    );
    final reads = source.textReads[scenePath];
    game.onHotReload();
    await scene.pendingCheck;
    expect(source.textReads[scenePath], reads);
  });

  testWithFlameGame('SC-003: 100 reloads alternating changed and unchanged '
      'content rebuild exactly 50 times', (game) async {
    final scene = await mount(game);
    for (var i = 1; i <= 50; i++) {
      source.texts[scenePath] = _scene(i.toDouble());
      await hotReload(game, scene);
      await hotReload(game, scene);
    }
    expect(reloads, hasLength(50));
    expect(scene.find<Player>('player').position.x, 50);
    expect(scene.children.whereType<PositionComponent>(), hasLength(1));
  });
}

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../support/loader_fixtures.dart';
import '../support/memory_asset_source.dart';
import '../support/scene_text.dart';
import '../support/test_registry.dart';

/// Root → `player` (9b2e) at ([x], 0) → `hand` (an entity).
String _scene(double x) => sceneJson([
  RootNode(id: const NodeId('root'), childIds: const [NodeId('9b2e')]),
  CustomNode(
    id: const NodeId('9b2e'),
    name: 'player',
    type: const TypeId('Player'),
    transform: at(x, 0),
    childIds: const [NodeId('h1')],
  ),
  EntityNode(id: const NodeId('h1'), name: 'hand', transform: at(1, 1)),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> printed;
  late DebugPrintCallback original;
  late MemoryAssetSource source;

  setUp(() async {
    printed = [];
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    source = await sourceFor(_scene(0));
  });

  tearDown(() => debugPrint = original);

  Iterable<String> warnings() =>
      printed.where((p) => p.contains('still uses Node'));

  Future<PyroScene> mount(FlameGame game) async {
    final scene = await PyroScene.load(
      scenePath,
      registry: testRegistry,
      assets: source,
    );
    await game.ensureAdd(scene);
    await game.ready();
    return scene;
  }

  Future<void> swap(FlameGame game, PyroScene scene, double x) async {
    source.texts[scenePath] = _scene(x);
    game.onHotReload();
    await scene.pendingCheck;
    await game.ready();
    // Let the removed components' `removed` futures start their watchers.
    await Future<void>.delayed(Duration.zero);
  }

  testWithFlameGame('the swap itself warns about nothing', (game) async {
    final scene = await mount(game);
    await swap(game, scene, 10);
    game.update(0);
    expect(warnings(), isEmpty);
  });

  testWithFlameGame('moving a stale component warns once, naming it', (
    game,
  ) async {
    final scene = await mount(game);
    final stale = scene.find<Player>('player');
    await swap(game, scene, 10);

    stale.position.x = 5;
    stale.position.x = 6;
    expect(warnings(), hasLength(1));
    expect(
      warnings().single,
      allOf(
        contains(scenePath),
        contains('"player" (9b2e)'),
        contains('onReloaded'),
      ),
    );
  });

  testWithFlameGame('a stale nested Node warns too', (game) async {
    final scene = await mount(game);
    final hand = scene.find<PyroEntity>('hand');
    await swap(game, scene, 10);
    hand.position.y = 3;
    expect(warnings().single, contains('"hand" (h1)'));
  });

  testWithFlameGame('adding a stale component back warns once per Node', (
    game,
  ) async {
    final scene = await mount(game);
    final stale = scene.find<Player>('player');
    await swap(game, scene, 10);

    await game.ensureAdd(stale);
    await Future<void>.delayed(Duration.zero);
    // The player and the hand it carries back in: one warning per Node.
    expect(warnings(), hasLength(2));
    expect(warnings().first, contains('"player" (9b2e)'));
    expect(warnings().last, contains('"hand" (h1)'));
  });

  testWithFlameGame('components of the current version carry no listener', (
    game,
  ) async {
    final scene = await mount(game);
    await swap(game, scene, 10);
    final current = scene.find<Player>('player');
    current.position.x = 99;
    expect(warnings(), isEmpty);
    expect(scene.staleWatch!.watching, 2, reason: 'the two removed Nodes');
  });

  testWithFlameGame('the next swap stops watching the first generation', (
    game,
  ) async {
    final scene = await mount(game);
    final first = scene.find<Player>('player');
    await swap(game, scene, 10);
    final second = scene.find<Player>('player');
    await swap(game, scene, 20);

    first.position.x = 1;
    expect(warnings(), isEmpty);
    second.position.x = 1;
    expect(warnings(), hasLength(1));
  });

  testWithFlameGame('removing the PyroScene detaches every watcher', (
    game,
  ) async {
    final scene = await mount(game);
    final stale = scene.find<Player>('player');
    await swap(game, scene, 10);
    scene.removeFromParent();
    await game.ready();

    stale.position.x = 1;
    expect(warnings(), isEmpty);
    expect(scene.staleWatch, isNull);
  });
}

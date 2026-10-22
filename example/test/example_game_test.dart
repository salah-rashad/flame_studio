import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_example/behaviors/spin.dart';
import 'package:pyro_example/components/banner.dart';
import 'package:pyro_example/example_game.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// The example game loads its Scene with every Override applied and keeps
/// its own state outside the Scene (spec 005, US1 #3–#4, US3 #3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<ExampleGame>('loads the Scene', ExampleGame.new, (game) async {
    final ship = game.scene.find<PyroEntity>('ship');
    final spin = ship.findBehavior<Spin>();
    expect(spin.turnsPerSecond, 0.5, reason: 'the Override');
    expect(spin.clockwise, isTrue, reason: 'the default from code');
    expect(game.scene.find<SpriteComponent>('hull').sprite, isNotNull);
    expect(game.scene.find<RectangleHitbox>('body').size, Vector2(48, 48));

    final title = game.scene.find<Banner>('title');
    expect(title.message, 'Hello from Pyro');
    expect(title.color, const Color(0xFFFFFFFF));
    expect(title.text, 'Hello from Pyro');
  });

  testWithGame<ExampleGame>('Spin turns the ship clockwise', ExampleGame.new, (
    game,
  ) async {
    final ship = game.scene.find<PyroEntity>('ship');
    final before = ship.angle;
    game.update(1);
    expect(ship.angle - before, closeTo(0.5 * 2 * math.pi, 1e-9));
  });

  testWithGame<ExampleGame>(
    'the HUD counts time, swaps and the code',
    ExampleGame.new,
    (game) async {
      game.update(1);
      expect(game.hudText, 'time: 1s  swaps: 0  code: v1');
    },
  );

  testWithGame<ExampleGame>(
    'a hot reload with the Scene unchanged is no Hot-swap',
    ExampleGame.new,
    (game) async {
      game.onHotReload();
      await game.scene.pendingCheck;
      expect(game.swaps, 0);
    },
  );
}

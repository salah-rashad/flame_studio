import 'dart:ui';

import 'package:fixture_game/behaviors/blink.dart';
import 'package:fixture_game/behaviors/patrol.dart';
import 'package:fixture_game/components/boss.dart';
import 'package:fixture_game/components/enemy.dart';
import 'package:fixture_game/components/lamp.dart';
import 'package:fixture_game/components/player.dart';
import 'package:fixture_game/pyro.g.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// A Scene loads through the game's own asset bundle with the committed,
/// generated Registry: the pattern #12's contract test reuses for
/// `example/` (spec 004, US5, quickstart §3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithFlameGame('loads assets/scenes/fixture.scene.json', (game) async {
    final scene = await PyroScene.load(
      'assets/scenes/fixture.scene.json',
      registry: pyroRegistry,
    );
    await game.ensureAdd(scene);
    await game.ready();

    final player = scene.find<Player>('player');
    expect(player.lives, 5);
    expect(player.icon!.image.width, 64);
    expect(player.position, Vector2(64, 128));

    final patrol = player.findBehavior<Patrol>();
    expect(patrol.speed, 80);
    expect(patrol.direction, Vector2(0, 1));
    expect(patrol.mode, PatrolMode.loop);
    expect(patrol.target, same(player));
    expect(patrol.hitEffect!.frames, hasLength(2));
    expect(patrol.trail, const ImagePath('assets/images/sheet.png'));
    expect(player.findBehavior<Blink>().visible, isTrue);

    final sprite = scene.find<SpriteComponent>('sprite');
    expect(sprite.sprite!.srcPosition, Vector2(32, 0));
    expect(scene.find<RectangleHitbox>('body').size, Vector2(28, 44));

    final grunt = scene.findAll<Enemy>(tag: 'enemy').single;
    expect(grunt.health, 4);
    expect(grunt.glow, 0.75);
    final boss = scene.find<Boss>('boss');
    expect(boss.rage, 3);
    expect(boss.minion, same(grunt));
    expect(scene.find<Lamp>('lamp').tint, const Color(0xFFFFCC00));
  });
}

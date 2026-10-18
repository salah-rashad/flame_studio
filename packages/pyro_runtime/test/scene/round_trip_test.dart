import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'fixtures.dart';

String _roundTrip(String text) =>
    SceneCodec.encode(SceneCodec.decode(text).scene);

void main() {
  group('canonical fixtures round-trip byte for byte (SC-001)', () {
    for (final name in fixtureNames('canonical')) {
      test(name, () {
        final text = readFixture('canonical/$name');
        expect(_roundTrip(text), text);
      });
    }
  });

  group('non-canonical fixtures are normalised, then stable (FR-016)', () {
    for (final name in fixtureNames('non_canonical')) {
      test(name, () {
        final output = _roundTrip(readFixture('non_canonical/$name'));
        expect(output, readExpected('non_canonical', name));
        expect(_roundTrip(output), output);
      });
    }
  });

  test('moving one Node changes one line inside its block (SC-003)', () {
    final text = readFixture('canonical/entity.scene.json');
    final scene = SceneCodec.decode(text).scene;
    final goblin = scene.nodes[const NodeId('e1')]! as EntityNode;
    final moved = goblin.copyWith(
      transform: goblin.transform.copyWith(position: const Vec2(321, 128)),
    );
    final output = SceneCodec.encode(
      scene.copyWith(nodes: {...scene.nodes, goblin.id: moved}),
    );

    final before = text.split('\n');
    final after = output.split('\n');
    expect(after, hasLength(before.length));
    final changed = [
      for (var i = 0; i < before.length; i++)
        if (before[i] != after[i]) i,
    ];
    expect(changed, hasLength(1));
    expect(after[changed.single], '        "position": [321, 128],');
    final blockStart = before.indexOf('    "e1": {');
    final blockEnd = before.indexOf('    "e2": {');
    expect(changed.single, inExclusiveRange(blockStart, blockEnd));
  });

  test('unknown kinds and keys are kept (FR-017)', () {
    final scene = SceneCodec.decode(
      readFixture('canonical/unknown_kind.scene.json'),
    ).scene;

    final prefab = scene.nodes[const NodeId('u1')]! as UnknownNode;
    expect(prefab.kind, 'prefabInstance');
    expect(prefab.name, 'goblin_2');
    expect(prefab.extra['prefab'], 'assets/scenes/prefabs/goblin.scene.json');

    final entity = scene.nodes[const NodeId('e1')]! as EntityNode;
    expect(entity.extra, {'locked': true});
    expect(entity.transform.extra, {
      'skew': [0, 0.5],
    });

    final hitbox = scene.nodes[const NodeId('h1')]! as RectangleHitboxNode;
    expect(hitbox.propsExtra, {'debugColor': '#FFFF0000'});

    expect(scene.extra.keys, ['editor']);
  });

  test('decodes every built-in Node kind into its class', () {
    final entity = SceneCodec.decode(
      readFixture('canonical/entity.scene.json'),
    ).scene;
    final goblin = entity.nodes[const NodeId('e1')]! as EntityNode;
    expect(goblin.name, 'goblin');
    expect(goblin.tags, ['enemy', 'patrol']);
    expect(goblin.transform.anchor, NodeAnchor.center);
    expect(goblin.transform.position, const Vec2(320, 128));
    expect(entity.parentOf(const NodeId('e2')), const NodeId('e1'));

    final sprites = SceneCodec.decode(
      readFixture('canonical/sprite.scene.json'),
    ).scene;
    final frame = sprites.nodes[const NodeId('s1')]! as SpriteNode;
    expect(frame.image, const AssetPath('assets/images/goblin_sheet.png'));
    expect(
      frame.region,
      const SpriteRegion(position: Vec2(32, 0), size: Vec2(32, 32)),
    );
    expect((sprites.nodes[const NodeId('s2')]! as SpriteNode).region, isNull);

    final rects = SceneCodec.decode(
      readFixture('canonical/rectangle_hitbox.scene.json'),
    ).scene;
    final feet = rects.nodes[const NodeId('h2')]! as RectangleHitboxNode;
    expect(feet.collisionType, NodeCollisionType.passive);
    expect(feet.isSolid, isTrue);
    expect(feet.angle, 0.25);

    final circles = SceneCodec.decode(
      readFixture('canonical/circle_hitbox.scene.json'),
    ).scene;
    final sensor = circles.nodes[const NodeId('c1')]! as CircleHitboxNode;
    expect(sensor.radius, 40.5);
    expect(sensor.collisionType, NodeCollisionType.inactive);

    final custom = SceneCodec.decode(
      readFixture('canonical/custom.scene.json'),
    ).scene;
    final player = custom.nodes[const NodeId('p1')]! as CustomNode;
    expect(player.type, const TypeId('Player'));
    expect(player.fields.isEmpty, isTrue);
  });

  test('text round-trips exactly', () {
    final scene = SceneCodec.decode(
      readFixture('canonical/text.scene.json'),
    ).scene;
    final node = scene.nodes[const NodeId('e1')]! as EntityNode;
    expect(node.name, 'say "hi" \\ 😀 مرحبا\nline two\ttab');
  });
}

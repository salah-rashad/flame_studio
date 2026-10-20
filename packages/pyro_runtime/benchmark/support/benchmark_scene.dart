// The 1,000-Node Scene the Scene format and loader benchmarks share
// (spec 001 SC-006, spec 004 SC-004). Pure Dart, so the codec benchmark
// still runs outside Flutter.
import 'package:pyro_runtime/src/scene/node.dart';
import 'package:pyro_runtime/src/scene/overrides.dart';
import 'package:pyro_runtime/src/scene/scene.dart';
import 'package:pyro_runtime/src/scene/values.dart';

/// The path of the benchmark Scene's image number [n] (0–9).
String benchmarkImage(int n) => 'assets/images/goblin_sheet_$n.png';

/// root → 250 entities, each with one Behavior with three fields, a sprite
/// (one of 10 images), a rectangle hitbox and a circle hitbox:
/// 1 + 250 × 4 = 1,001 Nodes.
Scene benchmarkScene() {
  const rootId = NodeId('root');
  final nodes = <NodeId, Node>{};
  final entities = <NodeId>[];
  for (var i = 0; i < 250; i++) {
    final entity = NodeId('entity-$i');
    final sprite = NodeId('sprite-$i');
    final hitbox = NodeId('hitbox-$i');
    final extra = NodeId('marker-$i');
    entities.add(entity);
    nodes[entity] = EntityNode(
      id: entity,
      childIds: [sprite, hitbox, extra],
      name: 'goblin_$i',
      tags: const ['enemy'],
      transform: NodeTransform(
        position: Vec2(i * 32.5, i * 12.25),
        size: const Vec2(32, 32),
        anchor: NodeAnchor.center,
      ),
      behaviors: [
        BehaviorAttachment(
          type: const TypeId('Patrol'),
          fields: Overrides({
            'speed': 80 + i,
            'mode': 'pingPong',
            'target': {'ref': 'entity-${(i + 1) % 250}'},
          }),
        ),
      ],
    );
    nodes[sprite] = SpriteNode(
      id: sprite,
      transform: NodeTransform(size: const Vec2(32, 32)),
      image: AssetPath(benchmarkImage(i % 10)),
      region: SpriteRegion(
        position: Vec2((i % 8) * 32, 0),
        size: const Vec2(32, 32),
      ),
    );
    nodes[hitbox] = RectangleHitboxNode(
      id: hitbox,
      name: 'body',
      position: const Vec2(4, 2),
      size: const Vec2(24, 30),
    );
    nodes[extra] = CircleHitboxNode(id: extra, name: 'sensor', radius: 48);
  }
  nodes[rootId] = RootNode(id: rootId, childIds: entities);
  return Scene(rootId: rootId, nodes: nodes);
}

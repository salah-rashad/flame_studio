import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/src/node_children.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

void main() {
  const children = [NodeId('c1'), NodeId('c2')];
  final transform = NodeTransform(position: const Vec2(1, 2));
  const extra = {'futureKey': 1};
  final behaviors = [
    BehaviorAttachment(
      type: const TypeId('Patrol'),
      fields: Overrides({'speed': 80}),
    ),
  ];

  final nodes = <Node>[
    RootNode(id: const NodeId('r'), extra: extra),
    EntityNode(
      id: const NodeId('e'),
      extra: extra,
      name: 'goblin',
      tags: const ['enemy'],
      transform: transform,
      behaviors: behaviors,
    ),
    SpriteNode(
      id: const NodeId('s'),
      extra: extra,
      name: 'body',
      transform: transform,
      image: const AssetPath('assets/images/goblin.png'),
      region: const SpriteRegion(position: Vec2.zero, size: Vec2(8, 8)),
      propsExtra: const {'tint': 'red'},
    ),
    RectangleHitboxNode(
      id: const NodeId('rh'),
      extra: extra,
      size: const Vec2(4, 4),
      isSolid: true,
      propsExtra: const {'layer': 2},
    ),
    CircleHitboxNode(
      id: const NodeId('ch'),
      extra: extra,
      radius: 3,
      collisionType: NodeCollisionType.passive,
    ),
    CustomNode(
      id: const NodeId('cu'),
      extra: extra,
      type: const TypeId('Spawner'),
      transform: transform,
      fields: Overrides({'rate': 2}),
      behaviors: behaviors,
    ),
    UnknownNode(
      id: const NodeId('u'),
      extra: extra,
      name: 'prefab',
      tags: const ['x'],
      kind: 'prefabInstance',
    ),
  ];

  for (final node in nodes) {
    test('withChildIds keeps every other field of ${node.runtimeType}', () {
      final changed = withChildIds(node, children);
      expect(changed.runtimeType, node.runtimeType);
      expect(changed.id, node.id);
      expect(changed.childIds, children);
      expect(changed.extra, node.extra);
      if (node is NamedNode) {
        changed as NamedNode;
        expect(changed.name, node.name);
        expect(changed.tags, node.tags);
      }
      switch (node) {
        case EntityNode():
          changed as EntityNode;
          expect(identical(changed.transform, node.transform), isTrue);
          expect(changed.behaviors, node.behaviors);
        case SpriteNode():
          changed as SpriteNode;
          expect(identical(changed.transform, node.transform), isTrue);
          expect(changed.image, node.image);
          expect(changed.region, node.region);
          expect(changed.propsExtra, node.propsExtra);
        case RectangleHitboxNode():
          changed as RectangleHitboxNode;
          expect(changed.size, node.size);
          expect(changed.isSolid, node.isSolid);
          expect(changed.propsExtra, node.propsExtra);
        case CircleHitboxNode():
          changed as CircleHitboxNode;
          expect(changed.radius, node.radius);
          expect(changed.collisionType, node.collisionType);
        case CustomNode():
          changed as CustomNode;
          expect(changed.type, node.type);
          expect(identical(changed.fields, node.fields), isTrue);
          expect(changed.behaviors, node.behaviors);
        case UnknownNode():
          changed as UnknownNode;
          expect(changed.kind, node.kind);
        case RootNode():
          break;
      }
    });
  }
}

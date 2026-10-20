import 'dart:async';

import 'package:pyro_runtime/pyro_runtime.dart';

/// A Node ID source counting `n1`, `n2`, … so tests are deterministic.
NodeId Function() counterIds([String prefix = 'n']) {
  var next = 0;
  return () => NodeId('$prefix${++next}');
}

/// An entity with a default transform.
EntityNode entity(String id, {List<String> children = const []}) => EntityNode(
  id: NodeId(id),
  childIds: [for (final c in children) NodeId(c)],
  name: id,
  transform: NodeTransform(),
);

/// A sprite drawing `images/<id>.png`.
SpriteNode sprite(String id) => SpriteNode(
  id: NodeId(id),
  name: id,
  transform: NodeTransform(),
  image: AssetPath('assets/images/$id.png'),
);

/// root → a (→ a1 sprite), b.
Scene smallScene() => Scene(
  rootId: const NodeId('root'),
  nodes: {
    const NodeId('root'): RootNode(
      id: const NodeId('root'),
      childIds: const [NodeId('a'), NodeId('b')],
    ),
    const NodeId('a'): entity('a', children: ['a1']),
    const NodeId('a1'): sprite('a1'),
    const NodeId('b'): entity('b'),
  },
);

/// A Scene of about [nodes] Nodes: the root and entities `e<i>`, each with a
/// sprite `e<i>s` and a rectangle hitbox `e<i>h`. IDs are deterministic.
Scene generatedScene(int nodes) {
  final entities = (nodes - 1) ~/ 3;
  final all = <NodeId, Node>{};
  final rootChildren = <NodeId>[];
  for (var i = 0; i < entities; i++) {
    final id = NodeId('e$i');
    final spriteId = NodeId('e${i}s');
    final hitboxId = NodeId('e${i}h');
    rootChildren.add(id);
    all[id] = EntityNode(
      id: id,
      childIds: [spriteId, hitboxId],
      name: 'enemy $i',
      transform: NodeTransform(position: Vec2(i * 8.0, i * 4.0)),
    );
    all[spriteId] = SpriteNode(
      id: spriteId,
      transform: NodeTransform(size: const Vec2(16, 16)),
      image: const AssetPath('assets/images/enemy.png'),
    );
    all[hitboxId] = RectangleHitboxNode(id: hitboxId, size: const Vec2(16, 16));
  }
  const rootId = NodeId('root');
  all[rootId] = RootNode(id: rootId, childIds: rootChildren);
  return Scene(rootId: rootId, nodes: all);
}

/// The inline `Offload`: runs [work] in place, so `fakeAsync` tests never wait
/// on a real isolate (spec 002, research R9).
Future<R> runInline<R>(FutureOr<R> Function() work) async => work();

// Times SceneCodec on a 1,000-Node Scene (SC-006: median under 100 ms each
// for decode and encode, AOT, on the reference Mac).
//
//   dart run benchmark/scene_codec_benchmark.dart
//   dart compile exe benchmark/scene_codec_benchmark.dart -o /tmp/scene_bench
//   /tmp/scene_bench
//
// Imports only the pure-Dart scene format (research R5), so it runs outside
// Flutter.
import 'dart:io';

import 'package:pyro_runtime/src/scene/node.dart';
import 'package:pyro_runtime/src/scene/overrides.dart';
import 'package:pyro_runtime/src/scene/scene.dart';
import 'package:pyro_runtime/src/scene/scene_codec.dart';
import 'package:pyro_runtime/src/scene/values.dart';

const int _warmUp = 10;
const int _runs = 50;

void main() {
  final text = SceneCodec.encode(_buildScene());
  final scene = SceneCodec.decode(text).scene;
  stdout.writeln(
    'Scene: ${scene.nodes.length} Nodes, '
    '${(text.length / 1024).toStringAsFixed(1)} KB',
  );

  _report('decode', () => SceneCodec.decode(text));
  _report('encode', () => SceneCodec.encode(scene));
}

/// root → 250 entities, each with one Behavior with three fields, a sprite,
/// a rectangle hitbox and a circle hitbox: 1 + 250 × 4 = 1,001 Nodes.
Scene _buildScene() {
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
      image: const AssetPath('assets/images/goblin_sheet.png'),
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

void _report(String name, void Function() run) {
  for (var i = 0; i < _warmUp; i++) {
    run();
  }
  final times = <double>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < _runs; i++) {
    stopwatch
      ..reset()
      ..start();
    run();
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds / 1000);
  }
  times.sort();
  final median = times[times.length ~/ 2];
  final p95 = times[(times.length * 0.95).floor() - 1];
  stdout.writeln(
    '$name: median ${median.toStringAsFixed(2)} ms, '
    'p95 ${p95.toStringAsFixed(2)} ms ($_runs runs)',
  );
}

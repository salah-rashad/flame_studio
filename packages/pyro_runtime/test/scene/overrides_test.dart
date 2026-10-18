import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'fixtures.dart';

const _goblin = NodeId('e1');
const _player = NodeId('p1');

void main() {
  late String text;
  late Scene scene;

  setUp(() {
    text = readFixture('canonical/overrides.scene.json');
    scene = SceneCodec.decode(text).scene;
  });

  test('round-trips byte for byte', () {
    expect(SceneCodec.encode(scene), text);
  });

  test('holds exactly the written fields (FR-009)', () {
    final player = scene.nodes[_player]! as CustomNode;
    expect(player.fields.values.keys, [
      'alive',
      'direction',
      'ghost',
      'greeting',
      'hitEffect',
      'legacyField',
      'maxHealth',
      'mode',
      'scale',
      'speed',
      'target',
      'tint',
    ]);
  });

  test('keeps an Override equal to its default, and unknown fields', () {
    final player = scene.nodes[_player]! as CustomNode;
    // maxHealth defaults to 5 in code; it is still an Override.
    expect(player.fields['maxHealth'], 5);
    expect(player.fields['legacyField'], 3);
  });

  test('removing an Override removes its key (FR-010)', () {
    final player = scene.nodes[_player]! as CustomNode;
    final reset = player.copyWith(fields: player.fields.reset('speed'));
    final output = SceneCodec.encode(
      scene.copyWith(nodes: {...scene.nodes, _player: reset}),
    );
    final reread =
        SceneCodec.decode(output).scene.nodes[_player]! as CustomNode;
    expect(reread.fields.contains('speed'), isFalse);
    expect(output.split('\n'), hasLength(text.split('\n').length - 1));
  });

  test('adding an Override writes it, even at the default value', () {
    final goblin = scene.nodes[_goblin]! as EntityNode;
    final patrol = goblin.behaviors.first;
    final updated = goblin.copyWith(
      behaviors: [
        patrol.copyWith(fields: patrol.fields.put('speed', 50)),
        ...goblin.behaviors.skip(1),
      ],
    );
    final output = SceneCodec.encode(
      scene.copyWith(nodes: {...scene.nodes, _goblin: updated}),
    );
    expect(output, contains('            "speed": 50,\n'));
  });

  test('keeps Behaviors in order, with their unknown keys', () {
    final goblin = scene.nodes[_goblin]! as EntityNode;
    expect(goblin.behaviors.map((b) => b.type), ['Patrol', 'Attack']);
    expect(goblin.behaviors[1].extra, {'enabled': false});
    expect(goblin.behaviors[1].fields['damage'], 2);
    final player = scene.nodes[_player]! as CustomNode;
    expect(player.behaviors.single.type, const TypeId('Blink'));
    expect(player.behaviors.single.fields.isEmpty, isTrue);
  });

  group('tagged references', () {
    test('EntityRef reads and writes {"ref": id}', () {
      final player = scene.nodes[_player]! as CustomNode;
      final ref = EntityRef.fromJson(player.fields['target']);
      expect(ref, const EntityRef(_goblin));
      expect(ref!.toJson(), {'ref': 'e1'});
    });

    test('a reference to a missing Node is kept as written', () {
      final player = scene.nodes[_player]! as CustomNode;
      expect(
        EntityRef.fromJson(player.fields['ghost']),
        const EntityRef(NodeId('missing-node')),
      );
    });

    test('AssetRef reads and writes {"asset": path}', () {
      final player = scene.nodes[_player]! as CustomNode;
      final ref = AssetRef.fromJson(player.fields['hitEffect']);
      expect(ref, const AssetRef(AssetPath('assets/images/fx.png')));
      expect(ref!.toJson(), {'asset': 'assets/images/fx.png'});
    });

    test('anything else is not a reference', () {
      for (final value in <Object?>[
        null,
        'e1',
        3,
        <String, Object?>{},
        {'ref': 3},
        {'ref': ''},
        {'ref': 'e1', 'extra': true},
        {'asset': 'a.png', 'ref': 'e1'},
      ]) {
        expect(EntityRef.fromJson(value), isNull, reason: '$value');
        expect(AssetRef.fromJson(value), isNull, reason: '$value');
      }
    });
  });

  test('a Behavior without a type is refused, naming the Node and key', () {
    const text =
        '{"schemaVersion": 1, "rootId": "r", "nodes": {'
        '"r": {"kind": "root", "childIds": ["e"]},'
        '"e": {"kind": "entity", "name": "goblin", "behaviors": [{"fields": {}}],'
        '"transform": {"anchor": "center", "angle": 0, "position": [0, 0],'
        '"scale": [1, 1], "size": [1, 1]}}}}';
    expect(
      () => SceneCodec.decode(text),
      throwsA(
        isA<InvalidNode>()
            .having((e) => e.nodeId, 'nodeId', const NodeId('e'))
            .having((e) => e.key, 'key', 'behaviors[0].type'),
      ),
    );
  });

  test('fields that are not an object are refused', () {
    const text =
        '{"schemaVersion": 1, "rootId": "r", "nodes": {'
        '"r": {"kind": "root", "childIds": ["p"]},'
        '"p": {"kind": "custom", "type": "Player", "fields": [1],'
        '"transform": {"anchor": "center", "angle": 0, "position": [0, 0],'
        '"scale": [1, 1], "size": [1, 1]}}}}';
    expect(
      () => SceneCodec.decode(text),
      throwsA(isA<InvalidNode>().having((e) => e.key, 'key', 'fields')),
    );
  });
}

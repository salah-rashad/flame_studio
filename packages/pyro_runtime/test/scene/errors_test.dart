import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'fixtures.dart';

void main() {
  group('invalid files are refused, naming what and where (FR-026)', () {
    for (final (name, type, mentions)
        in <(String, TypeMatcher<Object>, List<String>)>[
          ('malformed', isA<MalformedJson>(), ['line 1']),
          ('duplicate_node_id', isA<DuplicateKey>(), ['"root"', '"nodes"']),
          (
            'duplicate_key_in_transform',
            isA<DuplicateKey>(),
            ['"angle"', 'nodes.e1.transform'],
          ),
          ('missing_root_id', isA<InvalidRoot>(), ['rootId']),
          ('root_id_unknown', isA<InvalidRoot>(), ['"nope"']),
          ('root_wrong_kind', isA<InvalidRoot>(), ['"e1"', '"entity"']),
          ('two_roots', isA<InvalidRoot>(), ['"root"', '"other"']),
          (
            'custom_without_type',
            isA<InvalidNode>(),
            ['"p1"', '("player")', '"type"'],
          ),
          (
            'vector_one_number',
            isA<InvalidNode>(),
            ['"e1"', '("goblin")', '"transform.position"'],
          ),
          ('vector_string', isA<InvalidNode>(), ['"e1"', '"transform.size"']),
          ('negative_radius', isA<InvalidNode>(), ['"c1"', '"props.radius"']),
          (
            'bad_collision_type',
            isA<InvalidNode>(),
            ['"h1"', '"props.collisionType"', 'sometimes'],
          ),
          (
            'bad_anchor_name',
            isA<InvalidNode>(),
            ['"transform.anchor"', 'middle'],
          ),
          (
            'src_position_without_size',
            isA<InvalidNode>(),
            ['"s1"', 'srcSize'],
          ),
          ('kind_not_string', isA<InvalidNode>(), ['"e1"', '"kind"']),
          ('nodes_not_object', isA<InvalidRoot>(), ['nodes']),
          ('empty_node_id', isA<InvalidNode>(), ['empty']),
          ('child_ids_not_list', isA<InvalidNode>(), ['"root"', '"childIds"']),
          (
            'child_id_not_string',
            isA<InvalidNode>(),
            ['"root"', '"childIds[1]"'],
          ),
          ('tags_not_strings', isA<InvalidNode>(), ['"e1"', '"tags[1]"']),
        ]) {
      test(name, () {
        final text = readFixture('invalid/$name.scene.json');
        expect(
          () => SceneCodec.decode(text),
          throwsA(
            type.having(
              (e) => e.toString(),
              'toString()',
              allOf([for (final m in mentions) contains(m)]),
            ),
          ),
        );
      });
    }
  });

  test('a NaN can\'t be written, and the error names the Node and key', () {
    final scene = SceneCodec.decode(
      readFixture('canonical/entity.scene.json'),
    ).scene;
    final goblin = scene.nodes[const NodeId('e1')]! as EntityNode;
    final broken = scene.copyWith(
      nodes: {
        ...scene.nodes,
        goblin.id: goblin.copyWith(
          transform: goblin.transform.copyWith(angle: double.nan),
        ),
      },
    );
    expect(
      () => SceneCodec.encode(broken),
      throwsA(
        isA<UnwritableValue>()
            .having((e) => e.nodeId, 'nodeId', const NodeId('e1'))
            .having((e) => e.key, 'key', 'transform.angle'),
      ),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_runtime/src/scene/json/json_equality.dart';
import 'package:pyro_runtime/src/scene/json/strict_reader.dart';

import 'fixtures.dart';

NodeId _id(String value) => NodeId(value);

/// The expected issues per damaged fixture, in discovery order.
final Map<String, List<TreeIssue>> _expectedIssues = {
  'missing_child': [MissingChild(parentId: _id('root'), childId: _id('ghost'))],
  'self_child': [SelfChild(nodeId: _id('a'))],
  'root_as_child': [RootAsChild(parentId: _id('a'), rootId: _id('root'))],
  'duplicate_child': [DuplicateChild(parentId: _id('root'), childId: _id('a'))],
  'multiple_parents': [
    MultipleParents(
      nodeId: _id('c'),
      keptParentId: _id('a'),
      removedFromParentId: _id('b'),
    ),
  ],
  'orphans': [
    OrphanAttached(nodeId: _id('m')),
    OrphanAttached(nodeId: _id('z')),
  ],
  'cycle_unreachable': [
    CycleBroken(
      nodeIds: [_id('p'), _id('q')],
      attachedNodeId: _id('p'),
      removedFromParentId: _id('q'),
    ),
  ],
  'cycle_with_tail': [
    CycleBroken(
      nodeIds: [_id('b'), _id('c1'), _id('c2')],
      attachedNodeId: _id('c1'),
      removedFromParentId: _id('c2'),
    ),
  ],
  'cycle_reachable': [
    MultipleParents(
      nodeId: _id('a'),
      keptParentId: _id('root'),
      removedFromParentId: _id('b'),
    ),
  ],
  'merge_moved_and_deleted': [
    MissingChild(parentId: _id('root'), childId: _id('ghost')),
    MultipleParents(
      nodeId: _id('c'),
      keptParentId: _id('a'),
      removedFromParentId: _id('b'),
    ),
    OrphanAttached(nodeId: _id('e')),
  ],
};

Map<String, Object?> _nodesJson(String text) =>
    (readStrictJson(text)! as Map<String, Object?>)['nodes']!
        as Map<String, Object?>;

Map<String, Object?> _withoutChildIds(Object? node) => {
  for (final MapEntry(:key, :value) in (node! as Map<String, Object?>).entries)
    if (key != 'childIds') key: value,
};

void main() {
  final damaged = fixtureNames(
    'damaged',
  ).where((name) => name != 'healthy.scene.json');

  test('every damaged fixture has expected issues', () {
    expect(
      damaged.map((name) => name.replaceFirst('.scene.json', '')).toSet(),
      _expectedIssues.keys.toSet(),
    );
  });

  for (final name in damaged) {
    final key = name.replaceFirst('.scene.json', '');
    group(key, () {
      late String input;
      late SceneReadResult result;
      late String output;

      setUp(() {
        input = readFixture('damaged/$name');
        result = SceneCodec.decode(input);
        output = SceneCodec.encode(result.scene);
      });

      test('repairs to the expected tree', () {
        expect(output, readExpected('damaged', name));
      });

      test('reports the expected issues in order (FR-024)', () {
        expect(
          result.repairs.issues.map((issue) => issue.description),
          _expectedIssues[key]!.map((issue) => issue.description),
        );
        expect(
          result.repairs.issues.map((issue) => issue.runtimeType),
          _expectedIssues[key]!.map((issue) => issue.runtimeType),
        );
      });

      test('changes only childIds lists (FR-023)', () {
        final before = _nodesJson(input);
        final after = _nodesJson(output);
        expect(after.keys.toSet(), before.keys.toSet());
        for (final id in before.keys) {
          expect(
            jsonEquals(
              _withoutChildIds(before[id]),
              _withoutChildIds(after[id]),
            ),
            isTrue,
            reason: 'Node "$id" changed outside childIds',
          );
        }
      });

      test('repairs the same way every time (FR-022)', () {
        expect(SceneCodec.encode(SceneCodec.decode(input).scene), output);
      });

      test('describes each issue on one line, with its Node IDs', () {
        final lines = result.repairs.describe().split('\n');
        expect(lines, hasLength(result.repairs.issues.length));
        expect(result.repairs.isEmpty, isFalse);
      });
    });
  }

  test('a healthy file reports nothing', () {
    final result = SceneCodec.decode(readFixture('damaged/healthy.scene.json'));
    expect(result.repairs.isEmpty, isTrue);
    expect(result.repairs.describe(), isEmpty);
  });

  test('a 10,000-deep chain is read without overflowing the stack', () {
    const depth = 10000;
    final nodes = StringBuffer('"root": {"kind": "root", "childIds": ["n0"]}');
    for (var i = 0; i < depth; i++) {
      final child = i + 1 < depth ? '"childIds": ["n${i + 1}"], ' : '';
      nodes.write(
        ', "n$i": {"kind": "entity", $child"transform": {"anchor": "topLeft",'
        ' "angle": 0, "position": [0, 0], "scale": [1, 1], "size": [1, 1]}}',
      );
    }
    // An orphaned, deep chain exercises the repair walk as well.
    final text =
        '{"schemaVersion": 1, "rootId": "root", "nodes": {'
        '${nodes.toString().replaceFirst('"childIds": ["n0"]', '"childIds": []')}}}';
    final result = SceneCodec.decode(text);
    expect(result.scene.nodes, hasLength(depth + 1));
    expect(result.repairs.issues.single, isA<OrphanAttached>());
    expect(result.scene.parentOf(_id('n${depth - 1}')), _id('n${depth - 2}'));
  });
}

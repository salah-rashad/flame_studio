import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../support/loader_fixtures.dart';
import '../support/scene_text.dart';
import '../support/test_registry.dart';

/// Root → `holder` (`Ghost` Behavior and `AllFields`), `boss` (an unknown
/// Custom component) → `minion` → `pet`, `portal` (an unknown kind), and
/// `ref` whose `AllFields.target` points at `minion`.
String _scene() {
  final unknownKind = SceneCodec.decode(
    '{"schemaVersion": 1, "rootId": "r", "nodes": {'
    '"r": {"kind": "root", "childIds": ["portal"]},'
    '"portal": {"kind": "prefabInstance", "name": "portal"}}}',
  ).scene.nodes[const NodeId('portal')]!;
  return sceneJson([
    RootNode(
      id: const NodeId('root'),
      childIds: const [
        NodeId('holder'),
        NodeId('boss'),
        NodeId('portal'),
        NodeId('ref'),
      ],
    ),
    EntityNode(
      id: const NodeId('holder'),
      name: 'holder',
      transform: at(0, 0),
      behaviors: [
        BehaviorAttachment(type: const TypeId('Ghost')),
        BehaviorAttachment(type: const TypeId('AllFields')),
      ],
    ),
    CustomNode(
      id: const NodeId('boss'),
      name: 'boss',
      type: const TypeId('Boss'),
      transform: at(0, 0),
      childIds: const [NodeId('minion')],
    ),
    EntityNode(
      id: const NodeId('minion'),
      name: 'minion',
      transform: at(0, 0),
      childIds: const [NodeId('pet')],
    ),
    EntityNode(id: const NodeId('pet'), name: 'pet', transform: at(0, 0)),
    unknownKind,
    EntityNode(
      id: const NodeId('ref'),
      name: 'ref',
      transform: at(0, 0),
      behaviors: [
        BehaviorAttachment(
          type: const TypeId('AllFields'),
          fields: Overrides(const {
            'target': {'ref': 'minion'},
            'gone': 1,
          }),
        ),
      ],
    ),
  ]);
}

Future<PyroScene> _load(String scene, UnknownType policy) async =>
    PyroScene.load(
      scenePath,
      registry: testRegistry,
      onUnknownType: policy,
      assets: await sourceFor(scene),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = [];
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() => debugPrint = original);

  group('US2 #1, #3 by default, unknown types fail the load', () {
    String only(List<Node> nodes) => sceneJson([
      RootNode(
        id: const NodeId('root'),
        childIds: [for (final node in nodes) node.id],
      ),
      ...nodes,
    ]);

    test('an unknown Behavior', () async {
      final scene = only([
        EntityNode(
          id: const NodeId('e1'),
          name: 'goblin_1',
          transform: at(0, 0),
          behaviors: [BehaviorAttachment(type: const TypeId('Patrol'))],
        ),
      ]);
      await expectLater(
        _load(scene, UnknownType.error),
        throwsA(
          isA<SceneLoadException>()
              .having((e) => e.typeId, 'typeId', 'Patrol')
              .having((e) => e.nodeName, 'nodeName', 'goblin_1')
              .having(
                (e) => e.toString(),
                'toString()',
                allOf(contains('"Patrol"'), contains('UnknownType.skip')),
              ),
        ),
      );
    });

    test('an unknown Custom component', () async {
      final scene = only([
        CustomNode(
          id: const NodeId('b1'),
          name: 'boss',
          type: const TypeId('Boss'),
          transform: at(0, 0),
        ),
      ]);
      await expectLater(
        _load(scene, UnknownType.error),
        throwsA(
          isA<SceneLoadException>().having((e) => e.typeId, 'typeId', 'Boss'),
        ),
      );
    });

    test('an unknown Node kind', () async {
      await expectLater(
        _load(_scene(), UnknownType.error),
        throwsA(isA<SceneLoadException>()),
      );
      final kind = SceneCodec.encode(
        SceneCodec.decode(
          '{"schemaVersion": 1, "rootId": "r", "nodes": {'
          '"r": {"kind": "root", "childIds": ["u"]},'
          '"u": {"kind": "prefabInstance", "name": "portal"}}}',
        ).scene,
      );
      await expectLater(
        _load(kind, UnknownType.error),
        throwsA(
          isA<SceneLoadException>().having(
            (e) => e.toString(),
            'toString()',
            allOf(contains('"prefabInstance"'), contains('UnknownType.skip')),
          ),
        ),
      );
    });

    test('a role mismatch fails under both policies', () async {
      final scene = only([
        CustomNode(
          id: const NodeId('c1'),
          name: 'odd',
          type: const TypeId('AllFields'),
          transform: at(0, 0),
        ),
      ]);
      for (final policy in UnknownType.values) {
        await expectLater(
          _load(scene, policy),
          throwsA(
            isA<SceneLoadException>().having(
              (e) => e.toString(),
              'toString()',
              contains('Behavior'),
            ),
          ),
          reason: '$policy',
        );
      }
    });
  });

  group('US2 #2, #3, #8 under UnknownType.skip', () {
    late PyroScene scene;

    setUp(() async => scene = await _load(_scene(), UnknownType.skip));

    test('an unknown Behavior is left out and its Node kept', () {
      final holder = scene.find<PyroEntity>('holder');
      expect(holder.children.single, isA<AllFields>());
    });

    test('an unknown Custom component is left out with its subtree', () {
      expect(scene.findAll(name: 'boss'), isEmpty);
      expect(scene.findAll(name: 'minion'), isEmpty);
      expect(scene.findAll(name: 'pet'), isEmpty);
    });

    test('an unknown kind is left out', () {
      expect(scene.findAll(name: 'portal'), isEmpty);
      expect(scene.findAll<PyroEntity>(), hasLength(2));
    });

    test('a reference to a left-out Node is null', () {
      final ref = scene.find<PyroEntity>('ref');
      expect(ref.findBehavior<AllFields>().target, isNull);
    });

    test('one warning lists everything left out', () {
      final skips = printed.where((p) => p.contains('left')).toList();
      expect(skips, hasLength(1));
      expect(
        skips.single,
        allOf([
          contains(scenePath),
          contains('Behavior "Ghost"'),
          contains('Custom component "Boss"'),
          contains('"prefabInstance"'),
          contains('AllFields.target'),
          contains('"ref" (ref)'),
        ]),
      );
    });
  });

  test('US2 #6 an Override for a field no code has warns once', () async {
    await _load(_scene(), UnknownType.skip);
    final unused = printed.where((p) => p.contains('ignored')).toList();
    expect(unused, hasLength(1));
    expect(
      unused.single,
      allOf(
        contains(scenePath),
        contains('"ref" (ref)'),
        contains('AllFields.gone'),
      ),
    );
  });
}

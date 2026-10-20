import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../support/loader_fixtures.dart';
import '../support/memory_asset_source.dart';
import '../support/scene_text.dart';
import '../support/test_registry.dart';

/// A Scene of one entity `holder` (`AllFields` with [fields]) and a
/// `player`, unless [nodes] replaces them.
String _scene({Map<String, Object?> fields = const {}, List<Node>? nodes}) =>
    sceneJson([
      RootNode(
        id: const NodeId('root'),
        childIds: [
          for (final node in nodes ?? _holder(fields))
            if (node is! RootNode && !_nested.contains(node.id)) node.id,
        ],
      ),
      ...?nodes,
      if (nodes == null) ..._holder(fields),
    ]);

const _nested = {NodeId('child'), NodeId('grandchild')};

List<Node> _holder(Map<String, Object?> fields) => [
  EntityNode(
    id: const NodeId('e1'),
    name: 'holder',
    transform: at(0, 0),
    behaviors: [
      BehaviorAttachment(
        type: const TypeId('AllFields'),
        fields: Overrides(fields),
      ),
    ],
  ),
  CustomNode(
    id: const NodeId('p1'),
    name: 'player',
    type: const TypeId('Player'),
    transform: at(0, 0),
  ),
];

Future<PyroScene> _load(
  String scene, {
  Map<String, String> texts = const {},
}) async => PyroScene.load(
  scenePath,
  registry: testRegistry,
  assets: await sourceFor(scene, texts: texts),
);

/// A matcher for a SceneLoadException naming the Scene and every part
/// given.
Matcher _fails({
  String? node,
  String? nodeName,
  String? typeId,
  String? field,
  String? asset,
  List<String> mentions = const [],
  TypeMatcher<Object>? cause,
}) => throwsA(
  isA<SceneLoadException>()
      .having((e) => e.scene, 'scene', scenePath)
      .having((e) => e.nodeId, 'nodeId', node)
      .having((e) => e.nodeName, 'nodeName', nodeName)
      .having((e) => e.typeId, 'typeId', typeId)
      .having((e) => e.field, 'field', field)
      .having((e) => e.asset, 'asset', asset)
      .having((e) => e.cause, 'cause', cause ?? anything)
      .having(
        (e) => e.toString(),
        'toString()',
        allOf([
          startsWith(scenePath),
          if (nodeName != null) contains('"$nodeName" ($node)'),
          for (final mention in mentions) contains(mention),
        ]),
      ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DebugPrintCallback original;

  setUp(() {
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
  });

  tearDown(() => debugPrint = original);

  group('US2 value mismatches (#4)', () {
    final cases = <String, (Map<String, Object?>, String, List<String>)>{
      'a fraction for an int': ({'count': 1.5}, 'count', ['1.5', 'an int']),
      'a string for a bool': ({'active': 'yes'}, 'active', ['"yes"']),
      'an unknown enum value': ({'mode': 'c'}, 'mode', ['"c"', 'one of a, b']),
      'a malformed colour': ({'tint': '#FF8800'}, 'tint', ['#AARRGGBB']),
      'null for a non-nullable field': (
        {'count': null},
        'count',
        ["isn't nullable"],
      ),
      'a SpriteAnimation without an animation name': (
        {
          'effect': {'asset': fxAnim},
        },
        'effect',
        ['"animation": name'],
      ),
    };
    for (final MapEntry(key: name, value: (fields, field, mentions))
        in cases.entries) {
      test(name, () async {
        await expectLater(
          _load(_scene(fields: fields)),
          _fails(
            node: 'e1',
            nodeName: 'holder',
            typeId: 'AllFields',
            field: field,
            mentions: ['AllFields.$field', ...mentions],
          ),
        );
      });
    }
  });

  test('US2 #5 lossless numbers load silently', () async {
    final scene = await _load(_scene(fields: {'speed': 80, 'count': 2.0}));
    expect(scene.find<PyroEntity>('holder').children.single, isA<AllFields>());
  });

  group('US2 #7 references', () {
    test('to a Node that isn\'t in the Scene', () async {
      await expectLater(
        _load(
          _scene(
            fields: {
              'target': {'ref': 'ghost'},
            },
          ),
        ),
        _fails(
          node: 'e1',
          nodeName: 'holder',
          typeId: 'AllFields',
          field: 'target',
          mentions: ['"ghost"'],
        ),
      );
    });

    test('to a Node of a type the field doesn\'t accept', () async {
      final registry = PyroRegistry([
        for (final type in testRegistry.types)
          if (type.id == 'AllFields')
            RegistryType(
              id: type.id,
              role: type.role,
              create: type.create,
              acceptsParent: type.acceptsParent,
              fields: {
                ...type.fields,
                'target': RegistryField(
                  name: 'target',
                  type: FieldType.entityRef,
                  nullable: true,
                  accepts: (v) => v == null || v is Player,
                  set: (t, v) => (t as AllFields).target = v as Player?,
                ),
              },
            )
          else
            type,
      ]);
      await expectLater(
        PyroScene.load(
          scenePath,
          registry: registry,
          assets: await sourceFor(
            _scene(
              fields: {
                'target': {'ref': 'e1'},
              },
            ),
          ),
        ),
        _fails(
          node: 'e1',
          nodeName: 'holder',
          typeId: 'AllFields',
          field: 'target',
          mentions: ['"e1"', 'PyroEntity', "doesn't accept"],
        ),
      );
    });
  });

  group('US2 #9 assets', () {
    test('a missing image', () async {
      final scene = sceneJson([
        RootNode(id: const NodeId('root'), childIds: const [NodeId('s')]),
        SpriteNode(
          id: const NodeId('s'),
          name: 'sprite',
          transform: at(0, 0),
          image: const AssetPath('assets/images/missing.png'),
        ),
      ]);
      await expectLater(
        _load(scene),
        _fails(
          node: 's',
          nodeName: 'sprite',
          asset: 'assets/images/missing.png',
          cause: isA<FlutterError>(),
        ),
      );
    });

    test('a missing animation file', () async {
      await expectLater(
        _load(
          _scene(
            fields: {
              'effect': {
                'asset': 'assets/anims/missing.anim.json',
                'animation': 'walk',
              },
            },
          ),
        ),
        _fails(
          node: 'e1',
          nodeName: 'holder',
          typeId: 'AllFields',
          field: 'effect',
          asset: 'assets/anims/missing.anim.json',
        ),
      );
    });

    test('a malformed animation file', () async {
      await expectLater(
        _load(
          _scene(
            fields: {
              'effect': {
                'asset': 'assets/anims/bad.anim.json',
                'animation': 'walk',
              },
            },
          ),
          texts: {'assets/anims/bad.anim.json': '{"schemaVersion": 1}'},
        ),
        _fails(
          node: 'e1',
          nodeName: 'holder',
          typeId: 'AllFields',
          field: 'effect',
          asset: 'assets/anims/bad.anim.json',
          mentions: ["isn't a valid animation file"],
          cause: isA<SceneFormatException>(),
        ),
      );
    });

    test('an animation the file doesn\'t hold lists those it does', () async {
      await expectLater(
        _load(
          _scene(
            fields: {
              'effect': {'asset': fxAnim, 'animation': 'run'},
            },
          ),
        ),
        _fails(
          node: 'e1',
          nodeName: 'holder',
          typeId: 'AllFields',
          field: 'effect',
          asset: fxAnim,
          mentions: ['"run"', '"idle", "walk"'],
        ),
      );
    });
  });

  group('US2 #10 Behavior parents', () {
    test('Behaviors on a component that can\'t hold them', () async {
      final scene = _scene(
        nodes: [
          CustomNode(
            id: const NodeId('c1'),
            name: 'plain',
            type: const TypeId('Plain'),
            transform: at(0, 0),
            behaviors: [BehaviorAttachment(type: const TypeId('AllFields'))],
          ),
        ],
      );
      await expectLater(
        _load(scene),
        _fails(
          node: 'c1',
          nodeName: 'plain',
          typeId: 'AllFields',
          mentions: ["can't hold Behaviors", 'EntityMixin'],
        ),
      );
    });

    test('a Behavior on a Node of the wrong parent type', () async {
      final scene = _scene(
        nodes: [
          CustomNode(
            id: const NodeId('p1'),
            name: 'player',
            type: const TypeId('Player'),
            transform: at(0, 0),
            behaviors: [BehaviorAttachment(type: const TypeId('EnemyOnly'))],
          ),
        ],
      );
      await expectLater(
        _load(scene),
        _fails(
          node: 'p1',
          nodeName: 'player',
          typeId: 'EnemyOnly',
          mentions: ['parent type'],
        ),
      );
    });
  });

  group('US2 #11 the Scene file itself', () {
    test('missing', () async {
      final source = MemoryAssetSource();
      await expectLater(
        PyroScene.load(scenePath, registry: testRegistry, assets: source),
        _fails(asset: scenePath, mentions: ["couldn't be read"]),
      );
    });

    test('malformed JSON', () async {
      await expectLater(
        _load('{"schemaVersion": 1,'),
        _fails(cause: isA<MalformedJson>(), mentions: ['line 1']),
      );
    });

    test('a newer schemaVersion', () async {
      await expectLater(
        _load('{"schemaVersion": 2, "rootId": "r", "nodes": {}}'),
        _fails(
          cause: isA<UnsupportedSchemaVersion>(),
          mentions: ['schemaVersion 2'],
        ),
      );
    });
  });

  group('US2 #12 user code that throws', () {
    test('a constructor', () async {
      final scene = _scene(
        nodes: [
          EntityNode(
            id: const NodeId('e1'),
            name: 'holder',
            transform: at(0, 0),
            behaviors: [BehaviorAttachment(type: const TypeId('Throwing'))],
          ),
        ],
      );
      await expectLater(
        _load(scene),
        _fails(
          node: 'e1',
          nodeName: 'holder',
          typeId: 'Throwing',
          cause: isA<StateError>(),
          mentions: ['constructor'],
        ),
      );
    });

    test('a setter', () async {
      final scene = _scene(
        nodes: [
          CustomNode(
            id: const NodeId('b1'),
            name: 'bad',
            type: const TypeId('BadSetter'),
            transform: at(0, 0),
            fields: Overrides(const {'value': 1}),
          ),
        ],
      );
      await expectLater(
        _load(scene),
        _fails(
          node: 'b1',
          nodeName: 'bad',
          typeId: 'BadSetter',
          field: 'value',
          cause: isA<StateError>(),
          mentions: ['setter'],
        ),
      );
    });
  });

  test('a causing error keeps its stack trace', () async {
    try {
      await _load('{"schemaVersion": 1,');
      fail('expected a SceneLoadException');
    } on SceneLoadException catch (error) {
      expect(error.causeStackTrace, isNotNull);
    }
  });

  testWithFlameGame('FR-004: a failed load leaves nothing in the game', (
    game,
  ) async {
    final future = _load(_scene(fields: {'count': 1.5}));
    await expectLater(future, throwsA(isA<SceneLoadException>()));
    await game.ready();
    expect(game.children.whereType<PyroScene>(), isEmpty);
  });
}

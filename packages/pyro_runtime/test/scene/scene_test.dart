import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

NodeId _id(String value) => NodeId(value);

List<NodeId> _ids(List<String> values) => [for (final v in values) NodeId(v)];

final _transform = NodeTransform(size: const Vec2(32, 32));

EntityNode _entity(String id, [List<String> children = const []]) =>
    EntityNode(id: _id(id), childIds: _ids(children), transform: _transform);

RootNode _root(String id, List<String> children) =>
    RootNode(id: _id(id), childIds: _ids(children));

Scene _scene(String rootId, List<Node> nodes) =>
    Scene(rootId: _id(rootId), nodes: {for (final n in nodes) n.id: n});

void main() {
  group('Scene invariants', () {
    test('a valid tree is accepted', () {
      final scene = _scene('r', [
        _root('r', ['a', 'b']),
        _entity('a', ['c']),
        _entity('b'),
        _entity('c'),
      ]);
      expect(scene.root.id, _id('r'));
      expect(scene.nodes, hasLength(4));
    });

    for (final (name, rootId, nodes) in <(String, String, List<Node>)>[
      ('no root Node', 'a', [_entity('a')]),
      (
        'rootId names a Node that is not the root',
        'a',
        [
          _root('r', ['a']),
          _entity('a'),
        ],
      ),
      ('rootId names no Node', 'x', [_root('r', [])]),
      ('two roots', 'r', [_root('r', []), _root('s', [])]),
      (
        'a child ID with no Node',
        'r',
        [
          _root('r', ['a', 'ghost']),
          _entity('a'),
        ],
      ),
      (
        'a Node under two parents',
        'r',
        [
          _root('r', ['a', 'b']),
          _entity('a', ['c']),
          _entity('b', ['c']),
          _entity('c'),
        ],
      ),
      (
        'a Node twice in one list',
        'r',
        [
          _root('r', ['a', 'a']),
          _entity('a'),
        ],
      ),
      (
        'the root listed as a child',
        'r',
        [
          _root('r', ['a']),
          _entity('a', ['r']),
        ],
      ),
      ('an unreachable Node', 'r', [_root('r', []), _entity('a')]),
      (
        'an unreachable cycle',
        'r',
        [
          _root('r', []),
          _entity('a', ['b']),
          _entity('b', ['a']),
        ],
      ),
    ]) {
      test('$name is refused', () {
        expect(() => _scene(rootId, nodes), throwsArgumentError);
      });
    }

    test('a map key that differs from the Node ID is refused', () {
      expect(
        () => Scene(
          rootId: _id('r'),
          nodes: {_id('r'): _root('r', []), _id('x'): _entity('a')},
        ),
        throwsArgumentError,
      );
    });

    test('the nodes map is unmodifiable', () {
      final scene = _scene('r', [_root('r', [])]);
      expect(
        () => scene.nodes[_id('a')] = _entity('a'),
        throwsUnsupportedError,
      );
    });
  });

  test('parentOf is derived from childIds', () {
    final scene = _scene('r', [
      _root('r', ['a']),
      _entity('a', ['b']),
      _entity('b'),
    ]);
    expect(scene.parentOf(_id('r')), isNull);
    expect(scene.parentOf(_id('a')), _id('r'));
    expect(scene.parentOf(_id('b')), _id('a'));
  });

  group('copyWith', () {
    test('changes only the given fields', () {
      final entity = EntityNode(
        id: _id('a'),
        name: 'goblin',
        tags: const ['enemy'],
        transform: _transform,
      );
      final moved = entity.copyWith(childIds: _ids(['b']));
      expect(moved.id, entity.id);
      expect(moved.name, 'goblin');
      expect(moved.tags, ['enemy']);
      expect(identical(moved.transform, entity.transform), isTrue);
      expect(moved.childIds, _ids(['b']));
    });

    test('can clear optional fields', () {
      final entity = EntityNode(id: _id('a'), name: 'x', transform: _transform);
      expect(entity.copyWith(clearName: true).name, isNull);
      final sprite = SpriteNode(
        id: _id('s'),
        transform: _transform,
        image: const AssetPath('assets/images/a.png'),
        region: const SpriteRegion(position: Vec2.zero, size: Vec2(8, 8)),
      );
      expect(sprite.copyWith(clearRegion: true).region, isNull);
    });

    test('exists on every Node kind', () {
      final nodes = <Node>[
        _root('r', []),
        _entity('e'),
        SpriteNode(
          id: _id('s'),
          transform: _transform,
          image: const AssetPath('a.png'),
        ),
        RectangleHitboxNode(id: _id('h'), size: const Vec2(4, 4)),
        CircleHitboxNode(id: _id('c'), radius: 3),
        CustomNode(
          id: _id('x'),
          type: const TypeId('Player'),
          transform: _transform,
        ),
        UnknownNode(id: _id('u'), kind: 'prefabInstance'),
      ];
      for (final node in nodes) {
        final copy = switch (node) {
          RootNode() => node.copyWith(childIds: _ids(['z'])),
          EntityNode() => node.copyWith(childIds: _ids(['z'])),
          SpriteNode() => node.copyWith(childIds: _ids(['z'])),
          RectangleHitboxNode() => node.copyWith(childIds: _ids(['z'])),
          CircleHitboxNode() => node.copyWith(childIds: _ids(['z'])),
          CustomNode() => node.copyWith(childIds: _ids(['z'])),
          UnknownNode() => node.copyWith(childIds: _ids(['z'])),
        };
        expect(copy.runtimeType, node.runtimeType);
        expect(copy.id, node.id);
        expect(copy.childIds, _ids(['z']));
      }
    });
  });

  group('equality', () {
    test('value types compare by value', () {
      expect(const Vec2(1, 2), const Vec2(1, 2));
      expect(const Vec2(1, 2), isNot(const Vec2(2, 1)));
      expect(
        NodeTransform(
          size: const Vec2(1, 1),
          extra: const {
            'z': [1],
          },
        ),
        NodeTransform(
          size: const Vec2(1, 1),
          extra: const {
            'z': [1],
          },
        ),
      );
      expect(
        NodeTransform(
          extra: const {
            'z': [1],
          },
        ),
        isNot(
          NodeTransform(
            extra: const {
              'z': [2],
            },
          ),
        ),
      );
      expect(NodeAnchor.center, NodeAnchor.byName('center'));
      expect(const NodeAnchor.custom(0.5, 0.5), isNot(NodeAnchor.center));
      expect(
        const SpriteRegion(position: Vec2.zero, size: Vec2(1, 1)),
        const SpriteRegion(position: Vec2.zero, size: Vec2(1, 1)),
      );
    });

    test('Nodes compare by identity', () {
      expect(_entity('a') == _entity('a'), isFalse);
    });
  });

  test('Node collections are unmodifiable', () {
    final entity = EntityNode(
      id: _id('a'),
      childIds: _ids(['b']),
      tags: ['t'],
      transform: _transform,
    );
    expect(() => entity.childIds.add(_id('c')), throwsUnsupportedError);
    expect(() => entity.tags.add('u'), throwsUnsupportedError);
  });
}

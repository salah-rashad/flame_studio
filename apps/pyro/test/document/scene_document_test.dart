import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/src/errors.dart';
import 'package:pyro/document/src/scene_document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/fixtures.dart';
import 'helpers/scenes.dart';

void main() {
  group('conversion', () {
    void expectFaithful(Scene scene) {
      final doc = SceneDocument.fromScene(scene);
      expect(doc.rootId, scene.rootId);
      expect(doc.nodes.length, scene.nodes.length);
      for (final MapEntry(:key, :value) in scene.nodes.entries) {
        expect(identical(doc.nodes[key], value), isTrue, reason: key);
        expect(doc.parentOf(key), scene.parentOf(key), reason: key);
      }
      expect(doc.parents.length, scene.nodes.length - 1);
      expect(doc.sceneExtra, scene.extra);
      expect(SceneCodec.encode(doc.toScene()), SceneCodec.encode(scene));
    }

    test('small scene', () => expectFaithful(smallScene()));

    for (final name in fixtureNames('canonical')) {
      test('fixture $name', () {
        final text = utf8.decode(readFixtureBytes('canonical/$name'));
        expectFaithful(SceneCodec.decode(text).scene);
      });
    }

    test('derived getters', () {
      final doc = SceneDocument.fromScene(smallScene());
      const root = NodeId('root');
      const a = NodeId('a');
      const a1 = NodeId('a1');
      const b = NodeId('b');
      const missing = NodeId('missing');

      expect(doc.node(a), isA<EntityNode>());
      expect(doc.node(missing), isNull);
      expect(doc.contains(a1), isTrue);
      expect(doc.contains(missing), isFalse);
      expect(doc.parentOf(root), isNull);
      expect(doc.parentOf(a1), a);
      expect(doc.parentOf(missing), isNull);
      expect(doc.childrenOf(root), [a, b]);
      expect(doc.childrenOf(a1), isEmpty);
      expect(doc.childrenOf(missing), isEmpty);
      expect(doc.isAncestor(root, a1), isTrue);
      expect(doc.isAncestor(a, a1), isTrue);
      expect(doc.isAncestor(a1, a), isFalse);
      expect(doc.isAncestor(b, a1), isFalse);
      expect(doc.isAncestor(a, a), isFalse);
    });
  });

  group('edits', () {
    const root = NodeId('root');
    const a = NodeId('a');
    const a1 = NodeId('a1');
    const b = NodeId('b');
    late SceneDocument doc;

    setUp(() => doc = SceneDocument.fromScene(smallScene()));

    void expectUntouched(SceneDocument next, Set<NodeId> changed) {
      for (final MapEntry(:key, :value) in doc.nodes.entries) {
        if (changed.contains(key) || !next.contains(key)) continue;
        expect(identical(next.node(key), value), isTrue, reason: '$key');
      }
    }

    test('addNode appends by default and inserts at an index', () {
      final added = doc.addNode(entity('c'), parentId: root);
      expect(added.childrenOf(root), [a, b, const NodeId('c')]);
      expect(added.parentOf(const NodeId('c')), root);
      expectUntouched(added, {root});
      expect(doc.childrenOf(root), [a, b], reason: 'the old state is kept');

      final first = doc.addNode(entity('c'), parentId: root, index: 0);
      expect(first.childrenOf(root), [const NodeId('c'), a, b]);
      final under = doc.addNode(entity('c'), parentId: a1);
      expect(under.parentOf(const NodeId('c')), a1);
    });

    test('addNode refusals', () {
      expect(
        () => doc.addNode(entity('a'), parentId: root),
        throwsA(isA<DuplicateNodeId>()),
      );
      expect(
        () => doc.addNode(entity('c'), parentId: const NodeId('zz')),
        throwsA(isA<NodeNotFound>()),
      );
      expect(
        () => doc.addNode(RootNode(id: const NodeId('r2')), parentId: root),
        throwsA(isA<RootNotAllowed>()),
      );
      expect(
        () => doc.addNode(entity('c', children: ['d']), parentId: root),
        throwsA(isA<NodeHasChildren>()),
      );
      for (final index in [-1, 3]) {
        expect(
          () => doc.addNode(entity('c'), parentId: root, index: index),
          throwsA(
            isA<IndexOutOfRange>()
                .having((e) => e.length, 'length', 2)
                .having((e) => e.parentId, 'parentId', root),
          ),
        );
      }
    });

    test('removeNode removes the whole subtree', () {
      final removed = doc.removeNode(a);
      expect(removed.contains(a), isFalse);
      expect(removed.contains(a1), isFalse);
      expect(removed.parentOf(a1), isNull);
      expect(removed.childrenOf(root), [b]);
      expect(removed.parents.length, removed.nodes.length - 1);
      expectUntouched(removed, {root});
    });

    test('removeNode refusals', () {
      expect(
        () => doc.removeNode(const NodeId('zz')),
        throwsA(isA<NodeNotFound>()),
      );
      expect(() => doc.removeNode(root), throwsA(isA<RootNotAllowed>()));
    });

    test('moveNode reparents, reorders and appends by default', () {
      final moved = doc.moveNode(a1, parentId: b);
      expect(moved.childrenOf(a), isEmpty);
      expect(moved.childrenOf(b), [a1]);
      expect(moved.parentOf(a1), b);
      expectUntouched(moved, {a, b});

      final reordered = doc.moveNode(b, parentId: root, index: 0);
      expect(reordered.childrenOf(root), [b, a]);
      final last = doc.moveNode(a, parentId: root);
      expect(last.childrenOf(root), [b, a]);
    });

    test('moveNode to the same place is a no-op', () {
      expect(identical(doc.moveNode(a, parentId: root, index: 0), doc), isTrue);
      expect(identical(doc.moveNode(b, parentId: root), doc), isTrue);
    });

    test('moveNode refusals', () {
      expect(
        () => doc.moveNode(const NodeId('zz'), parentId: root),
        throwsA(isA<NodeNotFound>()),
      );
      expect(
        () => doc.moveNode(a, parentId: const NodeId('zz')),
        throwsA(isA<NodeNotFound>()),
      );
      expect(
        () => doc.moveNode(root, parentId: a),
        throwsA(isA<RootNotAllowed>()),
      );
      expect(
        () => doc.moveNode(a, parentId: a1),
        throwsA(isA<MoveIntoOwnSubtree>()),
      );
      expect(
        () => doc.moveNode(a, parentId: a),
        throwsA(isA<MoveIntoOwnSubtree>()),
      );
      expect(
        () => doc.moveNode(a1, parentId: b, index: 1),
        throwsA(isA<IndexOutOfRange>()),
      );
    });

    test('replaceNode swaps the Node and keeps the others', () {
      final renamed = (doc.node(a)! as EntityNode).copyWith(name: 'hero');
      final next = doc.replaceNode(renamed);
      expect(identical(next.node(a), renamed), isTrue);
      expectUntouched(next, {a});
      expect(identical(next.parents, doc.parents), isTrue);
      expect(identical(doc.replaceNode(doc.node(a)!), doc), isTrue);
    });

    test('replaceNode refusals', () {
      expect(() => doc.replaceNode(entity('zz')), throwsA(isA<NodeNotFound>()));
      expect(
        () => doc.replaceNode(RootNode(id: a, childIds: const [a1])),
        throwsA(isA<RootNotAllowed>()),
      );
      expect(
        () => doc.replaceNode(entity('root', children: ['a', 'b'])),
        throwsA(isA<RootNotAllowed>()),
      );
      expect(
        () => doc.replaceNode(entity('a')),
        throwsA(isA<ChildrenChanged>()),
      );
    });

    test('random edits keep the tree valid', () {
      final random = Random(2);
      final newId = counterIds('r');
      var current = doc;
      for (var step = 0; step < 1000; step++) {
        final ids = current.nodes.keys.toList();
        NodeId pick() => random.nextInt(10) == 0
            ? const NodeId('zz')
            : ids[random.nextInt(ids.length)];
        final target = pick();
        final index = random.nextInt(5) - 1;
        try {
          current = switch (random.nextInt(4)) {
            0 => current.addNode(
              entity(newId()),
              parentId: target,
              index: index < 0 ? null : index,
            ),
            1 => current.removeNode(target),
            2 => current.moveNode(
              target,
              parentId: pick(),
              index: index < 0 ? null : index,
            ),
            _ => current.replaceNode(current.node(target) ?? entity(target)),
          };
        } on DocumentEditError {
          // Refused edits leave `current` as it was.
        }
        expect(() => current.toScene(), returnsNormally, reason: 'step $step');
        expect(current.parents.length, current.nodes.length - 1);
        for (final node in current.nodes.values) {
          for (final child in node.childIds) {
            expect(current.parentOf(child), node.id, reason: 'step $step');
          }
        }
      }
    });
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/helpers/scenes.dart';

/// The reconciler suite (spec 006, T023; `contracts/reconciler.md`): the
/// contract's five invariants as named tests, plus the plain add / remove /
/// patch cases.
void main() {
  SceneDocument small() => SceneDocument.fromScene(smallScene());

  EntityNode moved(EntityNode node, double x) =>
      node.copyWith(transform: node.transform.copyWith(position: Vec2(x, 0)));

  group('invariant 1 — identity skip', () {
    test('an identical document yields no ops', () {
      final doc = small();
      expect(reconcile(doc, doc), isEmpty);
    });

    test('an edit that leaves every Node identical yields no ops', () {
      final doc = small();
      final next = doc.moveNode(const NodeId('b'), parentId: doc.rootId);
      expect(reconcile(doc, next), isEmpty);
    });

    test('a same-Node reparent yields only ReparentNode', () {
      final doc = small();
      final next = doc.moveNode(const NodeId('b'), parentId: const NodeId('a'));
      expect(
        identical(doc.node(const NodeId('b')), next.node(const NodeId('b'))),
        isTrue,
      );
      expect(reconcile(doc, next), [
        const ReparentNode(NodeId('b'), parentId: NodeId('a'), index: 1),
      ]);
    });
  });

  group('invariant 2 — minimality', () {
    final big = SceneDocument.fromScene(generatedScene(1000));

    test('a one-Node edit in a 1,000-Node document yields one PatchNode', () {
      final node = big.node(const NodeId('e300'))! as EntityNode;
      final next = big.replaceNode(moved(node, 3));
      expect(reconcile(big, next), [const PatchNode(NodeId('e300'))]);
    });

    test('a move in a 1,000-Node document yields one ReparentNode', () {
      final next = big.moveNode(
        const NodeId('e5s'),
        parentId: const NodeId('e7'),
      );
      expect(reconcile(big, next), [
        const ReparentNode(NodeId('e5s'), parentId: NodeId('e7'), index: 2),
      ]);
    });
  });

  group('invariant 3 — order', () {
    test('a reorder within a parent is a ReparentNode with the new index', () {
      final doc = small();
      final next = doc.moveNode(
        const NodeId('b'),
        parentId: doc.rootId,
        index: 0,
      );
      expect(reconcile(doc, next), [
        const ReparentNode(NodeId('b'), parentId: NodeId('root'), index: 0),
      ]);
    });

    test('only the moved child gets an op when siblings shift', () {
      final doc = SceneDocument.fromScene(generatedScene(31)); // e0..e9
      final next = doc.moveNode(
        const NodeId('e9'),
        parentId: doc.rootId,
        index: 2,
      );
      expect(reconcile(doc, next), [
        const ReparentNode(NodeId('e9'), parentId: NodeId('root'), index: 2),
      ]);
    });

    test('inserting a sibling does not reparent the ones after it', () {
      final doc = small();
      final next = doc.addNode(entity('c'), parentId: doc.rootId, index: 0);
      expect(reconcile(doc, next), [
        AddNode(next.node(const NodeId('c'))!, parentId: doc.rootId, index: 0),
      ]);
    });
  });

  group('invariant 4 — subtree atomicity', () {
    test('removing a Node yields one RemoveNode for its whole subtree', () {
      final doc = small();
      final next = doc.removeNode(const NodeId('a'));
      expect(reconcile(doc, next), [const RemoveNode(NodeId('a'))]);
    });

    test('an added subtree yields one AddNode for its top', () {
      final doc = small();
      final next = doc
          .addNode(entity('x'), parentId: doc.rootId)
          .addNode(sprite('y'), parentId: const NodeId('x'));
      expect(reconcile(doc, next), [
        AddNode(next.node(const NodeId('x'))!, parentId: doc.rootId, index: 2),
      ]);
    });

    test('a Node moved out of a removed subtree is reparented first', () {
      final doc = small();
      final next = doc
          .moveNode(const NodeId('a1'), parentId: const NodeId('b'))
          .removeNode(const NodeId('a'));
      expect(reconcile(doc, next), [
        const ReparentNode(NodeId('a1'), parentId: NodeId('b'), index: 0),
        const RemoveNode(NodeId('a')),
      ]);
    });

    test('a Node moved into an added subtree is reparented after the add', () {
      final doc = small();
      final next = doc
          .addNode(entity('x'), parentId: doc.rootId)
          .moveNode(const NodeId('b'), parentId: const NodeId('x'));
      expect(reconcile(doc, next), [
        AddNode(next.node(const NodeId('x'))!, parentId: doc.rootId, index: 1),
        const ReparentNode(NodeId('b'), parentId: NodeId('x'), index: 0),
      ]);
    });
  });

  group('invariant 5 — purity: old == null seeds adds', () {
    test('a null old document adds the root children in order', () {
      final doc = small();
      expect(reconcile(null, doc), [
        AddNode(doc.node(const NodeId('a'))!, parentId: doc.rootId, index: 0),
        AddNode(doc.node(const NodeId('b'))!, parentId: doc.rootId, index: 1),
      ]);
    });

    test('the same inputs always yield the same ops', () {
      final doc = small();
      final next = doc.removeNode(const NodeId('b'));
      expect(reconcile(doc, next), reconcile(doc, next));
    });
  });

  group('patches', () {
    test(
      'a changed Node that also moved yields ReparentNode and PatchNode',
      () {
        final doc = small();
        final b = doc.node(const NodeId('b'))! as EntityNode;
        final next = doc
            .replaceNode(moved(b, 9))
            .moveNode(const NodeId('b'), parentId: const NodeId('a'));
        expect(reconcile(doc, next), [
          const ReparentNode(NodeId('b'), parentId: NodeId('a'), index: 1),
          const PatchNode(NodeId('b')),
        ]);
      },
    );

    test('a parent whose only change is its children is not patched', () {
      final doc = small();
      final next = doc.addNode(sprite('a2'), parentId: const NodeId('a'));
      expect(reconcile(doc, next).whereType<PatchNode>(), isEmpty);
    });

    test('a renamed Node is patched', () {
      final doc = small();
      final a = doc.node(const NodeId('a'))! as EntityNode;
      final next = doc.replaceNode(a.copyWith(name: 'renamed'));
      expect(reconcile(doc, next), [const PatchNode(NodeId('a'))]);
    });

    test('a Custom component with new Overrides is patched', () {
      final doc = SceneDocument.fromScene(
        Scene(
          rootId: const NodeId('root'),
          nodes: {
            const NodeId('root'): RootNode(
              id: const NodeId('root'),
              childIds: const [NodeId('c')],
            ),
            const NodeId('c'): CustomNode(
              id: const NodeId('c'),
              type: const TypeId('goblin'),
              transform: NodeTransform(),
            ),
          },
        ),
      );
      final c = doc.node(const NodeId('c'))! as CustomNode;
      final next = doc.replaceNode(c.copyWith(fields: c.fields.put('hp', 3)));
      expect(reconcile(doc, next), [const PatchNode(NodeId('c'))]);
    });
  });

  test('ops are an IList', () {
    expect(reconcile(null, small()), isA<IList<PreviewOp>>());
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/catalog/built_in.dart';
import 'package:pyro/project/catalog/manifest_parse.dart';
import 'package:pyro/project/catalog/parenting.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../../document/helpers/scenes.dart';

/// The example catalog: the built-ins plus an entity-like Custom component
/// (`Boss`), a leaf one (`Banner`) and a Behavior (`Spin`).
TypeCatalog get _catalog => TypeCatalog(
  types: IMap({
    for (final type in [
      ...builtInTypes,
      _custom('Boss', acceptsBehaviors: true),
      _custom('Banner', acceptsBehaviors: false),
      _behavior('Spin'),
    ])
      type.id: type,
  }),
  problems: const IList.empty(),
  origin: const ManifestAbsent(),
);

TypeDescriptor _custom(String id, {required bool acceptsBehaviors}) =>
    TypeDescriptor(
      id: TypeId(id),
      role: TypeRole.component,
      label: id,
      supertypes: const ISet.empty(),
      acceptsBehaviors: acceptsBehaviors,
      builtIn: false,
      fields: const IList.empty(),
    );

TypeDescriptor _behavior(String id) => TypeDescriptor(
  id: TypeId(id),
  role: TypeRole.behavior,
  label: id,
  parentType: const TypeId('PyroEntity'),
  supertypes: const ISet.empty(),
  acceptsBehaviors: false,
  builtIn: false,
  fields: const IList.empty(),
);

/// root → a (entity) → [a1 sprite, ah hitbox], boss (Custom, entity-like)
/// → [banner (Custom, leaf)], spin attaches as a Behavior, not a Node.
SceneDocument get _doc {
  final scene = Scene(
    rootId: const NodeId('root'),
    nodes: {
      const NodeId('root'): RootNode(
        id: const NodeId('root'),
        childIds: const [NodeId('a'), NodeId('boss')],
      ),
      const NodeId('a'): entity('a', children: ['a1', 'ah']),
      const NodeId('a1'): sprite('a1'),
      const NodeId('ah'): RectangleHitboxNode(
        id: const NodeId('ah'),
        size: const Vec2(4, 4),
      ),
      const NodeId('boss'): CustomNode(
        id: const NodeId('boss'),
        name: 'boss',
        type: const TypeId('Boss'),
        childIds: const [NodeId('banner')],
        transform: NodeTransform(),
      ),
      const NodeId('banner'): CustomNode(
        id: const NodeId('banner'),
        name: 'banner',
        type: const TypeId('Banner'),
        transform: NodeTransform(),
      ),
    },
  );
  return SceneDocument.fromScene(scene);
}

const entityId = TypeId('entity');
const spriteId = TypeId('sprite');
const rectId = TypeId('rectangleHitbox');
const circleId = TypeId('circleHitbox');
const bossId = TypeId('Boss');
const bannerId = TypeId('Banner');

void main() {
  group('childOffers (T020, contracts/type-catalog.md)', () {
    test('the scene root offers entities and custom components only', () {
      final offers = childOffers(_catalog, const AddParent.root());
      final byId = {for (final offer in offers) offer.type.id: offer};
      expect(byId.keys, {
        entityId,
        spriteId,
        rectId,
        circleId,
        bossId,
        bannerId,
      });
      expect(byId[entityId]!.offered, isTrue);
      expect(byId[bossId]!.offered, isTrue);
      expect(byId[bannerId]!.offered, isTrue);
      expect(byId[spriteId]!.refusal, contains('positioned parent'));
      // The one rule a user can't guess (Q115), with its reason.
      expect(byId[rectId]!.refusal, hitboxUnderRootReason);
      expect(byId[circleId]!.refusal, hitboxUnderRootReason);
    });

    test(
      'an entity offers sprites, both hitboxes, custom components and entities',
      () {
        final offers = childOffers(_catalog, const AddParent.type(entityId));
        for (final id in [
          entityId,
          spriteId,
          rectId,
          circleId,
          bossId,
          bannerId,
        ]) {
          expect(
            offers.singleWhere((o) => o.type.id == id).offered,
            isTrue,
            reason: '$id under an entity',
          );
        }
      },
    );

    test('a sprite offers hitboxes and custom components', () {
      final offers = childOffers(_catalog, const AddParent.type(spriteId));
      final byId = {for (final offer in offers) offer.type.id: offer};
      expect(byId[rectId]!.offered, isTrue);
      expect(byId[circleId]!.offered, isTrue);
      expect(byId[bossId]!.offered, isTrue);
      expect(byId[entityId]!.refusal, contains('Entity-like Node'));
      expect(byId[spriteId]!.refusal, contains('Entity-like parent'));
    });

    test('a hitbox offers nothing', () {
      for (final id in [rectId, circleId]) {
        final offers = childOffers(_catalog, AddParent.type(id));
        expect(offers, isNotEmpty, reason: '$id lists every entry');
        expect(
          offers.every((offer) => !offer.offered),
          isTrue,
          reason: '$id refuses everything',
        );
      }
    });

    test('an entity-like custom component behaves like an entity', () {
      final offers = childOffers(_catalog, const AddParent.type(bossId));
      expect(offers.every((offer) => offer.offered), isTrue);
    });

    test('a leaf custom component offers nothing', () {
      final offers = childOffers(_catalog, const AddParent.type(bannerId));
      final refused = offers.where((offer) => !offer.offered).toList();
      expect(refused, hasLength(offers.length));
      expect(refused.first.refusal, '"Banner" accepts no children.');
    });

    test('a type missing from the catalog is offered under (conservative)', () {
      final offers = childOffers(
        _catalog,
        const AddParent.type(TypeId('Missing')),
      );
      expect(offers.every((offer) => offer.offered), isTrue);
    });

    test('Behaviors are never offered — they are not Nodes', () {
      final offers = childOffers(_catalog, const AddParent.type(entityId));
      expect(
        offers.map((offer) => offer.type.id),
        isNot(contains(const TypeId('Spin'))),
      );
    });
  });

  group('canReparent (T020, FR-027)', () {
    test('allowed moves follow the table', () {
      final doc = _doc;
      // entity under root, sprite under entity, hitbox under sprite,
      // custom under root.
      expect(
        canReparent(
          doc,
          _catalog,
          const NodeId('a'),
          const NodeId('boss'),
        ).allowed,
        isTrue,
      );
      expect(
        canReparent(
          doc,
          _catalog,
          const NodeId('a1'),
          const NodeId('boss'),
        ).allowed,
        isTrue,
      );
      expect(
        canReparent(
          doc,
          _catalog,
          const NodeId('ah'),
          const NodeId('a1'),
        ).allowed,
        isTrue,
      );
      expect(
        canReparent(
          doc,
          _catalog,
          const NodeId('banner'),
          const NodeId('root'),
        ).allowed,
        isTrue,
      );
    });

    test('no hitbox under the scene root (Q115)', () {
      final check = canReparent(
        _doc,
        _catalog,
        const NodeId('ah'),
        const NodeId('root'),
      );
      expect(check, isA<ReparentRefused>());
      expect((check as ReparentRefused).reason, hitboxUnderRootReason);
    });

    test('no Node into its own subtree', () {
      final check = canReparent(
        _doc,
        _catalog,
        const NodeId('a'),
        const NodeId('a1'),
      );
      expect(check, isA<ReparentRefused>());
      expect((check as ReparentRefused).reason, contains('inside itself'));
      // And not onto itself either.
      expect(
        canReparent(_doc, _catalog, const NodeId('a'), const NodeId('a')),
        isA<ReparentRefused>(),
      );
    });

    test("the root can't be moved", () {
      final check = canReparent(
        _doc,
        _catalog,
        const NodeId('root'),
        const NodeId('a'),
      );
      expect(check, isA<ReparentRefused>());
      expect(
        (check as ReparentRefused).reason,
        contains("root can't be moved"),
      );
    });

    test('the table refusals answer for reparenting too', () {
      // An entity onto a sprite; anything onto a hitbox; anything onto a
      // leaf custom component.
      expect(
        canReparent(_doc, _catalog, const NodeId('a'), const NodeId('a1')),
        isA<ReparentRefused>(),
      );
      expect(
        canReparent(_doc, _catalog, const NodeId('a'), const NodeId('ah')),
        isA<ReparentRefused>(),
      );
      expect(
        canReparent(_doc, _catalog, const NodeId('a1'), const NodeId('banner')),
        isA<ReparentRefused>(),
      );
    });

    test('a missing type keeps editing: only the hard rules answer', () {
      final doc = SceneDocument.fromScene(
        Scene(
          rootId: const NodeId('root'),
          nodes: {
            const NodeId('root'): RootNode(
              id: const NodeId('root'),
              childIds: const [NodeId('x'), NodeId('gone')],
            ),
            const NodeId('x'): CustomNode(
              id: const NodeId('x'),
              type: const TypeId('Deleted'),
              transform: NodeTransform(),
            ),
            const NodeId('gone'): UnknownNode(
              id: const NodeId('gone'),
              kind: 'mystery',
            ),
          },
        ),
      );
      expect(
        canReparent(
          doc,
          _catalog,
          const NodeId('x'),
          const NodeId('root'),
        ).allowed,
        isTrue,
      );
      expect(
        canReparent(
          doc,
          _catalog,
          const NodeId('gone'),
          const NodeId('x'),
        ).allowed,
        isTrue,
      );
      // The hard rules still hold.
      expect(
        canReparent(doc, _catalog, const NodeId('x'), const NodeId('x')),
        isA<ReparentRefused>(),
      );
    });
  });
}

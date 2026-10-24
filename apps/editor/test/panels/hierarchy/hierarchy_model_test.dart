import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/panels/hierarchy/hierarchy_model.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../behaviors/behavior_helpers.dart';

void main() {
  TypeCatalog catalogOf(
    List<TypeDescriptor> types, {
    ManifestOrigin origin = const ManifestUpToDate(),
  }) => TypeCatalog(
    types: IMap({
      for (final type in [...builtInTypes, ...types]) type.id: type,
    }),
    problems: const IList.empty(),
    origin: origin,
  );

  final entity = EntityNode(
    id: const NodeId('e'),
    name: 'e',
    transform: NodeTransform(),
    behaviors: [
      BehaviorAttachment(type: const TypeId('Spin')),
      BehaviorAttachment(type: const TypeId('Patrol')),
    ],
  );

  group('hasMissingBehavior (FR-037)', () {
    test('is true when a Behavior left the catalog', () {
      expect(hasMissingBehavior(entity, catalogOf([spinType()])), isTrue);
    });

    test('is false while every Behavior type is known', () {
      expect(
        hasMissingBehavior(entity, catalogOf([spinType(), patrolType()])),
        isFalse,
      );
    });

    test('is false for a stale catalog and for Nodes without Behaviors', () {
      expect(
        hasMissingBehavior(
          entity,
          catalogOf([
            spinType(),
          ], origin: const ManifestStale('the Manifest has errors')),
        ),
        isFalse,
      );
      expect(
        hasMissingBehavior(
          RectangleHitboxNode(id: const NodeId('h'), size: const Vec2(8, 8)),
          catalogOf(const []),
        ),
        isFalse,
      );
    });
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/project.dart';

import '../../panels/behaviors/behavior_helpers.dart';

void main() {
  final entity = builtInTypes.firstWhere((type) => type.id.value == 'entity');
  final sprite = builtInTypes.firstWhere((type) => type.id.value == 'sprite');

  test('a Behavior fits the type it names and its subtypes (Q57)', () {
    expect(behaviorRefusal(entity, spinType()), isNull);
    // `Behavior<PositionedEntity>` fits through the chain.
    expect(
      behaviorRefusal(
        entity,
        behaviorType('B', parentType: 'PositionedEntity'),
      ),
      isNull,
    );
    // No parent type: any entity will do.
    expect(behaviorRefusal(entity, behaviorType('Any')), isNull);
    // A custom component, through its own supertypes and by its own ID.
    expect(
      behaviorRefusal(enemyType(), behaviorType('B', parentType: 'Enemy')),
      isNull,
    );
    expect(
      behaviorRefusal(
        enemyType(),
        behaviorType('B', parentType: 'PositionComponent'),
      ),
      isNull,
    );
    expect(
      behaviorRefusal(enemyType(), spinType()),
      'Spin needs a PyroEntity, which Enemy is not.',
    );
  });

  test('a type that accepts no Behaviors refuses them all (Q50)', () {
    expect(
      behaviorRefusal(sprite, spinType()),
      'Sprite does not accept Behaviors.',
    );
  });

  test('an unknown parent type is never a reason to refuse', () {
    expect(behaviorRefusal(null, spinType()), isNull);
  });

  test('behaviorOffers lists only Behaviors, each with its refusal', () {
    final catalog = TypeCatalog(
      types: IMap({
        for (final type in [
          ...builtInTypes,
          spinType(),
          enemyType(),
          behaviorType('Aim', parentType: 'Enemy'),
        ])
          type.id: type,
      }),
      problems: const IList.empty(),
      origin: const ManifestUpToDate(),
    );
    final offers = behaviorOffers(catalog, entity);
    expect(offers.map((offer) => offer.type.id.value), ['Aim', 'Spin']);
    expect(offers.map((offer) => offer.offered), [false, true]);
  });
}

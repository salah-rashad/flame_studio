import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/catalog/built_in.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

void main() {
  group('builtInTypes (T019, contracts/type-catalog.md)', () {
    test('the four built-in kinds, all components and builtIn', () {
      expect(builtInTypes.map((type) => type.id.value), [
        'entity',
        'sprite',
        'rectangleHitbox',
        'circleHitbox',
      ]);
      for (final type in builtInTypes) {
        expect(
          type.role,
          TypeRole.component,
          reason: '${type.id} is a component',
        );
        expect(type.builtIn, isTrue, reason: '${type.id} is hand-written');
        expect(type.label, isNotEmpty);
      }
    });

    test('the entity holds Behaviors and carries no fields (Q89)', () {
      final entity = builtInTypes.first;
      expect(entity.acceptsBehaviors, isTrue);
      // The transform is rendered from NodeTransform, never a
      // FieldDescriptor.
      expect(entity.fields, isEmpty);
    });

    test('the sprite edits its image and optional region only', () {
      final sprite = builtInTypes[1];
      expect(sprite.acceptsBehaviors, isFalse);
      expect(sprite.fields.map((f) => f.name), ['image', 'region']);
      expect(sprite.fields[0].type, FieldType.imagePath);
      expect(sprite.fields[0].nullable, isFalse);
      expect(sprite.fields[1].type, FieldType.vector2);
      expect(sprite.fields[1].nullable, isTrue);
      // No transform ever appears as a field (Q89).
      for (final transform in [
        'position',
        'angle',
        'scale',
        'size',
        'anchor',
      ]) {
        expect(sprite.fields.map((f) => f.name), isNot(contains(transform)));
      }
    });

    test('both hitbox kinds share collisionType and isSolid', () {
      for (final id in ['rectangleHitbox', 'circleHitbox']) {
        final hitbox = builtInTypes.singleWhere((t) => t.id.value == id);
        expect(hitbox.acceptsBehaviors, isFalse, reason: id);
        expect(hitbox.fields.map((f) => f.name), [
          'collisionType',
          'isSolid',
        ], reason: id);
        final collisionType = hitbox.fields[0];
        expect(collisionType.type, FieldType.enumeration, reason: id);
        expect(collisionType.enumValues, [
          'active',
          'passive',
          'inactive',
        ], reason: id);
        expect(collisionType.defaultValue, 'active', reason: id);
        expect(hitbox.fields[1].type, FieldType.bool, reason: id);
        expect(hitbox.fields[1].defaultValue, isFalse, reason: id);
      }
    });
  });
}

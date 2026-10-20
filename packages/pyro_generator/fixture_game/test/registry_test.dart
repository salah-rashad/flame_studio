import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fixture_game/behaviors/patrol.dart';
import 'package:fixture_game/components/boss.dart';
import 'package:fixture_game/components/enemy.dart';
import 'package:fixture_game/components/lamp.dart';
import 'package:fixture_game/pyro.g.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// The committed Registry builds every type and sets every field, and agrees
/// with the committed Manifest (spec 003, SC-005, SC-006).
void main() {
  late Sprite sprite;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sprite = Sprite(await createTestImage());
  });

  /// A value of [field]'s type, or null if no instance in the Registry fits.
  Object? sampleFor(RegistryField field) => switch (field.type) {
    FieldType.int => 7,
    FieldType.double => 1.5,
    FieldType.bool => false,
    FieldType.string => 'text',
    FieldType.enumeration => field.values!.last,
    FieldType.vector2 => Vector2(3, 4),
    FieldType.color => const Color(0xFF102030),
    FieldType.imagePath => const ImagePath('assets/images/x.png'),
    FieldType.sprite => sprite,
    FieldType.spriteAnimation => SpriteAnimation.spriteList([
      sprite,
    ], stepTime: 1),
    FieldType.entityRef => [
      for (final type in pyroRegistry.types) type.create(),
    ].firstWhere(field.accepts),
  };

  test('creates every type and sets every field', () {
    expect(pyroRegistry.types, isNotEmpty);
    for (final type in pyroRegistry.types) {
      final instance = type.create();
      for (final field in type.fields.values) {
        final reason = '${type.id}.${field.name}';
        final value = sampleFor(field);
        expect(field.accepts(value), isTrue, reason: reason);
        expect(field.accepts(Object()), isFalse, reason: reason);
        expect(field.accepts(null), field.nullable, reason: reason);
        field.set(instance, value);
        if (field.nullable) field.set(instance, null);
      }
    }
  });

  test('every Field type appears at least once (FR-011)', () {
    final types = {
      for (final type in pyroRegistry.types)
        for (final field in type.fields.values) field.type,
    };
    expect(types, FieldType.values.toSet());
  });

  test('set assigns the value on the instance', () {
    final patrol = pyroRegistry[const TypeId('Patrol')]!;
    final instance = patrol.create() as Patrol;
    patrol.fields['speed']!.set(instance, 120.0);
    patrol.fields['mode']!.set(instance, PatrolMode.loop);
    patrol.fields['direction']!.set(instance, Vector2(0, 1));
    expect(instance.speed, 120);
    expect(instance.mode, PatrolMode.loop);
    expect(instance.direction, Vector2(0, 1));
    expect(patrol.fields['mode']!.values, PatrolMode.values);

    final lamp = pyroRegistry[const TypeId('Lamp')]!;
    final light = lamp.create() as Lamp;
    lamp.fields['tint']!.set(light, const Color(0xFF00FF00));
    expect(light.tint, const Color(0xFF00FF00));

    final boss = pyroRegistry[const TypeId('Boss')]!;
    final big = boss.create() as Boss;
    final minion = Enemy();
    boss.fields['minion']!.set(big, minion);
    boss.fields['health']!.set(big, 3);
    expect(big.minion, same(minion));
    expect(big.health, 3);
  });

  test('the Manifest and the Registry list the same types and fields', () {
    final manifest =
        jsonDecode(File('lib/pyro.manifest.json').readAsStringSync())
            as Map<String, Object?>;
    final fromManifest = {
      for (final type
          in (manifest['types']! as List<Object?>).cast<Map<String, Object?>>())
        type['id']: [
          for (final field
              in (type['fields']! as List<Object?>)
                  .cast<Map<String, Object?>>())
            field['name'],
        ],
    };
    final fromRegistry = {
      for (final type in pyroRegistry.types) type.id: type.fields.keys.toList(),
    };
    expect(fromRegistry.keys.toList(), fromManifest.keys.toList());
    expect(fromRegistry, fromManifest);
    expect(manifest['errors'], isEmpty);
    expect(manifest['warnings'], isEmpty);
  });
}

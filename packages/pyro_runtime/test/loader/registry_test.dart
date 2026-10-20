import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

class _Coin extends PositionComponent {
  int value = 1;
}

RegistryType _coin(String id) => RegistryType(
  id: TypeId(id),
  role: TypeRole.component,
  create: _Coin.new,
  fields: {
    'value': RegistryField(
      name: 'value',
      type: FieldType.int,
      nullable: false,
      accepts: (v) => v is int,
      set: (t, v) => (t as _Coin).value = v! as int,
    ),
  },
);

class _Enemy extends PositionedEntity {}

class _Chase extends Behavior<_Enemy> {}

RegistryType _chase({bool Function(Component)? acceptsParent}) => RegistryType(
  id: const TypeId('Chase'),
  role: TypeRole.behavior,
  create: _Chase.new,
  fields: const {},
  acceptsParent: acceptsParent,
);

void main() {
  test('looks types up by Type ID', () {
    final registry = PyroRegistry([_coin('coin')]);
    expect(registry[const TypeId('coin')]?.role, TypeRole.component);
    expect(registry[const TypeId('missing')], isNull);
  });

  test('lists types in Type ID order whatever the input order', () {
    final registry = PyroRegistry([_coin('b'), _coin('c'), _coin('a')]);
    expect([for (final t in registry.types) t.id], ['a', 'b', 'c']);
  });

  test('refuses two types with one Type ID, naming it', () {
    expect(
      () => PyroRegistry([_coin('coin'), _coin('coin')]),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"coin"'),
        ),
      ),
    );
  });

  test('creates instances and sets fields through accepts and set', () {
    final type = PyroRegistry([_coin('coin')])[const TypeId('coin')]!;
    final coin = type.create();
    final field = type.fields['value']!;
    expect(field.accepts(5), isTrue);
    expect(field.accepts('5'), isFalse);
    expect(field.accepts(null), isFalse);
    field.set(coin, 5);
    expect((coin as _Coin).value, 5);
  });

  test('keeps a Behavior\'s acceptsParent and calls it as given', () {
    final registry = PyroRegistry([
      _chase(acceptsParent: (parent) => parent is _Enemy),
    ]);
    final accepts = registry[const TypeId('Chase')]!.acceptsParent!;
    expect(accepts(_Enemy()), isTrue);
    expect(accepts(PositionComponent()), isFalse);
  });

  test('refuses a Behavior without acceptsParent, naming it', () {
    expect(
      () => PyroRegistry([_chase()]),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          allOf(contains('"Chase"'), contains('build_runner')),
        ),
      ),
    );
  });

  test('refuses a Custom component with acceptsParent, naming it', () {
    final coin = _coin('coin');
    expect(
      () => PyroRegistry([
        RegistryType(
          id: coin.id,
          role: coin.role,
          create: coin.create,
          fields: coin.fields,
          acceptsParent: (_) => true,
        ),
      ]),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"coin"'),
        ),
      ),
    );
  });
}

import 'package:flame/components.dart';
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
}

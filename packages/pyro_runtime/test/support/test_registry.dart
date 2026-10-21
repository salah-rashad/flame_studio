import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// The values of an enum field.
enum Mode { a, b }

/// What `AllFields.onLoad` saw, newest last, so tests can check that every
/// Override was set before `onLoad` (FR-003).
final List<Map<String, Object?>> allFieldsLoads = [];

/// A Behavior with one field of every Field type.
class AllFields extends Behavior<PositionedEntity> {
  int count = 1;
  double speed = 50;
  bool active = true;
  String label = 'x';
  Mode mode = Mode.a;
  Vector2 direction = Vector2(1, 0);
  Color tint = const Color(0xFFFFFFFF);
  ImagePath icon = const ImagePath('assets/images/default.png');
  Sprite? sprite;
  SpriteAnimation? effect;
  Component? target;
  int? maybe = 7;

  /// The fields' values, by name.
  Map<String, Object?> get values => {
    'count': count,
    'speed': speed,
    'active': active,
    'label': label,
    'mode': mode,
    'direction': direction.clone(),
    'tint': tint,
    'icon': icon,
    'sprite': sprite,
    'effect': effect,
    'target': target,
    'maybe': maybe,
    'parentLoaded': parent.isLoaded,
  };

  @override
  Future<void> onLoad() async => allFieldsLoads.add(values);
}

/// A Behavior that only fits an [Enemy].
class EnemyOnly extends Behavior<Enemy> {}

/// A Behavior whose constructor throws.
class Throwing extends Behavior<PositionedEntity> {
  Throwing() {
    throw StateError('boom');
  }
}

/// A Custom component that holds Behaviors.
class Player extends PositionedEntity {
  int maxHealth = 3;
  Color tint = const Color(0xFFFF8800);
}

/// Another Custom component that holds Behaviors.
class Enemy extends PositionedEntity {}

/// A Custom component that can't hold Behaviors.
class Plain extends PositionComponent {}

/// A Custom component whose field setter throws.
class BadSetter extends PositionComponent {
  set value(int value) => throw StateError('no');
}

RegistryField _field<T, O>(
  String name,
  FieldType type,
  void Function(O target, T value) set, {
  bool nullable = false,
  List<Enum>? values,
}) => RegistryField(
  name: name,
  type: type,
  nullable: nullable,
  values: values,
  accepts: (v) => v is T || (nullable && v == null),
  set: (t, v) => set(t as O, v as T),
);

/// The Registry the loader tests use, written as the Generator would.
final PyroRegistry testRegistry = PyroRegistry([
  RegistryType(
    id: const TypeId('AllFields'),
    role: TypeRole.behavior,
    create: AllFields.new,
    acceptsParent: (parent) => parent is PositionedEntity,
    fields: {
      'count': _field<int, AllFields>(
        'count',
        FieldType.int,
        (t, v) => t.count = v,
      ),
      'speed': _field<double, AllFields>(
        'speed',
        FieldType.double,
        (t, v) => t.speed = v,
      ),
      'active': _field<bool, AllFields>(
        'active',
        FieldType.bool,
        (t, v) => t.active = v,
      ),
      'label': _field<String, AllFields>(
        'label',
        FieldType.string,
        (t, v) => t.label = v,
      ),
      'mode': _field<Mode, AllFields>(
        'mode',
        FieldType.enumeration,
        (t, v) => t.mode = v,
        values: Mode.values,
      ),
      'direction': _field<Vector2, AllFields>(
        'direction',
        FieldType.vector2,
        (t, v) => t.direction = v,
      ),
      'tint': _field<Color, AllFields>(
        'tint',
        FieldType.color,
        (t, v) => t.tint = v,
      ),
      'icon': _field<ImagePath, AllFields>(
        'icon',
        FieldType.imagePath,
        (t, v) => t.icon = v,
      ),
      'sprite': _field<Sprite?, AllFields>(
        'sprite',
        FieldType.sprite,
        (t, v) => t.sprite = v,
        nullable: true,
      ),
      'effect': _field<SpriteAnimation?, AllFields>(
        'effect',
        FieldType.spriteAnimation,
        (t, v) => t.effect = v,
        nullable: true,
      ),
      'target': _field<Component?, AllFields>(
        'target',
        FieldType.entityRef,
        (t, v) => t.target = v,
        nullable: true,
      ),
      'maybe': _field<int?, AllFields>(
        'maybe',
        FieldType.int,
        (t, v) => t.maybe = v,
        nullable: true,
      ),
    },
  ),
  RegistryType(
    id: const TypeId('EnemyOnly'),
    role: TypeRole.behavior,
    create: EnemyOnly.new,
    acceptsParent: (parent) => parent is Enemy,
    fields: const {},
  ),
  RegistryType(
    id: const TypeId('Throwing'),
    role: TypeRole.behavior,
    create: Throwing.new,
    acceptsParent: (parent) => parent is PositionedEntity,
    fields: const {},
  ),
  RegistryType(
    id: const TypeId('Player'),
    role: TypeRole.component,
    create: Player.new,
    fields: {
      'maxHealth': _field<int, Player>(
        'maxHealth',
        FieldType.int,
        (t, v) => t.maxHealth = v,
      ),
      'tint': _field<Color, Player>(
        'tint',
        FieldType.color,
        (t, v) => t.tint = v,
      ),
    },
  ),
  const RegistryType(
    id: TypeId('Enemy'),
    role: TypeRole.component,
    create: Enemy.new,
    fields: {},
  ),
  const RegistryType(
    id: TypeId('Plain'),
    role: TypeRole.component,
    create: Plain.new,
    fields: {},
  ),
  RegistryType(
    id: const TypeId('BadSetter'),
    role: TypeRole.component,
    create: BadSetter.new,
    fields: {
      'value': _field<int, BadSetter>(
        'value',
        FieldType.int,
        (t, v) => t.value = v,
      ),
    },
  ),
]);

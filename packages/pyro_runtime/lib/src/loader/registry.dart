import 'package:flame/components.dart';

import '../scene/values.dart';

/// Whether a user type is a Behavior or a Custom component.
enum TypeRole {
  /// A `flame_behaviors` Behavior, attached to an entity Node.
  behavior,

  /// A `PositionComponent` subclass, placed in a Scene as a Custom component
  /// Node.
  component,
}

/// The Field type of an Editable field (project plan §6.1, *Q12*).
///
/// Each value's documentation names the Dart value the Runtime passes to
/// [RegistryField.set] for it, after converting the Scene's written form. The
/// Manifest spells them the same way, except [enumeration], which it writes
/// as `enum`.
enum FieldType {
  /// An `int`.
  int,

  /// A `double`.
  double,

  /// A `bool`.
  bool,

  /// A `String`.
  string,

  /// A value of the field's enum; [RegistryField.values] lists them.
  enumeration,

  /// Flame's `Vector2`.
  vector2,

  /// A `dart:ui` `Color`.
  color,

  /// An `ImagePath`.
  imagePath,

  /// A `Sprite`.
  sprite,

  /// A `SpriteAnimation`.
  spriteAnimation,

  /// The referenced `Component`.
  entityRef,
}

/// One Editable field of a user type, as the generated Registry describes it.
final class RegistryField {
  /// Describes the field [name].
  const RegistryField({
    required this.name,
    required this.type,
    required this.nullable,
    required this.accepts,
    required this.set,
    this.values,
  });

  /// The field's name, as Scenes key its Override.
  final String name;

  /// The field's Field type.
  final FieldType type;

  /// Whether the field accepts `null`.
  final bool nullable;

  /// The enum's values for a [FieldType.enumeration] field, in declaration
  /// order; null for every other Field type.
  final List<Enum>? values;

  /// Whether `value` can be assigned to the field: a value of its type, or
  /// null when [nullable]. The Runtime checks it before calling [set], so its
  /// error can name the Scene, the Node and the field.
  final bool Function(Object? value) accepts;

  /// Assigns `value` to the field of `target`, an instance created by its
  /// type's [RegistryType.create]. `value` must satisfy [accepts].
  final void Function(Object target, Object? value) set;

  @override
  String toString() => 'RegistryField($name, ${type.name})';
}

/// One user type: what the Runtime needs to build it from a Scene.
final class RegistryType {
  /// Describes the user type [id].
  const RegistryType({
    required this.id,
    required this.role,
    required this.create,
    required this.fields,
    this.acceptsParent,
  });

  /// The type's Type ID (*Q45*).
  final TypeId id;

  /// Whether it is a Behavior or a Custom component.
  final TypeRole role;

  /// Creates a new instance through the class's unnamed constructor.
  final Component Function() create;

  /// The Editable fields by name, in the Manifest's order.
  final Map<String, RegistryField> fields;

  /// For a Behavior, whether it can be attached to `parent`: whether
  /// `parent` is the type argument of its `Behavior<T>`. Null for Custom
  /// components.
  ///
  /// The Runtime checks it when it attaches Behaviors, because
  /// `flame_behaviors` only asserts the parent type in debug builds, after
  /// mounting.
  final bool Function(Component parent)? acceptsParent;

  @override
  String toString() => 'RegistryType($id, ${role.name})';
}

/// A game's Registry: every valid user type by Type ID.
///
/// `pyro_generator` writes one into the game as `pyroRegistry` in
/// `lib/pyro.g.dart`; tests may write one by hand.
final class PyroRegistry {
  /// A Registry of [types].
  ///
  /// Throws an [ArgumentError] naming the Type ID if two types share one,
  /// if a Behavior has no [RegistryType.acceptsParent], or if a Custom
  /// component has one. The generator never emits these, but a hand-written
  /// Registry might, and a Registry generated before `acceptsParent` existed
  /// lacks it (regenerate it with `dart run build_runner build`).
  PyroRegistry(Iterable<RegistryType> types) : _types = _byId(types);

  final Map<TypeId, RegistryType> _types;

  static Map<TypeId, RegistryType> _byId(Iterable<RegistryType> types) {
    final sorted = [...types]..sort((a, b) => a.id.compareTo(b.id));
    final byId = <TypeId, RegistryType>{};
    for (final type in sorted) {
      final isBehavior = type.role == TypeRole.behavior;
      if (isBehavior != (type.acceptsParent != null)) {
        throw ArgumentError.value(
          type.id,
          'types',
          isBehavior
              ? 'The Behavior "${type.id}" has no acceptsParent; regenerate '
                    'lib/pyro.g.dart with `dart run build_runner build`'
              : 'The Custom component "${type.id}" has an acceptsParent, '
                    'which only Behaviors have',
        );
      }
      if (byId.containsKey(type.id)) {
        throw ArgumentError.value(
          type.id,
          'types',
          'Two Registry types share the Type ID "${type.id}"',
        );
      }
      byId[type.id] = type;
    }
    return Map.unmodifiable(byId);
  }

  /// The type with Type ID [id], or null if there is none.
  RegistryType? operator [](TypeId id) => _types[id];

  /// Every type, in Type ID order.
  Iterable<RegistryType> get types => _types.values;
}

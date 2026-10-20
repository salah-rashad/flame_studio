# Contract: the Registry

Two halves: the types `pyro_runtime` exports for it (this feature adds them; the loader in #8
uses them), and the shape of the `lib/pyro.g.dart` that `pyro_generator` writes into a game
(FR-021 to FR-025; research R9 to R11).

## `pyro_runtime`: `lib/src/loader/registry.dart`

Exported from `package:pyro_runtime/pyro_runtime.dart`.

```dart
/// Whether a user type is a Behavior or a Custom component.
enum TypeRole { behavior, component }

/// The Field type of an Editable field (project plan §6.1, Q12), with the
/// value the Runtime passes to [RegistryField.set] for it.
enum FieldType {
  int,             // int
  double,          // double
  bool,            // bool
  string,          // String
  enumeration,     // the enum value (the Manifest writes "enum")
  vector2,         // Flame's Vector2
  color,           // dart:ui Color
  imagePath,       // ImagePath
  sprite,          // Sprite
  spriteAnimation, // SpriteAnimation
  entityRef,       // the referenced Component
}

/// One Editable field of a user type.
final class RegistryField {
  const RegistryField({
    required this.name,
    required this.type,
    required this.nullable,
    required this.accepts,
    required this.set,
    this.values,
  });

  final String name;
  final FieldType type;
  final bool nullable;

  /// The enum's values, for [FieldType.enumeration]; null otherwise.
  final List<Enum>? values;

  /// Whether [value] can be assigned to the field (its type, or null when
  /// [nullable]). The Runtime checks it before [set] so it can name the
  /// Scene, Node and field in its error.
  final bool Function(Object? value) accepts;

  /// Assigns [value] to the field of [target], an instance this type's
  /// `create` made. [value] must satisfy [accepts].
  final void Function(Object target, Object? value) set;
}

/// One user type: what the Runtime needs to build it from a Scene.
final class RegistryType {
  const RegistryType({
    required this.id,
    required this.role,
    required this.create,
    required this.fields,
    this.acceptsParent, // added by spec 004 (research R6)
  });

  final TypeId id;
  final TypeRole role;

  /// A new instance through the class's unnamed constructor.
  final Component Function() create;

  /// The Editable fields by name, in Manifest order.
  final Map<String, RegistryField> fields;

  /// For a Behavior, whether it can be attached to [parent]: the type
  /// argument of its `Behavior<T>`, or `EntityMixin`. Null for Custom
  /// components. PyroRegistry refuses a Behavior without one and a Custom
  /// component with one.
  final bool Function(Component parent)? acceptsParent;
}

/// The game's generated Registry: every valid user type by Type ID.
final class PyroRegistry {
  /// Throws [ArgumentError] if two types share a Type ID (the Generator
  /// never emits that; a hand-written Registry might).
  PyroRegistry(Iterable<RegistryType> types);

  /// The type with Type ID [id], or null.
  RegistryType? operator [](TypeId id);

  /// Every type, in Type ID order.
  Iterable<RegistryType> get types;
}
```

`FieldType`'s Dart names match the Manifest's strings (contracts/manifest-v1.md), except
`enumeration`, since `enum` is a reserved word. `int`, `double` and `bool` are legal value names;
code inside the enum body can't name the core types, so the generator keeps its rules in an
extension (implementation note, 2026-10-20). A
hand-written Registry (#8's tests, Phase 2's done-when) uses the same classes.

## Generated `lib/pyro.g.dart`

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND.
// pyro_generator: the Registry for this package's annotated types.
// ignore_for_file: type=lint

import 'package:flame/components.dart' as i0;
import 'package:my_game/behaviors/patrol.dart' as i1;
import 'package:my_game/components/player.dart' as i2;
import 'package:pyro_runtime/pyro_runtime.dart' as i3;

/// Every Behavior and Custom component in this package, for `PyroScene.load`.
final pyroRegistry = i3.PyroRegistry([
  i3.RegistryType(
    id: const i3.TypeId('Patrol'),
    role: i3.TypeRole.behavior,
    create: i1.Patrol.new,
    fields: {
      'speed': i3.RegistryField(
        name: 'speed',
        type: i3.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i1.Patrol).speed = v as double,
      ),
      'direction': i3.RegistryField(
        name: 'direction',
        type: i3.FieldType.vector2,
        nullable: false,
        accepts: (v) => v is i0.Vector2,
        set: (t, v) => (t as i1.Patrol).direction = v as i0.Vector2,
      ),
      'mode': i3.RegistryField(
        name: 'mode',
        type: i3.FieldType.enumeration,
        nullable: false,
        values: i1.PatrolMode.values,
        accepts: (v) => v is i1.PatrolMode,
        set: (t, v) => (t as i1.Patrol).mode = v as i1.PatrolMode,
      ),
      'target': i3.RegistryField(
        name: 'target',
        type: i3.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i2.Player,
        set: (t, v) => (t as i1.Patrol).target = v as i2.Player?,
      ),
    },
    acceptsParent: (parent) => parent is i2.Player, // Patrol extends Behavior<Player>
  ),
]);
```

Rules:

- Imports are prefixed `i0`, `i1`, … in URI order; field types are imported through a library
  the declaring class's library imports (research R10), never through another package's `src/`.
- Types in Type ID order, fields in Manifest order; the top-level name is always `pyroRegistry`.
- Every Behavior gets `acceptsParent: (parent) => parent is <T>`, with `<T>` its `Behavior<T>`
  type argument imported like a field type, or `flame_behaviors`' `EntityMixin` when it has none
  (spec 004 research R6). A parent type the Registry can't name is the `unreachableParentType`
  error.
- Formatted with `dart_style` (research R11). With no types:
  `final pyroRegistry = i0.PyroRegistry(const []);` and only the runtime import.
- The file passes `flutter analyze` in the game with no errors or warnings (SC-005).

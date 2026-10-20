/// Marks a Behavior that Pyro can attach to a Node (project plan §6.1).
///
/// The class must extend `Behavior` from `flame_behaviors`, be public and
/// non-abstract, and have an unnamed constructor callable with no arguments.
final class PyroBehavior {
  /// Marks a Behavior; every argument is optional.
  const PyroBehavior({this.label, this.category, this.id});

  /// The name shown in Pyro's Add Behavior list; the class name by default.
  final String? label;

  /// The group the Behavior is listed under in the Add Behavior list.
  final String? category;

  /// An explicit Type ID; the class name by default.
  ///
  /// Scenes name the Behavior by its Type ID, so keep a class's old name here
  /// when renaming it and Scenes keep working (ADR 0002).
  final String? id;
}

/// Marks a Custom component that Pyro can place in a Scene (project plan
/// §6.1).
///
/// The class must extend `PositionComponent`, be public and non-abstract, and
/// have an unnamed constructor callable with no arguments. It accepts
/// Behaviors only if it mixes in `EntityMixin` (*Q50*).
final class PyroComponent {
  /// Marks a Custom component; every argument is optional.
  const PyroComponent({this.label, this.category, this.id, this.preview});

  /// The name shown in Pyro's Add lists; the class name by default.
  final String? label;

  /// The group the component is listed under.
  final String? category;

  /// An explicit Type ID; the class name by default (ADR 0002).
  final String? id;

  /// A project-root-relative image Pyro draws in the editor instead of a
  /// placeholder, such as `assets/images/boss_preview.png`.
  final String? preview;
}

/// Marks a field that Pyro's inspector edits and a Scene can override.
///
/// The field must be a public, non-final instance field of a supported Field
/// type, with an initializer unless it is nullable. Entity references,
/// `Sprite` and `SpriteAnimation` fields must be nullable.
final class Editable {
  /// Marks an Editable field; every argument is optional.
  const Editable({this.min, this.max, this.tooltip, this.label});

  /// The lowest value the inspector offers, for `int` and `double` fields.
  final num? min;

  /// The highest value the inspector offers, for `int` and `double` fields.
  final num? max;

  /// Help text shown next to the field in the inspector.
  final String? tooltip;

  /// The inspector's label; Pyro derives one from the field name by default.
  final String? label;
}

# Contract: `pyro_annotations` public API

What `package:pyro_annotations/pyro_annotations.dart` exports (FR-001 to FR-004, FR-012). The
package stays pure Dart with no dependencies (Q44); `pyro_runtime` re-exports it, so games
usually import it through the Runtime. All four types are `final` classes with `const`
constructors and no behavior beyond equality.

```dart
/// Marks a Behavior Pyro can attach to a Node (project plan §6.1).
final class PyroBehavior {
  const PyroBehavior({this.label, this.category, this.id});

  /// Shown in Pyro's Add Behavior list; defaults to the class name.
  final String? label;

  /// Groups the Add Behavior list.
  final String? category;

  /// Explicit Type ID; defaults to the class name. Keep a class's old name
  /// here when renaming it, and Scenes keep working (ADR 0002).
  final String? id;
}

/// Marks a Custom component Pyro can place in a Scene.
final class PyroComponent {
  const PyroComponent({this.label, this.category, this.id, this.preview});

  final String? label;
  final String? category;
  final String? id;

  /// Project-root-relative image drawn in the editor instead of a placeholder.
  final String? preview;
}

/// Marks a field Pyro's inspector edits and a Scene can override.
final class Editable {
  const Editable({this.min, this.max, this.tooltip, this.label});

  /// Lower bound for `int` and `double` fields.
  final num? min;

  /// Upper bound for `int` and `double` fields.
  final num? max;

  final String? tooltip;

  /// Inspector label; Pyro derives one from the field name when absent.
  final String? label;
}

/// A project-root-relative image path, the Field type of an image-path
/// Editable field (`assets/images/fx.png`). A plain `String` field is text.
final class ImagePath {
  const ImagePath(this.path);

  final String path;

  @override
  bool operator ==(Object other) => other is ImagePath && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'ImagePath($path)';
}
```

Doc comments are abbreviated here; the package documents every public member
(`public_member_api_docs`).

## Usage

```dart
@PyroBehavior(label: 'Patrol', category: 'Movement')
class Patrol extends Behavior<PositionedEntity> {
  @Editable(min: 0, max: 400, tooltip: 'Pixels per second')
  double speed = 50;

  @Editable()
  ImagePath trail = const ImagePath('assets/images/trail.png');

  @Editable()
  Player? target;
}
```

## Compatibility

- The annotations are matched by type, so their names are part of the contract: renaming one is
  a breaking change of `pyro_annotations` and needs the matching trigger change in
  `pyro_generator`'s `build.yaml` (research R2, R3).
- New optional parameters are additive (FR-015a); the Generator ignores annotation fields it
  doesn't read.

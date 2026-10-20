# pyro_annotations

Annotations that mark your Flame components and behaviors for Pyro:

- `@PyroBehavior`: a `flame_behaviors` Behavior Pyro can attach to a Node.
- `@PyroComponent`: a `PositionComponent` Pyro can place in a Scene.
- `@Editable`: a field Pyro's inspector edits and a Scene can override.
- `ImagePath`: the type of an Editable field holding an image path.

```dart
@PyroBehavior(label: 'Patrol', category: 'Movement')
class Patrol extends Behavior<PositionedEntity> {
  @Editable(min: 0, max: 400, tooltip: 'Pixels per second')
  double speed = 50;

  @Editable()
  ImagePath trail = const ImagePath('assets/images/trail.png');
}
```

Pure Dart with no dependencies. You normally don't depend on it directly:
`pyro_runtime` re-exports it. `pyro_generator` reads the annotations at build
time.

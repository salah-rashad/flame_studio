import 'package:flame_behaviors/flame_behaviors.dart';

/// The component of a Scene's `entity` Node: a positioned entity that holds
/// Behaviors, with no behavior of its own.
///
/// Look one up with `scene.find<PyroEntity>('goblin_1')`, or as any
/// `PositionedEntity`.
class PyroEntity extends PositionedEntity {
  /// Creates an entity with the given transform.
  PyroEntity({
    super.position,
    super.size,
    super.scale,
    super.angle,
    super.anchor,
  });
}

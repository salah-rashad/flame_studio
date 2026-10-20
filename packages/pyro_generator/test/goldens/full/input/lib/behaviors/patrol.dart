import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../components/player.dart';

enum PatrolMode { pingPong, loop }

/// Walks between two points.
///
/// Turns around at each end.
@PyroBehavior(label: 'Patrol', category: 'Movement')
class Patrol extends Behavior<PositionedEntity> {
  @Editable(min: 0, max: 400, tooltip: 'Pixels per second')
  double speed = 50;

  @Editable()
  Vector2 direction = Vector2(1, 0);

  @Editable()
  PatrolMode mode = PatrolMode.pingPong;

  @Editable()
  Player? target;

  @Editable()
  SpriteAnimation? hitEffect;

  @Editable()
  ImagePath trail = const ImagePath('assets/images/trail.png');

  /// Not editable: no annotation.
  int steps = 0;
}

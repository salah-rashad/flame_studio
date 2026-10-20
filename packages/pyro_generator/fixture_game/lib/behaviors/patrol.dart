import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../components/legacy/player.dart' as legacy;
import '../components/player.dart';

/// How a [Patrol] turns around.
enum PatrolMode { pingPong, loop }

/// Walks between two points.
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
  legacy.Player? oldTarget;

  @Editable()
  SpriteAnimation? hitEffect;

  @Editable()
  ImagePath trail = const ImagePath('assets/images/trail.png');

  @override
  void update(double dt) {
    parent.position.add(direction * speed * dt);
  }
}

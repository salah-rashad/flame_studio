import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class Patrol extends PositionComponent {
  Patrol(this.speed);

  final int speed;
}

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class Optional extends PositionComponent {
  Optional({this.speed = 1});

  final int speed;
}

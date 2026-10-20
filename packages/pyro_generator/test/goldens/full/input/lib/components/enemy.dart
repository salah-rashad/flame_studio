import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

abstract class Hurtable extends PositionComponent {
  @Editable()
  int health = 10;
}

mixin Glows on PositionComponent {
  @Editable()
  double glow = 0.5;
}

@PyroComponent(id: 'enemy.base', label: 'Enemy', category: 'Enemies')
class Enemy extends Hurtable with Glows {
  @Editable()
  double health2 = 2.5;
}

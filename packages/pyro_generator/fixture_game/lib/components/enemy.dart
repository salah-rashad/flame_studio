import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

/// Something with health.
abstract class Hurtable extends PositionComponent {
  @Editable()
  int health = 10;
}

/// Something that glows.
mixin Glows on PositionComponent {
  @Editable()
  double glow = 0.5;
}

/// A basic enemy.
@PyroComponent(id: 'enemy.base', label: 'Enemy', category: 'Enemies')
class Enemy extends Hurtable with Glows {}

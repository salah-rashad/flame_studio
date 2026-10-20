import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroBehavior()
class Wobble extends Behavior {}

@PyroComponent()
class Host extends PositionComponent {
  @Editable()
  Wobble? other;
}

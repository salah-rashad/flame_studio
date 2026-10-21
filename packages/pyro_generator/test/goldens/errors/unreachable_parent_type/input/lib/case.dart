import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

class _Boss extends PositionedEntity {}

@PyroBehavior()
class Taunt extends Behavior<_Boss> {}

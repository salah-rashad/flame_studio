import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

mixin Tough on PositionedEntity {}

@PyroBehavior()
class Toughen extends Behavior<Tough> {}

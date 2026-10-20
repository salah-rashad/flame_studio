import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

abstract class Base extends PositionComponent {
  @Editable()
  abstract int hp;
}

@PyroComponent()
class Host extends Base {
  @override
  int hp = 1;
}

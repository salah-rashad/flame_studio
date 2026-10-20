import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

class Loose extends PositionComponent {
  @Editable()
  int ignored = 1;
}

mixin Used on PositionComponent {
  @Editable()
  int counted = 1;
}

@PyroComponent()
class Host extends PositionComponent with Used {}

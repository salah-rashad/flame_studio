import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

/// Valid, so it must stay in both outputs.
@PyroComponent()
class Good extends PositionComponent {
  @Editable()
  int value = 1;
}

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class Host extends PositionComponent {
  @Editable(min: 0, max: 10)
  double speed = -1;
}

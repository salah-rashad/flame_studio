import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

/// Shows and hides its entity.
@PyroBehavior()
class Blink extends Behavior {
  @Editable(label: 'Visible')
  bool visible = true;

  @Editable(min: -1, max: 10)
  int times = -1;
}

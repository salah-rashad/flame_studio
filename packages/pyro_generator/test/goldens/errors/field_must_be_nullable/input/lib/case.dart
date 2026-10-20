import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

import 'good.dart';

// Good is declared in good.dart.

@PyroComponent()
class Host extends PositionComponent {
  @Editable()
  Good target = Good();

  @Editable()
  Sprite icon = Sprite();

  @Editable()
  SpriteAnimation fx = SpriteAnimation();
}

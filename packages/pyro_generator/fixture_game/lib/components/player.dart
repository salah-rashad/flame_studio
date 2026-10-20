import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

import 'legacy/player.dart' as legacy;

/// The player.
@PyroComponent(preview: 'assets/images/player.png')
class Player extends PositionedEntity {
  @Editable()
  int lives = 3;

  @Editable()
  String nickname = 'p1';

  @Editable()
  Sprite? icon;

  @Editable()
  legacy.Player? buddy;
}

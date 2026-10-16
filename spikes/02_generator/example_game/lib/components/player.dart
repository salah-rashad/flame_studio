import 'dart:ui';

import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:studio_annotations/studio_annotations.dart';

@StudioComponent(category: 'Characters')
class Player extends PositionedEntity {
  @Editable(min: 0)
  int lives = 3;

  @Editable()
  bool invincible = false;

  @Editable(tooltip: 'Shown above the head')
  String nickname = 'Hero';

  @Editable()
  Color tint = const Color(0xFFFFFFFF);
}

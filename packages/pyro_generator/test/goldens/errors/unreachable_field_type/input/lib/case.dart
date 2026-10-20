import 'package:flame/src/components/position_component.dart';
import 'package:flame/src/sprite.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class Host extends PositionComponent {
  @Editable()
  Sprite? icon;
}

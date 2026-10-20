import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

@PyroComponent()
class Host extends PositionComponent {
  @Editable()
  v64.Vector2 at = v64.Vector2(0, 0);
}

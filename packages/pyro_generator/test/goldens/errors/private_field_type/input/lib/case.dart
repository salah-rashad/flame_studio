import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

enum _Mode { idle, run }

class _Marker extends PositionComponent {}

@PyroComponent()
class Host extends PositionComponent {
  @Editable()
  _Mode mode = _Mode.idle;

  @Editable()
  _Marker? marker;
}

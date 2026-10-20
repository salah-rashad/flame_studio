// Stand-ins for the parts of Flame, flame_behaviors and vector_math the
// generator matches, at their real paths (research R3, R12). The generator
// never depends on Flame, so its tests resolve these in memory. dart:ui can't
// be stood in for, so Color is covered by the fixture game.

/// In-memory sources, keyed `package|path`, for `testBuilders`.
const Map<String, String> flameStubs = {
  'flame|lib/src/components/core/component.dart': 'class Component {}\n',
  'flame|lib/src/components/position_component.dart': '''
import 'core/component.dart';

class PositionComponent extends Component {}
''',
  'flame|lib/src/sprite.dart': 'class Sprite {}\n',
  'flame|lib/src/sprite_animation.dart': 'class SpriteAnimation {}\n',
  'flame|lib/components.dart': '''
export 'package:vector_math/vector_math.dart';
export 'src/components/core/component.dart';
export 'src/components/position_component.dart';
export 'src/sprite.dart';
export 'src/sprite_animation.dart';
''',
  // vector_math declares its classes in part files, as the real one does.
  'vector_math|lib/vector_math.dart':
      "part 'src/vector_math/vector2.dart';\n",
  'vector_math|lib/src/vector_math/vector2.dart': '''
part of '../../vector_math.dart';

class Vector2 {
  Vector2(this.x, this.y);
  final double x;
  final double y;
}
''',
  'vector_math|lib/vector_math_64.dart':
      "part 'src/vector_math_64/vector2.dart';\n",
  'vector_math|lib/src/vector_math_64/vector2.dart': '''
part of '../../vector_math_64.dart';

class Vector2 {
  Vector2(this.x, this.y);
  final double x;
  final double y;
}
''',
  'flame_behaviors|lib/flame_behaviors.dart': '''
import 'package:flame/components.dart';

mixin EntityMixin on Component {}

abstract class Behavior<Parent extends EntityMixin> extends Component {}

class PositionedEntity extends PositionComponent with EntityMixin {}
''',
};

/// A stand-in `pyro_runtime` library that re-exports the annotations, as the
/// real one does.
const Map<String, String> runtimeStub = {
  'pyro_runtime|lib/pyro_runtime.dart':
      "export 'package:pyro_annotations/pyro_annotations.dart';\n",
};

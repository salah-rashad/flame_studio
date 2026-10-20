import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:pyro_annotations/pyro_annotations.dart';
import 'package:source_gen/source_gen.dart';

// Pyro's annotations are matched by their declaration, so a re-export through
// pyro_runtime or a prefixed import still counts (research R3).

/// Matches `@PyroBehavior`.
const pyroBehaviorChecker = TypeChecker.typeNamed(
  PyroBehavior,
  inPackage: 'pyro_annotations',
);

/// Matches `@PyroComponent`.
const pyroComponentChecker = TypeChecker.typeNamed(
  PyroComponent,
  inPackage: 'pyro_annotations',
);

/// Matches `@Editable`.
const editableChecker = TypeChecker.typeNamed(
  Editable,
  inPackage: 'pyro_annotations',
);

/// Matches the `ImagePath` Field type.
const imagePathChecker = TypeChecker.typeNamed(
  ImagePath,
  inPackage: 'pyro_annotations',
);

// Flame's types are matched by package and name: the generator never depends
// on Flame (constitution II), and the names are stable across Flame 1.x.

/// Matches Flame's `Component`.
const componentChecker = TypeChecker.typeNamedLiterally(
  'Component',
  inPackage: 'flame',
);

/// Matches Flame's `PositionComponent`.
const positionComponentChecker = TypeChecker.typeNamedLiterally(
  'PositionComponent',
  inPackage: 'flame',
);

/// Matches Flame's `Sprite`.
const spriteChecker = TypeChecker.typeNamedLiterally(
  'Sprite',
  inPackage: 'flame',
);

/// Matches Flame's `SpriteAnimation`.
const spriteAnimationChecker = TypeChecker.typeNamedLiterally(
  'SpriteAnimation',
  inPackage: 'flame',
);

/// Matches `flame_behaviors`' `Behavior`.
const behaviorChecker = TypeChecker.typeNamedLiterally(
  'Behavior',
  inPackage: 'flame_behaviors',
);

/// Matches `flame_behaviors`' `EntityMixin`.
const entityMixinChecker = TypeChecker.typeNamedLiterally(
  'EntityMixin',
  inPackage: 'flame_behaviors',
);

/// Matches the `Vector2` Flame uses. `vector_math` declares a second one in
/// `vector_math_64`, which the Runtime can't assign a Flame vector to, so this
/// one is matched by its library. Both are `part`s of their library, so the
/// URL is the library's, not the part file's (research R3).
const vector2Checker = TypeChecker.fromUrl(
  'package:vector_math/vector_math.dart#Vector2',
);

/// Matches `dart:ui`'s `Color`.
const colorChecker = TypeChecker.fromUrl('dart:ui#Color');

/// Whether [element] is `vector_math_64`'s `Vector2`, for a better error.
bool isVectorMath64Vector2(InterfaceElement element) =>
    element.name == 'Vector2' &&
    element.library.uri.toString().contains('vector_math_64');

/// Whether [type] is, or extends, Flame's `Component`.
bool isComponentType(InterfaceType type) =>
    componentChecker.isAssignableFromType(type);

/// Whether [type] is, or extends, a `flame_behaviors` `Behavior`.
bool isBehaviorType(InterfaceType type) =>
    behaviorChecker.isAssignableFromType(type);

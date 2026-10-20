import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'checkers.dart';

/// The v1 Field types (project plan §6.1, *Q12*; research R5).
enum FieldKind {
  /// `int`.
  int('int'),

  /// `double`.
  double('double'),

  /// `bool`.
  bool('bool'),

  /// `String`.
  string('string'),

  /// An enum with at least one value.
  enumeration('enum'),

  /// Flame's `Vector2`.
  vector2('vector2'),

  /// `dart:ui`'s `Color`.
  color('color'),

  /// `ImagePath` from `pyro_annotations`.
  imagePath('imagePath'),

  /// Flame's `Sprite`.
  sprite('sprite'),

  /// Flame's `SpriteAnimation`.
  spriteAnimation('spriteAnimation'),

  /// A `Component` that isn't a Behavior: an entity reference.
  entityRef('entityRef');

  const FieldKind(this.manifestName);

  /// The Manifest's name for it (contracts/manifest-v1.md).
  final String manifestName;

  /// The `FieldType` value's name in `pyro_runtime`.
  String get registryName => name;
}

// Outside the enum, where `int`, `double` and `bool` name the core types
// rather than its values.

/// What the rules need to know about a [FieldKind].
extension FieldKindRules on FieldKind {
  /// Whether `min` and `max` apply.
  bool get isNumeric => this == FieldKind.int || this == FieldKind.double;

  /// Whether the type is a `dart:core` type, which the Registry names
  /// without an import.
  bool get isCore =>
      this == FieldKind.int ||
      this == FieldKind.double ||
      this == FieldKind.bool ||
      this == FieldKind.string;

  /// Whether the field must be nullable (FR-011a).
  bool get mustBeNullable =>
      this == FieldKind.entityRef ||
      this == FieldKind.sprite ||
      this == FieldKind.spriteAnimation;
}

/// A supported field type, classified.
final class FieldClass {
  /// [kind], with [element] naming the Dart type.
  const FieldClass({
    required this.kind,
    required this.nullable,
    required this.element,
  });

  /// The Field type.
  final FieldKind kind;

  /// Whether the declared type is nullable.
  final bool nullable;

  /// The Dart type's declaration, such as `Vector2` or the enum.
  final InterfaceElement element;

  /// The enum's value names in declaration order, for [FieldKind.enumeration].
  List<String> get enumValues => [
    if (element case final EnumElement e)
      for (final constant in e.constants) constant.name!,
  ];
}

/// Classifies [type] as a v1 Field type, or returns null if it isn't one
/// (research R5). Type aliases are resolved by the analyzer already; types
/// with type arguments are never supported.
FieldClass? classifyField(DartType type) {
  if (type is! InterfaceType || type.typeArguments.isNotEmpty) return null;
  final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
  final element = type.element;
  FieldClass make(FieldKind kind) =>
      FieldClass(kind: kind, nullable: nullable, element: element);

  if (type.isDartCoreInt) return make(FieldKind.int);
  if (type.isDartCoreDouble) return make(FieldKind.double);
  if (type.isDartCoreBool) return make(FieldKind.bool);
  if (type.isDartCoreString) return make(FieldKind.string);
  if (element is EnumElement) {
    return element.constants.isEmpty ? null : make(FieldKind.enumeration);
  }
  if (imagePathChecker.isExactly(element)) return make(FieldKind.imagePath);
  if (vector2Checker.isExactly(element)) return make(FieldKind.vector2);
  if (colorChecker.isExactly(element)) return make(FieldKind.color);
  if (spriteChecker.isExactly(element)) return make(FieldKind.sprite);
  if (spriteAnimationChecker.isExactly(element)) {
    return make(FieldKind.spriteAnimation);
  }
  if (isComponentType(type) && !isBehaviorType(type)) {
    return make(FieldKind.entityRef);
  }
  return null;
}

/// Why [type] isn't a Field type, as a hint for the error message, or null
/// when there is nothing more to say than "unsupported".
String? unsupportedHint(DartType type) {
  if (type is! InterfaceType) return null;
  if (isVectorMath64Vector2(type.element)) {
    return "use Flame's Vector2 (package:flame/components.dart), not "
        "vector_math_64's";
  }
  if (isBehaviorType(type)) {
    return 'a Behavior is never a Node, so it can\'t be an entity reference';
  }
  if (type.element case EnumElement(constants: [])) {
    return 'the enum has no values';
  }
  if (type.typeArguments.isNotEmpty) {
    return 'types with type arguments are not supported';
  }
  return null;
}
